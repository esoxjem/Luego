import Foundation
import SwiftSoup

enum ArticleMetadataError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError(Error)
    case noMetadata

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid or malformed."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Failed to parse article: \(error.localizedDescription)"
        case .noMetadata:
            return "No metadata found for this article."
        }
    }
}

@MainActor
class ArticleMetadataService {
    static let shared = ArticleMetadataService()

    private init() {}

    func fetchMetadata(from url: URL) async throws -> ArticleMetadata {
        try validateHTTPScheme(url)
        let htmlContent = try await fetchHTMLContent(from: url)
        let document = try parseHTML(htmlContent)

        let (ogTitle, ogImage, ogDescription) = extractOpenGraphMetadata(from: document)
        let (htmlTitle, metaDescription) = extractStandardMetadata(from: document)

        let title = ogTitle ?? htmlTitle ?? url.host() ?? url.absoluteString
        let thumbnailURL = buildThumbnailURL(from: ogImage, baseURL: url)
        let description = ogDescription ?? metaDescription

        return ArticleMetadata(
            title: title,
            thumbnailURL: thumbnailURL,
            description: description
        )
    }

    func validateURL(_ urlString: String) -> URL? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespaces)
        let urlWithScheme = addHTTPSSchemeIfNeeded(to: trimmedURL)

        guard let url = URL(string: urlWithScheme),
              (url.scheme == "http" || url.scheme == "https"),
              url.host() != nil else {
            return nil
        }

        return url
    }

    func fetchFullContent(from url: URL) async throws -> ArticleContent {
        try validateHTTPScheme(url)
        let htmlContent = try await fetchHTMLContent(from: url)
        let document = try parseHTML(htmlContent)

        try removeUnwantedElements(from: document)

        let (ogTitle, ogImage, ogDescription) = extractOpenGraphMetadata(from: document)
        let (htmlTitle, metaDescription) = extractStandardMetadata(from: document)

        let title = ogTitle ?? htmlTitle ?? url.host() ?? url.absoluteString
        let thumbnailURL = buildThumbnailURL(from: ogImage, baseURL: url)
        let description = ogDescription ?? metaDescription
        let content = try extractArticleContent(from: document)

        return ArticleContent(
            title: title,
            thumbnailURL: thumbnailURL,
            description: description,
            content: content
        )
    }

    private func validateHTTPScheme(_ url: URL) throws {
        guard url.scheme == "http" || url.scheme == "https" else {
            throw ArticleMetadataError.invalidURL
        }
    }

    private func fetchHTMLContent(from url: URL) async throws -> String {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
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
        try document.select("script, style, nav, header, footer, aside, iframe, .ad, .advertisement, .social-share").remove()
    }

    private func extractArticleContent(from document: Document) throws -> String {
        let container = try findMainContentContainer(in: document)
        let elements = try extractContentElements(from: container)
        let formattedText = formatContentElements(elements)

        guard formattedText.count > 200 else {
            throw ArticleMetadataError.noMetadata
        }

        return formattedText
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

    private func extractContentElements(from container: Element) throws -> [Element] {
        return try container.select("p, h1, h2, h3, h4, h5, h6, blockquote, ul, ol").array()
    }

    private func formatContentElements(_ elements: [Element]) -> String {
        var contentParts: [String] = []

        for element in elements {
            guard let text = try? element.text().trimmingCharacters(in: .whitespacesAndNewlines),
                  text.count > 20 else {
                continue
            }

            let formatted = formatElement(element, text: text)
            if !formatted.isEmpty {
                contentParts.append(formatted)
            }
        }

        return contentParts.joined(separator: "\n\n")
    }

    private func formatElement(_ element: Element, text: String) -> String {
        let tagName = element.tagName()

        switch tagName {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            return "\n# \(text)\n"
        case "blockquote":
            return "\n> \(text)\n"
        case "ul", "ol":
            return formatListElement(element)
        default:
            return text
        }
    }

    private func formatListElement(_ element: Element) -> String {
        guard let listItems = try? element.select("li").array() else {
            return ""
        }

        var items: [String] = []
        for item in listItems {
            if let itemText = try? item.text() {
                items.append("• \(itemText)")
            }
        }
        items.append("")

        return items.joined(separator: "\n")
    }
}
