import Foundation
import SwiftSoup

protocol MetadataDataSourceProtocol: Sendable {
    func validateURL(_ url: URL) async throws -> URL
    func fetchMetadata(for url: URL, timeout: TimeInterval?) async throws -> ArticleMetadata
    func fetchContent(for url: URL, timeout: TimeInterval?) async throws -> ArticleContent
}

extension MetadataDataSourceProtocol {
    func fetchMetadata(for url: URL) async throws -> ArticleMetadata {
        try await fetchMetadata(for: url, timeout: nil)
    }

    func fetchContent(for url: URL) async throws -> ArticleContent {
        try await fetchContent(for: url, timeout: nil)
    }
}

@MainActor
final class MetadataDataSource: MetadataDataSourceProtocol {
    private let turndownDataSource: TurndownDataSource

    init(turndownDataSource: TurndownDataSource) {
        self.turndownDataSource = turndownDataSource
    }

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

    func fetchContent(for url: URL, timeout: TimeInterval?) async throws -> ArticleContent {
        try validateHTTPScheme(url)
        let htmlContent = try await fetchHTMLContent(from: url, timeout: timeout)
        let document = try parseHTML(htmlContent)

        try removeUnwantedElements(from: document)

        let (ogTitle, ogImage, ogDescription) = extractOpenGraphMetadata(from: document)
        let (htmlTitle, metaDescription) = extractStandardMetadata(from: document)
        let publishedDate = extractPublishedDate(from: document)

        let title = ogTitle ?? htmlTitle ?? url.host() ?? url.absoluteString
        let imageURL = ogImage ?? extractFirstImageURL(from: document)
        let thumbnailURL = buildThumbnailURL(from: imageURL, baseURL: url)
        let description = ogDescription ?? metaDescription
        let content = try extractArticleContent(from: document, baseURL: url)

        return ArticleContent(
            title: title,
            thumbnailURL: thumbnailURL,
            description: description,
            content: content,
            publishedDate: publishedDate
        )
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

    private func removeUnwantedElements(from document: Document) throws {
        try document.select("script, style, nav, header, footer, aside, iframe, svg, .ad, .advertisement, .social-share").remove()
    }

    private func extractArticleContent(from document: Document, baseURL: URL) throws -> String {
        let container = try findMainContentContainer(in: document)

        guard let html = try? container.html() else {
            throw ArticleMetadataError.noMetadata
        }

        if let markdown = turndownDataSource.convert(html) {
            let resolved = resolveRelativeURLsInMarkdown(markdown, baseURL: baseURL)
            if resolved.count > 200 {
                return resolved
            }
        }

        let plainTextContent = try extractPlainTextContent(from: container)
        guard plainTextContent.count > 200 else {
            throw ArticleMetadataError.noMetadata
        }

        return plainTextContent
    }

    private func resolveRelativeURLsInMarkdown(_ markdown: String, baseURL: URL) -> String {
        var result = markdown

        result = resolveMarkdownURLs(in: result, pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)", baseURL: baseURL, isImage: true)
        result = resolveMarkdownURLs(in: result, pattern: "\\[([^\\]]*)\\]\\(([^)]+)\\)", baseURL: baseURL, isImage: false)

        return result
    }

    private func resolveMarkdownURLs(in text: String, pattern: String, baseURL: URL, isImage: Bool) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        var result = text
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let fullRange = match.range
            let altRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            let alt = nsString.substring(with: altRange)
            let url = nsString.substring(with: urlRange)

            if let resolvedURL = resolveImageURL(url, baseURL: baseURL) {
                let prefix = isImage ? "![" : "["
                let replacement = "\(prefix)\(alt)](\(resolvedURL))"
                result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
            }
        }

        return result
    }

    private func findMainContentContainer(in document: Document) throws -> Element {
        let contentSelectors = [
            "article",
            "main",
            "[role=main]",
            ".post-content",
            ".article-content",
            ".entry-content",
            ".content",
            "body"
        ]

        for selector in contentSelectors {
            if let container = try? document.select(selector).first(),
               isValidContentContainer(container) {
                return container
            }
        }

        return try document.select("body").first() ?? {
            throw ArticleMetadataError.noMetadata
        }()
    }

    private func isValidContentContainer(_ container: Element) -> Bool {
        guard let text = try? container.text() else { return false }
        return text.count > 100
    }

    private func resolveImageURL(_ imageURL: String, baseURL: URL) -> String? {
        if imageURL.hasPrefix("http://") || imageURL.hasPrefix("https://") {
            return imageURL
        }

        if imageURL.hasPrefix("//") {
            return "https:" + imageURL
        }

        if imageURL.hasPrefix("/") {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.path = imageURL
            components?.query = nil
            return components?.url?.absoluteString
        }

        if imageURL.hasPrefix("data:") {
            return imageURL
        }

        return nil
    }

    private func normalizeWhitespace(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private func extractPlainTextContent(from container: Element) throws -> String {
        guard let html = try? container.html() else {
            throw ArticleMetadataError.noMetadata
        }

        let htmlWithBreaks = html
            .replacingOccurrences(of: "<br>", with: "|||BREAK|||", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: "|||BREAK|||", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: "|||BREAK|||", options: .caseInsensitive)

        let modifiedDocument = try SwiftSoup.parse(htmlWithBreaks)
        guard let text = try? modifiedDocument.body()?.text() else {
            throw ArticleMetadataError.noMetadata
        }

        let textWithNewlines = text.replacingOccurrences(of: "|||BREAK|||", with: "\n")
        let paragraphs = splitIntoParagraphs(textWithNewlines)
        let cleanedParagraphs = filterAndCleanParagraphs(paragraphs)

        return cleanedParagraphs.joined(separator: "\n\n")
    }

    private func splitIntoParagraphs(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var paragraphs: [String] = []
        var currentParagraph: [String] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.isEmpty {
                if !currentParagraph.isEmpty {
                    let joined = currentParagraph.joined(separator: " ")
                    paragraphs.append(normalizeWhitespace(joined))
                    currentParagraph = []
                }
            } else {
                currentParagraph.append(trimmedLine)
            }
        }

        if !currentParagraph.isEmpty {
            let joined = currentParagraph.joined(separator: " ")
            paragraphs.append(normalizeWhitespace(joined))
        }

        return paragraphs
    }

    private func filterAndCleanParagraphs(_ paragraphs: [String]) -> [String] {
        return paragraphs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { paragraph in
                paragraph.count > 30 &&
                !isNavigationOrMetadata(paragraph)
            }
    }

    private func isNavigationOrMetadata(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let navigationKeywords = [
            "cookie", "privacy policy", "terms of service",
            "subscribe", "newsletter", "share this",
            "follow us", "copyright ©", "all rights reserved"
        ]

        return navigationKeywords.contains { lowercased.contains($0) }
    }
}
