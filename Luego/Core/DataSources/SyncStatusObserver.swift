import Foundation
import CoreData
import CloudKit

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

    nonisolated(unsafe) private var observerTask: Task<Void, Never>?
    nonisolated(unsafe) private var debounceTask: Task<Void, Never>?

    init() {
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
            updateState(.syncing)
            Logger.cloudKit.debug("\(eventType) started")
        } else if let error = event.error {
            let (message, needsSignIn) = classifyError(error)
            updateState(.error(message: message, needsSignIn: needsSignIn))
            Logger.cloudKit.error("\(eventType) failed: \(error.localizedDescription)")
        } else {
            lastSyncTime = Date()
            updateState(.success)
            Logger.cloudKit.info("\(eventType) completed")

            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                if state == .success { updateState(.idle) }
            }
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
        if let ckError = error as? CKError, ckError.code == .notAuthenticated {
            return ("Sign in to iCloud to sync", true)
        }
        return (error.localizedDescription, false)
    }

    func dismissError() {
        if case .error = state {
            updateState(.idle)
        }
    }
}
