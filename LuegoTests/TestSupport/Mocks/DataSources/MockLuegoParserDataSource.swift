import Foundation
@testable import Luego

@MainActor
final class MockLuegoParserDataSource: LuegoParserDataSourceProtocol {
    var parseCallCount = 0
    var lastParsedHTML: String?
    var lastParsedURL: URL?

    var mockIsReady = false
    var resultToReturn: ParserResult?

    var isReady: Bool {
        mockIsReady
    }

    func parse(html: String, url: URL) async -> ParserResult? {
        parseCallCount += 1
        lastParsedHTML = html
        lastParsedURL = url
        return resultToReturn
    }

    func reset() {
        parseCallCount = 0
        lastParsedHTML = nil
        lastParsedURL = nil
        mockIsReady = false
        resultToReturn = nil
    }
}
