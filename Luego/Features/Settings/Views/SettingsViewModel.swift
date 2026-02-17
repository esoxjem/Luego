import Foundation
import SwiftData

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

        do {
            let count = try await articleService.forceReSyncAllArticles()
            forceSyncCount = count
            didForceSync = true
        } catch {
            Logger.cloudKit.error("Force re-sync failed: \(error.localizedDescription)")
        }

        isForceSyncing = false

        if didForceSync {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                didForceSync = false
            }
        }
    }
}
