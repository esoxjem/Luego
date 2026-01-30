import Foundation
import CoreData

final class CloudKitSyncObserver: Sendable {
    init() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            Self.handleSyncEvent(notification)
        }
        Logger.cloudKit.info("CloudKit sync observer initialized")
    }

    private static func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else { return }

        let eventType = switch event.type {
            case .setup: "Setup"
            case .import: "Import"
            case .export: "Export"
            @unknown default: "Unknown"
        }

        if event.endDate != nil {
            if let error = event.error {
                Logger.cloudKit.error("\(eventType) failed: \(error.localizedDescription)")
            } else {
                Logger.cloudKit.info("\(eventType) completed successfully")
            }
        } else {
            Logger.cloudKit.debug("\(eventType) started")
        }
    }
}
