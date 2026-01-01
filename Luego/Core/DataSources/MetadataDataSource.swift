import Foundation

protocol MetadataDataSourceProtocol: Sendable {
    func validateURL(_ url: URL) async throws -> URL
    func fetchMetadata(for url: URL, timeout: TimeInterval?) async throws -> ArticleMetadata
    func fetchContent(for url: URL, timeout: TimeInterval?, forceRefresh: Bool, skipCache: Bool) async throws -> ArticleContent
    func fetchHTML(from url: URL, timeout: TimeInterval?) async throws -> String
}

extension MetadataDataSourceProtocol {
    func fetchMetadata(for url: URL) async throws -> ArticleMetadata {
        try await fetchMetadata(for: url, timeout: nil)
    }

    func fetchContent(for url: URL) async throws -> ArticleContent {
        try await fetchContent(for: url, timeout: nil, forceRefresh: false, skipCache: false)
    }

    func fetchContent(for url: URL, timeout: TimeInterval?) async throws -> ArticleContent {
        try await fetchContent(for: url, timeout: timeout, forceRefresh: false, skipCache: false)
    }

    func fetchContent(for url: URL, timeout: TimeInterval?, forceRefresh: Bool) async throws -> ArticleContent {
        try await fetchContent(for: url, timeout: timeout, forceRefresh: forceRefresh, skipCache: false)
    }

    func fetchHTML(from url: URL) async throws -> String {
        try await fetchHTML(from: url, timeout: nil)
    }
}

@MainActor
final class MetadataDataSource: MetadataDataSourceProtocol {
    init() {}

    func validateURL(_ url: URL) async throws -> URL {
        let urlString = url.absoluteString
        guard let validatedURL = validateURLString(urlString) else {
            throw ArticleMetadataError.invalidURL
        }
        return validatedURL
    }

    func fetchMetadata(for url: URL, timeout: TimeInterval?) async throws -> ArticleMetadata {
        throw ArticleMetadataError.noMetadata
    }

    func fetchContent(for url: URL, timeout: TimeInterval?, forceRefresh: Bool, skipCache: Bool) async throws -> ArticleContent {
        throw ArticleMetadataError.noMetadata
    }

    func fetchHTML(from url: URL, timeout: TimeInterval?) async throws -> String {
        try validateHTTPScheme(url)
        return try await fetchHTMLContent(from: url, timeout: timeout)
    }

    private func validateURLString(_ urlString: String) -> URL? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespaces)
        let urlWithScheme = addHTTPSSchemeIfNeeded(to: trimmedURL)

        guard let url = URL(string: urlWithScheme),
              (url.scheme == "http" || url.scheme == "https"),
              url.host() != nil else {
            return nil
        }

        return url
    }

    private func validateHTTPScheme(_ url: URL) throws {
        guard url.scheme == "http" || url.scheme == "https" else {
            throw ArticleMetadataError.invalidURL
        }
    }

    private func fetchHTMLContent(from url: URL, timeout: TimeInterval?) async throws -> String {
        do {
            let data: Data
            if let timeout {
                var request = URLRequest(url: url)
                request.timeoutInterval = timeout
                (data, _) = try await URLSession.shared.data(for: request)
            } else {
                (data, _) = try await URLSession.shared.data(from: url)
            }
            guard let content = String(data: data, encoding: .utf8) else {
                throw ArticleMetadataError.noMetadata
            }
            return content
        } catch {
            throw ArticleMetadataError.networkError(error)
        }
    }

    private func addHTTPSSchemeIfNeeded(to urlString: String) -> String {
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            return "https://" + urlString
        }
        return urlString
    }
}
