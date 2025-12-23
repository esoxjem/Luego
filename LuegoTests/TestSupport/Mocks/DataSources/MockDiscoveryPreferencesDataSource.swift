import Foundation
@testable import Luego

@MainActor
final class MockDiscoveryPreferencesDataSource: DiscoveryPreferencesDataSourceProtocol {
    var selectedSource: DiscoverySource = .surpriseMe

    var getSelectedSourceCallCount = 0
    var setSelectedSourceCallCount = 0

    var lastSetSource: DiscoverySource?

    func getSelectedSource() -> DiscoverySource {
        getSelectedSourceCallCount += 1
        return selectedSource
    }

    func setSelectedSource(_ source: DiscoverySource) {
        setSelectedSourceCallCount += 1
        lastSetSource = source
        selectedSource = source
    }

    func reset() {
        selectedSource = .surpriseMe
        getSelectedSourceCallCount = 0
        setSelectedSourceCallCount = 0
        lastSetSource = nil
    }
}
