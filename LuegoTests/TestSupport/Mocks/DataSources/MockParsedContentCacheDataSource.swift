import Foundation
@testable import Luego

@MainActor
final class MockParsedContentCacheDataSource: ParsedContentCacheDataSourceProtocol {
    var getCallCount = 0
    var saveCallCount = 0
    var clearCallCount = 0
    var removeCallCount = 0

    var lastGetURL: URL?
    var lastSaveURL: URL?
    var lastSavedContent: ArticleContent?
    var lastRemoveURL: URL?

    var cachedContent: [URL: ArticleContent] = [:]

    func get(for url: URL) -> ArticleContent? {
        getCallCount += 1
        lastGetURL = url
        return cachedContent[url]
    }

    func save(_ content: ArticleContent, for url: URL) {
        saveCallCount += 1
        lastSaveURL = url
        lastSavedContent = content
        cachedContent[url] = content
    }

    func clear() {
        clearCallCount += 1
        cachedContent.removeAll()
    }

    func remove(for url: URL) {
        removeCallCount += 1
        lastRemoveURL = url
        cachedContent.removeValue(forKey: url)
    }

    func reset() {
        getCallCount = 0
        saveCallCount = 0
        clearCallCount = 0
        removeCallCount = 0
        lastGetURL = nil
        lastSaveURL = nil
        lastSavedContent = nil
        lastRemoveURL = nil
        cachedContent.removeAll()
    }
}
