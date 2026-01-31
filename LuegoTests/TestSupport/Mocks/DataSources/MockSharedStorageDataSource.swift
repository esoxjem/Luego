import Foundation
@testable import Luego

@MainActor
final class MockSharedStorageDataSource: SharedStorageDataSourceProtocol {
    var sharedURLs: [SharedURL] = []
    var lastSyncTimestamp: Date?

    var saveSharedURLCallCount = 0
    var getSharedURLsCallCount = 0
    var getSharedURLsAfterCallCount = 0
    var clearSharedURLsCallCount = 0
    var getLastSyncTimestampCallCount = 0
    var setLastSyncTimestampCallCount = 0

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

    func getSharedURLs(after timestamp: Date) -> [SharedURL] {
        getSharedURLsAfterCallCount += 1
        return sharedURLs.filter { $0.timestamp > timestamp }
    }

    func clearSharedURLs() {
        clearSharedURLsCallCount += 1
        sharedURLs.removeAll()
    }

    func getLastSyncTimestamp() -> Date? {
        getLastSyncTimestampCallCount += 1
        return lastSyncTimestamp
    }

    func setLastSyncTimestamp(_ timestamp: Date) {
        setLastSyncTimestampCallCount += 1
        lastSyncTimestamp = timestamp
    }

    func reset() {
        sharedURLs = []
        lastSyncTimestamp = nil
        saveSharedURLCallCount = 0
        getSharedURLsCallCount = 0
        getSharedURLsAfterCallCount = 0
        clearSharedURLsCallCount = 0
        getLastSyncTimestampCallCount = 0
        setLastSyncTimestampCallCount = 0
        lastSavedURL = nil
    }
}
