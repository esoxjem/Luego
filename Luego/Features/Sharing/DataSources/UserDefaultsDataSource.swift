import Foundation

@MainActor
protocol UserDefaultsDataSourceProtocol: Sendable {
    func getSharedURLs() -> [URL]
    func getSharedURLs(after timestamp: Date) -> [SharedURL]
    func clearSharedURLs()
    func getLastSyncTimestamp() -> Date?
    func setLastSyncTimestamp(_ timestamp: Date)
}

@MainActor
final class UserDefaultsDataSource: UserDefaultsDataSourceProtocol {
    private let sharedStorage: SharedStorageDataSourceProtocol

    init(sharedStorage: SharedStorageDataSourceProtocol) {
        self.sharedStorage = sharedStorage
    }

    func getSharedURLs() -> [URL] {
        sharedStorage.getSharedURLs().map { $0.url }
    }

    func getSharedURLs(after timestamp: Date) -> [SharedURL] {
        sharedStorage.getSharedURLs(after: timestamp)
    }

    func clearSharedURLs() {
        sharedStorage.clearSharedURLs()
    }

    func getLastSyncTimestamp() -> Date? {
        sharedStorage.getLastSyncTimestamp()
    }

    func setLastSyncTimestamp(_ timestamp: Date) {
        sharedStorage.setLastSyncTimestamp(timestamp)
    }
}
