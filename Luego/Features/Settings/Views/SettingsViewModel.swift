import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var selectedDiscoverySource: DiscoverySource
    var didRefreshPool = false
    var isCheckingForUpdates = false
    var updateResult: SDKUpdateResult?
    var showUpdateAlert = false

    private let preferencesDataSource: DiscoveryPreferencesDataSourceProtocol
    private let discoveryService: DiscoveryServiceProtocol
    private let sdkManager: LuegoSDKManagerProtocol

    init(
        preferencesDataSource: DiscoveryPreferencesDataSourceProtocol,
        discoveryService: DiscoveryServiceProtocol,
        sdkManager: LuegoSDKManagerProtocol
    ) {
        self.preferencesDataSource = preferencesDataSource
        self.discoveryService = discoveryService
        self.sdkManager = sdkManager
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
}
