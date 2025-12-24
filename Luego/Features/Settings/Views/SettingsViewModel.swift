import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var selectedDiscoverySource: DiscoverySource
    var didRefreshPool = false

    private let preferencesDataSource: DiscoveryPreferencesDataSourceProtocol
    private let discoveryService: DiscoveryServiceProtocol

    init(
        preferencesDataSource: DiscoveryPreferencesDataSourceProtocol,
        discoveryService: DiscoveryServiceProtocol
    ) {
        self.preferencesDataSource = preferencesDataSource
        self.discoveryService = discoveryService
        self.selectedDiscoverySource = preferencesDataSource.getSelectedSource()
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
