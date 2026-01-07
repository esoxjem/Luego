import Foundation

protocol UserDefaultsDataSourceProtocol: Sendable {
    func getSharedURLs() -> [URL]
    func clearSharedURLs()
}

final class UserDefaultsDataSource: UserDefaultsDataSourceProtocol {
    private let sharedStorage: SharedStorageDataSourceProtocol

    init(sharedStorage: SharedStorageDataSourceProtocol) {
        self.sharedStorage = sharedStorage
    }

    func getSharedURLs() -> [URL] {
        sharedStorage.getSharedURLs().map { $0.url }
    }

    func clearSharedURLs() {
        sharedStorage.clearSharedURLs()
    }
}
