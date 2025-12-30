import Foundation
@testable import Luego

@MainActor
final class MockLuegoSDKManager: LuegoSDKManagerProtocol {
    var ensureSDKReadyCallCount = 0
    var isSDKAvailableCallCount = 0
    var loadBundlesCallCount = 0
    var loadRulesCallCount = 0
    var getVersionInfoCallCount = 0

    var mockIsSDKAvailable = true
    var bundlesToReturn: [String: String]?
    var rulesToReturn: Data?
    var versionInfoToReturn: SDKVersionInfo?

    func ensureSDKReady() async {
        ensureSDKReadyCallCount += 1
    }

    func isSDKAvailable() -> Bool {
        isSDKAvailableCallCount += 1
        return mockIsSDKAvailable
    }

    func loadBundles() -> [String: String]? {
        loadBundlesCallCount += 1
        return bundlesToReturn
    }

    func loadRules() -> Data? {
        loadRulesCallCount += 1
        return rulesToReturn
    }

    func getVersionInfo() -> SDKVersionInfo? {
        getVersionInfoCallCount += 1
        return versionInfoToReturn
    }

    func reset() {
        ensureSDKReadyCallCount = 0
        isSDKAvailableCallCount = 0
        loadBundlesCallCount = 0
        loadRulesCallCount = 0
        getVersionInfoCallCount = 0
        mockIsSDKAvailable = true
        bundlesToReturn = nil
        rulesToReturn = nil
        versionInfoToReturn = nil
    }
}
