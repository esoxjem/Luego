import Foundation
import CoreData
import CloudKit
import SwiftData

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum SyncState: Equatable {
    case idle
    case syncing
    case success
    case error(message: String, needsSignIn: Bool)
}

@MainActor
protocol SyncStatusObservable: AnyObject {
    var state: SyncState { get }
    var lastSyncTime: Date? { get }
    func dismissError()
}

@Observable
@MainActor
final class SyncStatusObserver: SyncStatusObservable {
    private(set) var state: SyncState = .idle
    private(set) var lastSyncTime: Date?

    @ObservationIgnored
    private let modelContext: ModelContext
    @ObservationIgnored
    private var observerTask: Task<Void, Never>?
    @ObservationIgnored
    private var debounceTask: Task<Void, Never>?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        observeCloudKitEvents()
    }

    deinit {
        observerTask?.cancel()
        debounceTask?.cancel()
    }

    private func observeCloudKitEvents() {
        observerTask = Task {
            let notifications = NotificationCenter.default.notifications(
                named: NSPersistentCloudKitContainer.eventChangedNotification
            )
            for await notification in notifications {
                handleSyncEvent(notification)
            }
        }
        Logger.cloudKit.info("SyncStatusObserver initialized")
    }

    private func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else { return }

        let eventType = switch event.type {
            case .setup: "Setup"
            case .import: "Import"
            case .export: "Export"
            @unknown default: "Sync"
        }

        if event.endDate == nil {
            debounceTask?.cancel()
            updateState(.syncing)
            Logger.cloudKit.debug("\(eventType) started")
        } else if let error = event.error {
            debounceTask?.cancel()
            let (message, needsSignIn) = classifyError(error)
            updateState(.error(message: message, needsSignIn: needsSignIn))
            logSyncError(eventType: eventType, error: error)
        } else {
            debounceTask?.cancel()
            lastSyncTime = Date()
            updateState(.success)
            Logger.cloudKit.info("\(eventType) completed successfully")

            if event.type == .import {
                logArticleCounts(after: eventType)
            }

            debounceTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                if state == .success { updateState(.idle) }
            }
        }
    }

    private func logSyncError(eventType: String, error: Error) {
        if let ckError = error as? CKError {
            Logger.cloudKit.error("\(eventType) failed — CKError code: \(ckError.code.rawValue), domain: \(ckError.errorCode), description: \(ckError.localizedDescription)")
            if let retryAfter = ckError.retryAfterSeconds {
                Logger.cloudKit.error("\(eventType) — server suggests retry after \(retryAfter)s")
            }
            if let partialErrors = ckError.partialErrorsByItemID {
                Logger.cloudKit.error("\(eventType) — partial errors for \(partialErrors.count) items")
            }
        } else {
            Logger.cloudKit.error("\(eventType) failed — \(error.localizedDescription)")
        }
    }

    private func logArticleCounts(after eventType: String) {
        do {
            let allDescriptor = FetchDescriptor<Article>()
            let total = try modelContext.fetchCount(allDescriptor)

            let favPredicate = #Predicate<Article> { $0.isFavorite }
            let favDescriptor = FetchDescriptor<Article>(predicate: favPredicate)
            let favorites = try modelContext.fetchCount(favDescriptor)

            let archPredicate = #Predicate<Article> { $0.isArchived }
            let archDescriptor = FetchDescriptor<Article>(predicate: archPredicate)
            let archived = try modelContext.fetchCount(archDescriptor)

            let readingList = total - favorites - archived
            Logger.cloudKit.info("Article counts after \(eventType) — total: \(total), reading list: \(readingList), favorites: \(favorites), archived: \(archived)")
        } catch {
            Logger.cloudKit.error("Failed to fetch article counts: \(error.localizedDescription)")
        }
    }

    private func updateState(_ newState: SyncState) {
        let oldState = state
        state = newState

        if oldState != newState {
            announceStateChange(newState)
        }
    }

    private func announceStateChange(_ newState: SyncState) {
        let announcement: String? = switch newState {
        case .idle: nil
        case .syncing: "Syncing with iCloud"
        case .success: "Sync complete"
        case .error(let message, _): "Sync error: \(message)"
        }

        if let announcement {
            #if os(iOS)
            UIAccessibility.post(notification: .announcement, argument: announcement)
            #elseif os(macOS)
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [.announcement: announcement]
            )
            #endif
        }
    }

    private func classifyError(_ error: Error) -> (message: String, needsSignIn: Bool) {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return ("Sign in to iCloud to sync", true)
            case .networkUnavailable, .networkFailure:
                return ("Network unavailable. Please check your connection.", false)
            case .quotaExceeded:
                return ("iCloud storage is full", false)
            case .serverResponseLost:
                return ("Sync interrupted. Will retry automatically.", false)
            default:
                return ("Unable to sync. Please try again later.", false)
            }
        }
        return ("Unable to sync. Please try again later.", false)
    }

    func dismissError() {
        if case .error = state {
            updateState(.idle)
        }
    }
}
