import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var selectedDiscoverySource: DiscoverySource
    var didRefreshPool = false

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
}
