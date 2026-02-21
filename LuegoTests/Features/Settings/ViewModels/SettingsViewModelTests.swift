import Testing
import Foundation
@testable import Luego

@Suite("SettingsViewModel Tests")
@MainActor
struct SettingsViewModelTests {
    var mockPreferencesDataSource: MockDiscoveryPreferencesDataSource
    var mockDiscoveryService: MockDiscoveryService
    var mockSDKManager: MockLuegoSDKManager
    var mockArticleService: MockArticleService
    var viewModel: SettingsViewModel

    init() {
        mockPreferencesDataSource = MockDiscoveryPreferencesDataSource()
        mockPreferencesDataSource.selectedSource = .kagiSmallWeb
        mockDiscoveryService = MockDiscoveryService()
        mockSDKManager = MockLuegoSDKManager()
        mockArticleService = MockArticleService()
        viewModel = SettingsViewModel(
            preferencesDataSource: mockPreferencesDataSource,
            discoveryService: mockDiscoveryService,
            sdkManager: mockSDKManager,
            articleService: mockArticleService
        )
    }

    @Test("init loads selected source from preferences")
    func initLoadsSelectedSource() {
        mockPreferencesDataSource.selectedSource = DiscoverySource.blogroll
        let vm = SettingsViewModel(
            preferencesDataSource: mockPreferencesDataSource,
            discoveryService: mockDiscoveryService,
            sdkManager: mockSDKManager,
            articleService: mockArticleService
        )

        #expect(vm.selectedDiscoverySource == DiscoverySource.blogroll)
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
        viewModel.updateDiscoverySource(DiscoverySource.blogroll)

        #expect(mockPreferencesDataSource.setSelectedSourceCallCount == 1)
        #expect(mockPreferencesDataSource.lastSetSource == DiscoverySource.blogroll)
    }

    @Test("updateDiscoverySource updates local property")
    func updateDiscoverySourceUpdatesLocal() {
        viewModel.updateDiscoverySource(DiscoverySource.blogroll)

        #expect(viewModel.selectedDiscoverySource == DiscoverySource.blogroll)
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
