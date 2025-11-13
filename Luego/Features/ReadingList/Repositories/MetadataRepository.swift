import Foundation
import SwiftSoup

protocol MetadataRepositoryProtocol: Sendable {
    func validateURL(_ url: URL) async throws -> URL
    func fetchMetadata(for url: URL) async throws -> ArticleMetadata
    func fetchContent(for url: URL) async throws -> ArticleContent
}

@MainActor
final class MetadataRepository: MetadataRepositoryProtocol {
    func validateURL(_ url: URL) async throws -> URL {
        let urlString = url.absoluteString
        guard let validatedURL = validateURLString(urlString) else {
            throw ArticleMetadataError.invalidURL
        }
        return validatedURL
    }

    func fetchMetadata(for url: URL) async throws -> ArticleMetadata {
        try validateHTTPScheme(url)
        let htmlContent = try await fetchHTMLContent(from: url)
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

    func fetchContent(for url: URL) async throws -> ArticleContent {
        try validateHTTPScheme(url)
        let htmlContent = try await fetchHTMLContent(from: url)
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
        try document.select("script, style, nav, header, footer, aside, iframe, .ad, .advertisement, .social-share").remove()
    }

    private func extractArticleContent(from document: Document, baseURL: URL) throws -> String {
        let container = try findMainContentContainer(in: document)
        let elements = try extractContentElements(from: container)
        let formattedText = formatContentElements(elements, baseURL: baseURL)

        if formattedText.count > 200 {
            return formattedText
        }

        let plainTextContent = try extractPlainTextContent(from: container)
        guard plainTextContent.count > 200 else {
            throw ArticleMetadataError.noMetadata
        }

        return plainTextContent
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
        let allElements = try container.select("p, h1, h2, h3, h4, h5, h6, blockquote, ul, ol, img").array()
        return removeDescendantDuplicates(from: allElements)
    }

    private func removeDescendantDuplicates(from elements: [Element]) -> [Element] {
        var result: [Element] = []

        for element in elements {
            let isDescendant = result.contains { potentialAncestor in
                isDescendantOf(element, ancestor: potentialAncestor)
            }

            if !isDescendant {
                result.append(element)
            }
        }

        return result
    }

    private func isDescendantOf(_ element: Element, ancestor: Element) -> Bool {
        var current = element.parent()

        while let parent = current {
            if parent === ancestor {
                return true
            }
            current = parent.parent()
        }

        return false
    }

    private func formatContentElements(_ elements: [Element], baseURL: URL) -> String {
        var contentParts: [String] = []

        for element in elements {
            let markdownText = convertElementToMarkdown(element, baseURL: baseURL)

            let minLength = isHeadingOrImageElement(element) ? 3 : 20
            guard markdownText.count > minLength else {
                continue
            }

            let formatted = formatElement(element, text: markdownText, baseURL: baseURL)
            if !formatted.isEmpty {
                contentParts.append(formatted)
            }
        }

        return contentParts.joined(separator: "\n\n")
    }

    private func convertElementToMarkdown(_ element: Element, baseURL: URL) -> String {
        let tagName = element.tagName()

        if tagName == "img" {
            return convertImageToMarkdown(element, baseURL: baseURL)
        }

        guard let html = try? element.html() else {
            return ""
        }

        var markdown = html

        markdown = convertInlineImagesToMarkdown(markdown, baseURL: baseURL)

        markdown = markdown.replacingOccurrences(of: "<li>", with: "\n- ", options: .caseInsensitive)
        markdown = markdown.replacingOccurrences(of: "</li>", with: "", options: .caseInsensitive)
        markdown = markdown.replacingOccurrences(of: "</?ul>", with: "\n", options: [.regularExpression, .caseInsensitive])
        markdown = markdown.replacingOccurrences(of: "</?ol>", with: "\n", options: [.regularExpression, .caseInsensitive])

        markdown = markdown.replacingOccurrences(of: "<strong>(.*?)</strong>", with: "**$1**", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<b>(.*?)</b>", with: "**$1**", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<em>(.*?)</em>", with: "*$1*", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<i>(.*?)</i>", with: "*$1*", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<code>(.*?)</code>", with: "`$1`", options: .regularExpression)

        markdown = markdown.replacingOccurrences(of: "<a[^>]*href=\"([^\"]*)\"[^>]*>(.*?)</a>", with: "[$2]($1)", options: .regularExpression)

        markdown = markdown.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        markdown = markdown.replacingOccurrences(of: "&amp;", with: "&")
        markdown = markdown.replacingOccurrences(of: "&lt;", with: "<")
        markdown = markdown.replacingOccurrences(of: "&gt;", with: ">")
        markdown = markdown.replacingOccurrences(of: "&quot;", with: "\"")
        markdown = markdown.replacingOccurrences(of: "&#39;", with: "'")
        markdown = markdown.replacingOccurrences(of: "&nbsp;", with: " ")

        markdown = markdown.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func convertImageToMarkdown(_ element: Element, baseURL: URL) -> String {
        guard let src = try? element.attr("src"), !src.isEmpty else {
            return ""
        }

        let alt = (try? element.attr("alt")) ?? ""
        let title = (try? element.attr("title")) ?? nil

        guard let resolvedURL = resolveImageURL(src, baseURL: baseURL) else {
            return ""
        }

        if let title = title, !title.isEmpty {
            return "![\(alt)](\(resolvedURL) \"\(title)\")"
        } else {
            return "![\(alt)](\(resolvedURL))"
        }
    }

    private func convertInlineImagesToMarkdown(_ html: String, baseURL: URL) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "<img[^>]*?(?:src=\"([^\"]*)\"[^>]*?alt=\"([^\"]*)\"[^>]*?|alt=\"([^\"]*)\"[^>]*?src=\"([^\"]*)\"[^>]*?|src=\"([^\"]*)\"[^>]*?)>",
            options: [.caseInsensitive]
        ) else {
            return html
        }

        let nsString = html as NSString
        let results = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))

        var output = html
        var offset = 0

        for result in results {
            let matchRange = NSRange(location: result.range.location + offset, length: result.range.length)
            var src: String?
            var alt: String = ""

            if result.range(at: 1).location != NSNotFound {
                src = nsString.substring(with: result.range(at: 1))
                if result.range(at: 2).location != NSNotFound {
                    alt = nsString.substring(with: result.range(at: 2))
                }
            } else if result.range(at: 4).location != NSNotFound {
                src = nsString.substring(with: result.range(at: 4))
                if result.range(at: 3).location != NSNotFound {
                    alt = nsString.substring(with: result.range(at: 3))
                }
            } else if result.range(at: 5).location != NSNotFound {
                src = nsString.substring(with: result.range(at: 5))
            }

            guard let imageSrc = src,
                  let resolvedURL = resolveImageURL(imageSrc, baseURL: baseURL) else {
                continue
            }

            let markdown = "![\(alt)](\(resolvedURL))"
            let outputNS = output as NSString
            output = outputNS.replacingCharacters(in: matchRange, with: markdown)

            offset += markdown.count - result.range.length
        }

        return output
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

    private func isHeadingElement(_ element: Element) -> Bool {
        let tagName = element.tagName()
        return ["h1", "h2", "h3", "h4", "h5", "h6"].contains(tagName)
    }

    private func isHeadingOrImageElement(_ element: Element) -> Bool {
        let tagName = element.tagName()
        return ["h1", "h2", "h3", "h4", "h5", "h6", "img"].contains(tagName)
    }

    private func normalizeWhitespace(_ text: String) -> String {
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private func formatElement(_ element: Element, text: String, baseURL: URL) -> String {
        let tagName = element.tagName()

        switch tagName {
        case "h1":
            return "# \(text)"
        case "h2":
            return "## \(text)"
        case "h3":
            return "### \(text)"
        case "h4":
            return "#### \(text)"
        case "h5":
            return "##### \(text)"
        case "h6":
            return "###### \(text)"
        case "blockquote":
            return "> \(text)"
        case "ul", "ol":
            return formatListElement(element, baseURL: baseURL)
        default:
            return text
        }
    }

    private func formatListElement(_ element: Element, baseURL: URL) -> String {
        guard let listItems = try? element.select("li").array() else {
            return ""
        }

        var items: [String] = []
        for item in listItems {
            let markdownText = convertElementToMarkdown(item, baseURL: baseURL)
            if !markdownText.isEmpty {
                items.append("- \(markdownText)")
            }
        }

        return items.joined(separator: "\n")
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
