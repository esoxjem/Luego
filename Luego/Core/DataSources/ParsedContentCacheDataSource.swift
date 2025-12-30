import Foundation
import CryptoKit

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
            #if DEBUG
            print("[ParsedContentCache] Failed to create directory: \(error)")
            #endif
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

        guard !cached.isExpired else {
            remove(for: url)
            return nil
        }

        #if DEBUG
        print("[ParsedContentCache] Cache hit for: \(url.absoluteString)")
        #endif

        return cached.content
    }

    func save(_ content: ArticleContent, for url: URL) {
        let cached = CachedContent(content: content, timestamp: Date())
        let fileURL = cacheFileURL(for: url)

        do {
            let data = try JSONEncoder().encode(cached)
            try data.write(to: fileURL)

            #if DEBUG
            print("[ParsedContentCache] Saved content for: \(url.absoluteString)")
            #endif
        } catch {
            #if DEBUG
            print("[ParsedContentCache] Failed to save: \(error)")
            #endif
        }
    }

    func clear() {
        try? fileManager.removeItem(at: cacheDirectory)
        ensureDirectoryExists()

        #if DEBUG
        print("[ParsedContentCache] Cleared all cached content")
        #endif
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
    let timestamp: Date

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > AppConfiguration.parsedContentCacheExpiration
    }
}
