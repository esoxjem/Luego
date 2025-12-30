import Foundation
import SwiftSoup

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
        try validateHTTPScheme(url)
        let htmlContent = try await fetchHTMLContent(from: url, timeout: timeout)
        let document = try parseHTML(htmlContent)

        let (ogTitle, ogImage, ogDescription) = extractOpenGraphMetadata(from: document)
        let (htmlTitle, metaDescription) = extractStandardMetadata(from: document)
        let publishedDate = extractPublishedDate(from: document)

        let title = ogTitle ?? htmlTitle ?? url.host() ?? url.absoluteString
        let imageURL = ogImage ?? extractFirstImageURL(from: document)
        let thumbnailURL = buildThumbnailURL(from: imageURL, baseURL: url)
        let description = ogDescription ?? metaDescription

        return ArticleMetadata(
            title: title,
            thumbnailURL: thumbnailURL,
            description: description,
            publishedDate: publishedDate
        )
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

    private func parseHTML(_ htmlContent: String) throws -> Document {
        do {
            return try SwiftSoup.parse(htmlContent)
        } catch {
            throw ArticleMetadataError.parsingError(error)
        }
    }

    private func extractOpenGraphMetadata(from document: Document) -> (title: String?, image: String?, description: String?) {
        let ogTitle = try? document.select("meta[property=og:title]").first()?.attr("content")
        let ogImage = try? document.select("meta[property=og:image]").first()?.attr("content")
        let ogDescription = try? document.select("meta[property=og:description]").first()?.attr("content")
        return (ogTitle, ogImage, ogDescription)
    }

    private func extractStandardMetadata(from document: Document) -> (title: String?, description: String?) {
        let htmlTitle = try? document.select("title").first()?.text()
        let metaDescription = try? document.select("meta[name=description]").first()?.attr("content")
        return (htmlTitle, metaDescription)
    }

    private func extractPublishedDate(from document: Document) -> Date? {
        let dateSelectors = [
            "meta[property='article:published_time']",
            "meta[name='article:published_time']",
            "meta[property='og:published_time']",
            "meta[name='published_time']",
            "meta[name='datePublished']",
            "meta[itemprop='datePublished']",
            "time[datetime]",
            "meta[property='article:published']"
        ]

        for selector in dateSelectors {
            if let dateString = try? document.select(selector).first()?.attr("content").trimmingCharacters(in: .whitespaces),
               !dateString.isEmpty,
               let date = parseDateString(dateString) {
                return date
            }

            if selector == "time[datetime]",
               let dateString = try? document.select(selector).first()?.attr("datetime").trimmingCharacters(in: .whitespaces),
               !dateString.isEmpty,
               let date = parseDateString(dateString) {
                return date
            }
        }

        return nil
    }

    private func extractFirstImageURL(from document: Document) -> String? {
        let contentSelectors = [
            "article img",
            "main img",
            "[role=main] img",
            ".post-content img",
            ".article-content img",
            ".entry-content img",
            ".content img",
            "img"
        ]

        for selector in contentSelectors {
            guard let images = try? document.select(selector).array() else {
                continue
            }

            for image in images {
                if let imageURL = extractValidImageURL(from: image) {
                    return imageURL
                }
            }
        }

        return nil
    }

    private func extractValidImageURL(from image: Element) -> String? {
        guard let src = try? (image.attr("src").isEmpty ? image.attr("data-src") : image.attr("src")),
              !src.isEmpty else {
            return nil
        }

        if isLikelySmallOrIconImage(image) {
            return nil
        }

        return src
    }

    private func isLikelySmallOrIconImage(_ image: Element) -> Bool {
        let widthString = (try? image.attr("width")) ?? ""
        let heightString = (try? image.attr("height")) ?? ""

        if let width = Int(widthString), width < 200 {
            return true
        }

        if let height = Int(heightString), height < 200 {
            return true
        }

        let srcValue = ((try? image.attr("src")) ?? "").lowercased()
        let iconKeywords = ["icon", "logo", "avatar", "pixel", "tracking", "badge", "button"]

        return iconKeywords.contains { srcValue.contains($0) }
    }

    private func parseDateString(_ dateString: String) -> Date? {
        let formatters: [ISO8601DateFormatter] = [
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                return formatter
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let dateFormats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "MMM dd, yyyy",
            "MMMM dd, yyyy"
        ]

        for format in dateFormats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    private func buildThumbnailURL(from imageURLString: String?, baseURL: URL) -> URL? {
        guard let imageURLString else { return nil }

        if imageURLString.hasPrefix("http") {
            return URL(string: imageURLString)
        }

        if imageURLString.hasPrefix("/") {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = imageURLString
            components?.query = nil
            return components?.url
        }

        return nil
    }

    private func addHTTPSSchemeIfNeeded(to urlString: String) -> String {
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            return "https://" + urlString
        }
        return urlString
    }
}
