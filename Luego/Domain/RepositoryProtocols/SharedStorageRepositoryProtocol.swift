import Foundation

protocol SharedStorageRepositoryProtocol: Sendable {
    func getSharedURLs() async -> [URL]
    func clearSharedURLs() async
}
