import Foundation
@testable import Luego

@MainActor
final class MockUserDefaultsDataSource: UserDefaultsDataSourceProtocol {
    var sharedURLs: [URL] = []
    var sharedURLsWithTimestamps: [SharedURL] = []
    var lastSyncTimestamp: Date?

    var getSharedURLsCallCount = 0
    var getSharedURLsAfterCallCount = 0
    var clearSharedURLsCallCount = 0
    var getLastSyncTimestampCallCount = 0
    var setLastSyncTimestampCallCount = 0

    func getSharedURLs() -> [URL] {
        getSharedURLsCallCount += 1
        return sharedURLs
    }

    func getSharedURLs(after timestamp: Date) -> [SharedURL] {
        getSharedURLsAfterCallCount += 1
        return sharedURLsWithTimestamps.filter { $0.timestamp > timestamp }
    }

    func clearSharedURLs() {
        clearSharedURLsCallCount += 1
        sharedURLs.removeAll()
        sharedURLsWithTimestamps.removeAll()
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
        sharedURLsWithTimestamps = []
        lastSyncTimestamp = nil
        getSharedURLsCallCount = 0
        getSharedURLsAfterCallCount = 0
        clearSharedURLsCallCount = 0
        getLastSyncTimestampCallCount = 0
        setLastSyncTimestampCallCount = 0
    }
}
