import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var selectedDiscoverySource: DiscoverySource
    var didRefreshPool = false

    private let preferencesDataSource: DiscoveryPreferencesDataSourceProtocol
    private let discoveryRepositories: [DiscoverySourceProtocol]

    init(
        preferencesDataSource: DiscoveryPreferencesDataSourceProtocol,
        discoveryRepositories: [DiscoverySourceProtocol]
    ) {
        self.preferencesDataSource = preferencesDataSource
        self.discoveryRepositories = discoveryRepositories
        self.selectedDiscoverySource = preferencesDataSource.getSelectedSource()
    }

    func updateDiscoverySource(_ source: DiscoverySource) {
        selectedDiscoverySource = source
        preferencesDataSource.setSelectedSource(source)
    }

    func refreshArticlePool() {
        discoveryRepositories.forEach { $0.clearCache() }
        didRefreshPool = true
    }
}
