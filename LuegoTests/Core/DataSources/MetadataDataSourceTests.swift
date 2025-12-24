import Testing
import Foundation
@testable import Luego

@Suite("MetadataDataSource Tests")
@MainActor
struct MetadataDataSourceTests {
    var turndownDataSource: TurndownDataSource
    var sut: MetadataDataSource

    init() {
        turndownDataSource = TurndownDataSource()
        sut = MetadataDataSource(turndownDataSource: turndownDataSource)
    }

    @Test("validateURL returns same URL for valid HTTPS URL")
    func validateURLReturnsValidHTTPSURL() async throws {
        let url = URL(string: "https://example.com/article")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL == url)
    }

    @Test("validateURL returns same URL for valid HTTP URL")
    func validateURLReturnsValidHTTPURL() async throws {
        let url = URL(string: "http://example.com/article")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL == url)
    }

    @Test("validateURL returns valid URL unchanged")
    func validateURLReturnsValidURLUnchanged() async throws {
        let url = URL(string: "https://example.com/article")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.absoluteString == "https://example.com/article")
    }

    @Test("validateURL adds HTTPS scheme when missing")
    func validateURLAddsHTTPSScheme() async throws {
        let url = URL(string: "example.com/article")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.scheme == "https")
        #expect(validatedURL.absoluteString == "https://example.com/article")
    }

    @Test("validateURL accepts URL with path")
    func validateURLAcceptsURLWithPath() async throws {
        let url = URL(string: "https://example.com/path/to/article")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.path == "/path/to/article")
    }

    @Test("validateURL accepts URL with query parameters")
    func validateURLAcceptsURLWithQuery() async throws {
        let url = URL(string: "https://example.com/article?id=123&ref=test")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.query?.contains("id=123") == true)
    }

    @Test("validateURL accepts URL with fragment")
    func validateURLAcceptsURLWithFragment() async throws {
        let url = URL(string: "https://example.com/article#section1")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.fragment == "section1")
    }

    @Test("validateURL accepts international domain names")
    func validateURLAcceptsInternationalDomains() async throws {
        let url = URL(string: "https://例え.jp/article")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.host() != nil)
    }

    @Test("validateURL preserves port number")
    func validateURLPreservesPort() async throws {
        let url = URL(string: "https://example.com:8080/article")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.port == 8080)
    }
}

@Suite("MetadataDataSource URL Validation Edge Cases")
@MainActor
struct MetadataDataSourceURLEdgeCaseTests {
    var turndownDataSource: TurndownDataSource
    var sut: MetadataDataSource

    init() {
        turndownDataSource = TurndownDataSource()
        sut = MetadataDataSource(turndownDataSource: turndownDataSource)
    }

    @Test("validateURL handles URL with special characters")
    func validateURLHandlesSpecialCharacters() async throws {
        let url = URL(string: "https://example.com/article%20with%20spaces")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.absoluteString.contains("article%20with%20spaces"))
    }

    @Test("validateURL accepts subdomains")
    func validateURLAcceptsSubdomains() async throws {
        let url = URL(string: "https://blog.example.com/article")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.host() == "blog.example.com")
    }

    @Test("validateURL accepts deep paths")
    func validateURLAcceptsDeepPaths() async throws {
        let url = URL(string: "https://example.com/a/b/c/d/e/article")!

        let validatedURL = try await sut.validateURL(url)

        #expect(validatedURL.pathComponents.count > 5)
    }
}
