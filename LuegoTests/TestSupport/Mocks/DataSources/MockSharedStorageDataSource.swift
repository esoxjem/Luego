import Foundation
@testable import Luego

@MainActor
final class MockSharedStorageDataSource: SharedStorageDataSourceProtocol {
    var sharedURLs: [SharedURL] = []

    var saveSharedURLCallCount = 0
    var getSharedURLsCallCount = 0
    var clearSharedURLsCallCount = 0

    var lastSavedURL: URL?

    func saveSharedURL(_ url: URL) {
        saveSharedURLCallCount += 1
        lastSavedURL = url
        sharedURLs.append(SharedURL(url: url, timestamp: Date()))
    }

    func getSharedURLs() -> [SharedURL] {
        getSharedURLsCallCount += 1
        return sharedURLs
    }

    func clearSharedURLs() {
        clearSharedURLsCallCount += 1
        sharedURLs.removeAll()
    }

    func reset() {
        sharedURLs = []
        saveSharedURLCallCount = 0
        getSharedURLsCallCount = 0
        clearSharedURLsCallCount = 0
        lastSavedURL = nil
    }
}
