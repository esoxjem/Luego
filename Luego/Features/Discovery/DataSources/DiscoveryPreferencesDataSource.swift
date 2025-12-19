import Foundation

protocol DiscoveryPreferencesDataSourceProtocol: Sendable {
    func getSelectedSource() -> DiscoverySource
    func setSelectedSource(_ source: DiscoverySource)
}

final class DiscoveryPreferencesDataSource: DiscoveryPreferencesDataSourceProtocol, Sendable {
    private let selectedSourceKey = "discovery_selected_source"

    func getSelectedSource() -> DiscoverySource {
        guard let rawValue = UserDefaults.standard.string(forKey: selectedSourceKey),
              let source = DiscoverySource(rawValue: rawValue) else {
            return .kagiSmallWeb
        }
        return source
    }

    func setSelectedSource(_ source: DiscoverySource) {
        UserDefaults.standard.set(source.rawValue, forKey: selectedSourceKey)
    }
}
