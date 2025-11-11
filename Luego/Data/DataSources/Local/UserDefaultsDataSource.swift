import Foundation

final class UserDefaultsDataSource {
    private let sharedStorage: SharedStorage

    init(sharedStorage: SharedStorage = .shared) {
        self.sharedStorage = sharedStorage
    }

    func getSharedURLs() -> [URL] {
        sharedStorage.getSharedURLs().map { $0.url }
    }

    func clearSharedURLs() {
        sharedStorage.clearSharedURLs()
    }
}
