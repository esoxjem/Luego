import Foundation

@Observable
@MainActor
final class SettingsViewModel {
    var selectedDiscoverySource: DiscoverySource

    private let preferencesDataSource: DiscoveryPreferencesDataSourceProtocol

    init(preferencesDataSource: DiscoveryPreferencesDataSourceProtocol) {
        self.preferencesDataSource = preferencesDataSource
        self.selectedDiscoverySource = preferencesDataSource.getSelectedSource()
    }

    func updateDiscoverySource(_ source: DiscoverySource) {
        selectedDiscoverySource = source
        preferencesDataSource.setSelectedSource(source)
    }
}
