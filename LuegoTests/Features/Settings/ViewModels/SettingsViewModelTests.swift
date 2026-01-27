import Testing
import Foundation
@testable import Luego

@Suite("SettingsViewModel Tests")
@MainActor
struct SettingsViewModelTests {
    var mockPreferencesDataSource: MockDiscoveryPreferencesDataSource
    var mockDiscoveryService: MockDiscoveryService
    var mockSDKManager: MockLuegoSDKManager
    var viewModel: SettingsViewModel

    init() {
        mockPreferencesDataSource = MockDiscoveryPreferencesDataSource()
        mockPreferencesDataSource.selectedSource = .kagiSmallWeb
        mockDiscoveryService = MockDiscoveryService()
        mockSDKManager = MockLuegoSDKManager()
        viewModel = SettingsViewModel(
            preferencesDataSource: mockPreferencesDataSource,
            discoveryService: mockDiscoveryService,
            sdkManager: mockSDKManager
        )
    }

    @Test("init loads selected source from preferences")
    func initLoadsSelectedSource() {
        mockPreferencesDataSource.selectedSource = .blogroll
        let vm = SettingsViewModel(
            preferencesDataSource: mockPreferencesDataSource,
            discoveryService: mockDiscoveryService,
            sdkManager: mockSDKManager
        )

        #expect(vm.selectedDiscoverySource == .blogroll)
    }

    @Test("sdkVersionString returns formatted version when available")
    func sdkVersionStringReturnsVersion() {
        mockSDKManager.versionInfoToReturn = SDKVersionInfo(parserVersion: "1.2.3", rulesVersion: "4.5.6")

        #expect(viewModel.sdkVersionString == "Parser 1.2.3 · Rules 4.5.6")
    }

    @Test("sdkVersionString returns nil when version info unavailable")
    func sdkVersionStringReturnsNil() {
        mockSDKManager.versionInfoToReturn = nil

        #expect(viewModel.sdkVersionString == nil)
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

    @Test("refreshArticlePool clears all caches")
    func refreshArticlePoolClearsCaches() {
        viewModel.refreshArticlePool()

        #expect(mockDiscoveryService.clearAllCachesCallCount == 1)
    }

    @Test("refreshArticlePool sets didRefreshPool to true")
    func refreshArticlePoolSetsFlag() {
        #expect(viewModel.didRefreshPool == false)

        viewModel.refreshArticlePool()

        #expect(viewModel.didRefreshPool == true)
    }
}
