import Foundation
@testable import Luego

@MainActor
final class MockUserDefaultsDataSource: UserDefaultsDataSourceProtocol {
    var sharedURLs: [URL] = []

    var getSharedURLsCallCount = 0
    var clearSharedURLsCallCount = 0

    func getSharedURLs() -> [URL] {
        getSharedURLsCallCount += 1
        return sharedURLs
    }

    func clearSharedURLs() {
        clearSharedURLsCallCount += 1
        sharedURLs.removeAll()
    }

    func reset() {
        sharedURLs = []
        getSharedURLsCallCount = 0
        clearSharedURLsCallCount = 0
    }
}
