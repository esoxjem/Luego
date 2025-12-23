import Testing
import Foundation
@testable import Luego

@Suite("SettingsViewModel Tests")
@MainActor
struct SettingsViewModelTests {
    var mockPreferencesDataSource: MockDiscoveryPreferencesDataSource
    var mockDiscoveryRepository1: MockDiscoverySourceRepository
    var mockDiscoveryRepository2: MockDiscoverySourceRepository
    var viewModel: SettingsViewModel

    init() {
        mockPreferencesDataSource = MockDiscoveryPreferencesDataSource()
        mockPreferencesDataSource.selectedSource = .kagiSmallWeb
        mockDiscoveryRepository1 = MockDiscoverySourceRepository(source: .kagiSmallWeb)
        mockDiscoveryRepository2 = MockDiscoverySourceRepository(source: .blogroll)
        viewModel = SettingsViewModel(
            preferencesDataSource: mockPreferencesDataSource,
            discoveryRepositories: [mockDiscoveryRepository1, mockDiscoveryRepository2]
        )
    }

    @Test("init loads selected source from preferences")
    func initLoadsSelectedSource() {
        mockPreferencesDataSource.selectedSource = .blogroll
        let vm = SettingsViewModel(
            preferencesDataSource: mockPreferencesDataSource,
            discoveryRepositories: []
        )

        #expect(vm.selectedDiscoverySource == .blogroll)
    }

    @Test("updateDiscoverySource updates preferences")
    func updateDiscoverySourceUpdatesPreferences() {
        viewModel.updateDiscoverySource(.blogroll)

        #expect(mockPreferencesDataSource.setSelectedSourceCallCount == 1)
        #expect(mockPreferencesDataSource.lastSetSource == .blogroll)
    }

    @Test("updateDiscoverySource updates local property")
    func updateDiscoverySourceUpdatesLocal() {
        viewModel.updateDiscoverySource(.blogroll)

        #expect(viewModel.selectedDiscoverySource == .blogroll)
    }

    @Test("refreshArticlePool clears all repository caches")
    func refreshArticlePoolClearsCaches() {
        viewModel.refreshArticlePool()

        #expect(mockDiscoveryRepository1.clearCacheCallCount == 1)
        #expect(mockDiscoveryRepository2.clearCacheCallCount == 1)
    }

    @Test("refreshArticlePool sets didRefreshPool to true")
    func refreshArticlePoolSetsFlag() {
        #expect(viewModel.didRefreshPool == false)

        viewModel.refreshArticlePool()

        #expect(viewModel.didRefreshPool == true)
    }

    @Test("refreshArticlePool handles empty repository list")
    func refreshArticlePoolHandlesEmpty() {
        let vm = SettingsViewModel(
            preferencesDataSource: mockPreferencesDataSource,
            discoveryRepositories: []
        )

        vm.refreshArticlePool()

        #expect(vm.didRefreshPool == true)
    }
}
