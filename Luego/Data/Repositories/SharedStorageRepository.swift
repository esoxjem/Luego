import Foundation

final class SharedStorageRepository: SharedStorageRepositoryProtocol {
    private let userDefaultsDataSource: UserDefaultsDataSource

    init(userDefaultsDataSource: UserDefaultsDataSource) {
        self.userDefaultsDataSource = userDefaultsDataSource
    }

    func getSharedURLs() async -> [URL] {
        userDefaultsDataSource.getSharedURLs()
    }

    func clearSharedURLs() async {
        userDefaultsDataSource.clearSharedURLs()
    }
}
