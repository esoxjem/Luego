import Foundation
import CryptoKit

@MainActor
protocol ParsedContentCacheDataSourceProtocol: Sendable {
    func get(for url: URL) -> ArticleContent?
    func save(_ content: ArticleContent, for url: URL)
    func clear()
    func remove(for url: URL)
}

@MainActor
final class ParsedContentCacheDataSource: ParsedContentCacheDataSourceProtocol {
    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        guard let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return fileManager.temporaryDirectory.appendingPathComponent("ParsedContent")
        }
        return caches.appendingPathComponent("ParsedContent")
    }

    init() {
        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            Logger.cache.error("Failed to create directory: \(error)")
        }
    }

    func get(for url: URL) -> ArticleContent? {
        let fileURL = cacheFileURL(for: url)

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        guard let cached = try? JSONDecoder().decode(CachedContent.self, from: data) else {
            remove(for: url)
            return nil
        }

        Logger.cache.debug("Cache hit for: \(url.absoluteString)")

        return cached.content
    }

    func save(_ content: ArticleContent, for url: URL) {
        let cached = CachedContent(content: content)
        let fileURL = cacheFileURL(for: url)

        do {
            let data = try JSONEncoder().encode(cached)
            try data.write(to: fileURL)

            Logger.cache.debug("Saved content for: \(url.absoluteString)")
        } catch {
            Logger.cache.error("Failed to save: \(error)")
        }
    }

    func clear() {
        try? fileManager.removeItem(at: cacheDirectory)
        ensureDirectoryExists()

        Logger.cache.info("Cleared all cached content")
    }

    func remove(for url: URL) {
        let fileURL = cacheFileURL(for: url)
        try? fileManager.removeItem(at: fileURL)
    }

    private func cacheFileURL(for url: URL) -> URL {
        let hash = sha256Hash(of: url.absoluteString)
        return cacheDirectory.appendingPathComponent("\(hash).json")
    }

    private func sha256Hash(of string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private struct CachedContent: Codable {
    let content: ArticleContent
}
