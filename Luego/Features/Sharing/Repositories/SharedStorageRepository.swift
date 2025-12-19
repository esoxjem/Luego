import Foundation

protocol SharedStorageRepositoryProtocol: Sendable {
    func getSharedURLs() async -> [URL]
    func clearSharedURLs() async
}

@MainActor
final class SharedStorageRepository: SharedStorageRepositoryProtocol {
    private let userDefaultsDataSource: UserDefaultsDataSourceProtocol

    init(userDefaultsDataSource: UserDefaultsDataSourceProtocol) {
        self.userDefaultsDataSource = userDefaultsDataSource
    }

    func getSharedURLs() async -> [URL] {
        userDefaultsDataSource.getSharedURLs()
    }

    func clearSharedURLs() async {
        userDefaultsDataSource.clearSharedURLs()
    }
}
