import Foundation
import CloudKit
import UIKit

@Observable
@MainActor
final class SettingsViewModel {
    var selectedDiscoverySource: DiscoverySource
    var didRefreshPool = false
    var isCheckingForUpdates = false
    var updateResult: SDKUpdateResult?
    var showUpdateAlert = false
    var isForceSyncing = false
    var didForceSync = false
    var forceSyncCount = 0
    var forceSyncErrorMessage: String?

    private let preferencesDataSource: DiscoveryPreferencesDataSourceProtocol
    private let discoveryService: DiscoveryServiceProtocol
    private let sdkManager: LuegoSDKManagerProtocol
    private let articleService: ArticleServiceProtocol

    init(
        preferencesDataSource: DiscoveryPreferencesDataSourceProtocol,
        discoveryService: DiscoveryServiceProtocol,
        sdkManager: LuegoSDKManagerProtocol,
        articleService: ArticleServiceProtocol
    ) {
        self.preferencesDataSource = preferencesDataSource
        self.discoveryService = discoveryService
        self.sdkManager = sdkManager
        self.articleService = articleService
        self.selectedDiscoverySource = preferencesDataSource.getSelectedSource()
    }

    var sdkVersionString: String? {
        guard let info = sdkManager.getVersionInfo() else { return nil }
        return "Parser \(info.parserVersion) · Rules \(info.rulesVersion)"
    }

    func updateDiscoverySource(_ source: DiscoverySource) {
        selectedDiscoverySource = source
        preferencesDataSource.setSelectedSource(source)
    }

    func refreshArticlePool() {
        discoveryService.clearAllCaches()
        didRefreshPool = true
    }

    func checkForSDKUpdates() async {
        isCheckingForUpdates = true
        updateResult = await sdkManager.checkForUpdates()
        isCheckingForUpdates = false
        showUpdateAlert = true
    }

    var updateAlertTitle: String {
        guard let result = updateResult else { return "" }
        switch result {
        case .updated: return "SDK Updated"
        case .alreadyUpToDate: return "Up to Date"
        case .failed: return "Update Failed"
        }
    }

    var updateAlertMessage: String {
        guard let result = updateResult else { return "" }
        switch result {
        case .updated(let parser, let rules, let bundlesUpdated, let rulesUpdated):
            var components: [String] = []
            if bundlesUpdated > 0 { components.append("\(bundlesUpdated) bundle(s)") }
            if rulesUpdated { components.append("rules") }
            let updatedText = components.isEmpty ? "" : "\nUpdated: \(components.joined(separator: ", "))"
            return "Parser \(parser) · Rules \(rules)\(updatedText)"
        case .alreadyUpToDate(let parser, let rules):
            return "Parser \(parser) · Rules \(rules)"
        case .failed(let error):
            return error.localizedDescription
        }
    }

    func forceReSync() async {
        isForceSyncing = true
        didForceSync = false
        forceSyncErrorMessage = nil

        let syncStartTime = Date()

        do {
            let count = try await articleService.forceReSyncAllArticles()
            forceSyncCount = count

            let elapsed = Date().timeIntervalSince(syncStartTime)
            let minDuration: TimeInterval = 1.5
            if elapsed < minDuration {
                try? await Task.sleep(nanoseconds: UInt64((minDuration - elapsed) * 1_000_000_000))
            }

            didForceSync = true
        } catch {
            let message = error.localizedDescription
            forceSyncErrorMessage = message
            Logger.cloudKit.error("Repair sync failed: \(message)")
        }

        isForceSyncing = false

        if didForceSync {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                didForceSync = false
            }
        }
    }

    func gatherDiagnostics(syncStatusObserver: SyncStatusObserver?) async -> String {
        var lines: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        lines.append("=== Luego Diagnostics ===")
        lines.append("Generated: \(dateFormatter.string(from: Date()))")
        lines.append("")

        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        lines.append("App Bundle ID: \(bundleID)")
        lines.append("OSLog Subsystem: \(bundleID)")
        lines.append("App Version: \(version)")
        lines.append("Build Number: \(build)")
        lines.append("Platform: iOS \(UIDevice.current.systemVersion)")
        lines.append("")

        let container = CKContainer(identifier: AppConfiguration.cloudKitContainerIdentifier)
        async let cloudKitDiagnosticsTask = CloudKitRuntimeDiagnostics.collect(
            container: container,
            containerIdentifier: AppConfiguration.cloudKitContainerIdentifier
        )
        async let subscriptionsTask = fetchSubscriptions(for: container)
        async let articlesTask = articleService.getAllArticles()

        let cloudKitDiagnostics = await cloudKitDiagnosticsTask
        let subscriptions = await subscriptionsTask
        let articles = (try? await articlesTask) ?? []

        lines.append(contentsOf: cloudKitDiagnostics.detailLines)
        lines.append("Local Article Count: \(articles.count)")
        lines.append("Last Repair Sync Error: \(forceSyncErrorMessage ?? "none")")
        lines.append("")

        if let syncStatusObserver {
            lines.append("Sync Engine State: \(syncStateDescription(syncStatusObserver.state))")
            lines.append("Last Successful Sync: \(formattedDate(syncStatusObserver.lastSyncTime, dateFormatter: dateFormatter))")
            lines.append("Sync Account Status: \(syncStatusObserver.accountStatusDescription ?? "unknown")")
            if let diagnosticSummary = syncStatusObserver.cloudKitDiagnosticSummary {
                lines.append("Sync CloudKit Summary: \(diagnosticSummary)")
            }
            if let diagnosticHint = syncStatusObserver.cloudKitDiagnosticHint {
                lines.append("Sync CloudKit Hint: \(diagnosticHint)")
            }
            if syncStatusObserver.recentErrors.isEmpty {
                lines.append("Recent Sync Errors: none")
            } else {
                lines.append("Recent Sync Errors:")
                for error in syncStatusObserver.recentErrors.prefix(5) {
                    lines.append("  - \(error)")
                }
            }
            if syncStatusObserver.recentFailedRecordDetails.isEmpty {
                lines.append("Recent Failed Record Saves: none")
            } else {
                lines.append("Recent Failed Record Saves:")
                for detail in syncStatusObserver.recentFailedRecordDetails.prefix(5) {
                    lines.append("  - \(detail)")
                }
            }
            lines.append("")
        }

        lines.append("Active CloudKit Subscriptions: \(subscriptions.subscriptions.count)")
        for sub in subscriptions.subscriptions {
            lines.append("  - \(sub.subscriptionID) (type: \(sub.subscriptionType.rawValue))")
        }
        if let fetchError = subscriptions.errorMessage {
            lines.append("Subscription Fetch Error: \(fetchError)")
        }
        lines.append("")

        lines.append("--- Recent Logs (last 500 entries) ---")
        let logDateFormatter = DateFormatter()
        logDateFormatter.dateFormat = "HH:mm:ss"
        let recentLogs = LogStream.shared.entries.suffix(500)
        if recentLogs.isEmpty {
            lines.append("No logs captured yet.")
        } else {
            for entry in recentLogs {
                let time = logDateFormatter.string(from: entry.timestamp)
                lines.append("[\(time)] [\(entry.category)] [\(entry.level.rawValue)] \(entry.message)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func fetchSubscriptions(for container: CKContainer) async -> CloudKitSubscriptionSnapshot {
        do {
            return CloudKitSubscriptionSnapshot(
                subscriptions: try await container.privateCloudDatabase.allSubscriptions(),
                errorMessage: nil
            )
        } catch {
            return CloudKitSubscriptionSnapshot(
                subscriptions: [],
                errorMessage: error.localizedDescription
            )
        }
    }

    private func syncStateDescription(_ state: SyncState) -> String {
        switch state {
        case .idle:
            return "idle"
        case .syncing:
            return "syncing"
        case .restoring:
            return "restoring"
        case .success:
            return "success"
        case .error(let message, let needsSignIn):
            return needsSignIn ? "error: \(message) (sign in required)" : "error: \(message)"
        }
    }

    private func formattedDate(_ date: Date?, dateFormatter: DateFormatter) -> String {
        guard let date else { return "never" }
        return dateFormatter.string(from: date)
    }
}

private struct CloudKitSubscriptionSnapshot {
    let subscriptions: [CKSubscription]
    let errorMessage: String?
}
