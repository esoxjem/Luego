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

    func awaitWithTimeout(_ message: String) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while clock.now < deadline {
            if message == "syncing" && viewModel.isForceSyncing == true && mockArticleService.hasPendingForceReSyncContinuation {
                return
            }
            if message == "didSync" && viewModel.didForceSync == true {
                return
            }
            await Task.yield()
        }
        throw TimeoutError(message: "Timeout waiting for \(message)")
    }

    struct TimeoutError: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
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

    @Test("forceReSync succeeds and observes transient states")
    func forceReSyncSucceeds() async throws {
        mockArticleService.suspendNextForceReSync()
        mockArticleService.forceReSyncAllArticlesReturnCount = 5

        let task = Task {
            await viewModel.forceReSync()
        }

        defer {
            task.cancel()
            mockArticleService.cancelPendingForceReSync()
        }

        try await awaitWithTimeout("syncing")
        #expect(viewModel.isForceSyncing == true)
        #expect(viewModel.didForceSync == false)

        try? await Task.sleep(nanoseconds: 1_600_000_000)

        mockArticleService.resumeForceReSync(returning: 5)

        try await awaitWithTimeout("didSync")
        #expect(viewModel.didForceSync == true)

        await task.value

        #expect(viewModel.isForceSyncing == false)
        #expect(viewModel.didForceSync == false)
        #expect(viewModel.forceSyncCount == 5)
        #expect(mockArticleService.forceReSyncAllArticlesCallCount == 1)
    }

    @Test("forceReSync handles failure gracefully")
    func forceReSyncHandlesFailure() async {
        mockArticleService.shouldThrowOnForceReSyncAllArticles = true

        await viewModel.forceReSync()

        #expect(viewModel.didForceSync == false)
        #expect(viewModel.isForceSyncing == false)
        #expect(mockArticleService.forceReSyncAllArticlesCallCount == 1)
    }
}
