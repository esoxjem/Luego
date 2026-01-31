//
//  Article.swift
//  Luego
//
//  Created by Claude on 2025-11-10.
//

import Foundation
import SwiftData

@Model
final class Article {
    var id: UUID = UUID()
    var url: URL = URL(string: "luego://placeholder")!
    var title: String = ""
    var content: String?
    var savedDate: Date = Date()
    var thumbnailURL: URL?
    var publishedDate: Date?
    var readPosition: Double = 0.0
    var isFavorite: Bool = false
    var isArchived: Bool = false
    var author: String?
    var wordCount: Int?

    var domain: String {
        url.host() ?? url.absoluteString
    }

    var estimatedReadingTime: String {
        if let wordCount = wordCount, wordCount > 0 {
            let wordsPerMinute = 200
            let minutes = max(1, Int(ceil(Double(wordCount) / Double(wordsPerMinute))))
            return "\(minutes) min"
        }

        guard let content = content, !content.isEmpty else {
            return "0 min"
        }

        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let calculatedWordCount = words.count
        let wordsPerMinute = 200
        let minutes = max(1, Int(ceil(Double(calculatedWordCount) / Double(wordsPerMinute))))

        return "\(minutes) min"
    }

    init(id: UUID = UUID(), url: URL, title: String, content: String? = nil, savedDate: Date = Date(), thumbnailURL: URL? = nil, publishedDate: Date? = nil, readPosition: Double = 0.0, isFavorite: Bool = false, isArchived: Bool = false, author: String? = nil, wordCount: Int? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.content = content
        self.savedDate = savedDate
        self.thumbnailURL = thumbnailURL
        self.publishedDate = publishedDate
        self.readPosition = readPosition
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.author = author
        self.wordCount = wordCount
    }
}

extension Article: Equatable {
    static func == (lhs: Article, rhs: Article) -> Bool {
        lhs.id == rhs.id
    }
}

extension Article {
    var excerpt: String {
        guard let content = content, !content.isEmpty else { return "" }

        let textToProcess = String(content.prefix(500))
        let stripped = textToProcess.strippingMarkdown()
        let cleaned = stripped
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if cleaned.count <= 120 {
            return cleaned
        }

        let truncated = String(cleaned.prefix(120))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "…"
        }
        return truncated + "…"
    }
}

extension String {
    func strippingMarkdown() -> String {
        var result = self

        if let codeBlockRegex = try? NSRegularExpression(pattern: #"```.*?```"#, options: [.dotMatchesLineSeparators]) {
            result = codeBlockRegex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        let patterns: [(pattern: String, replacement: String)] = [
            (#"!\[([^\]]*)\]\([^)]+\)"#, ""),           // Images
            (#"\[([^\]]+)\]\([^)]+\)"#, "$1"),          // Links → keep text
            (#"^#{1,6}\s+"#, ""),                        // Headers
            (#"\*\*([^*]+)\*\*"#, "$1"),                // Bold
            (#"__([^_]+)__"#, "$1"),                    // Bold alt
            (#"\*([^*]+)\*"#, "$1"),                    // Italic
            (#"_([^_]+)_"#, "$1"),                      // Italic alt
            (#"~~([^~]+)~~"#, "$1"),                    // Strikethrough
            (#"`([^`]+)`"#, "$1"),                      // Inline code
            (#"^>\s+"#, ""),                            // Blockquotes
            (#"^[-*+]\s+"#, ""),                        // List items
            (#"^\d+\.\s+"#, ""),                        // Numbered lists
            (#"^---+$"#, ""),                           // Horizontal rules
            (#"^___+$"#, ""),                           // Horizontal rules alt
        ]

        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Article {
    static let sampleArticles: [Article] = [
        Article(
            url: URL(string: "https://www.example.com/article1")!,
            title: "Understanding SwiftUI State Management",
            content: "Sample content about SwiftUI state...",
            savedDate: Date().addingTimeInterval(-86400),
            thumbnailURL: URL(string: "https://www.example.com/image1.jpg"),
            publishedDate: Date().addingTimeInterval(-172800)
        ),
        Article(
            url: URL(string: "https://www.medium.com/article2")!,
            title: "Building iOS Apps in 2025",
            content: "Sample content about iOS development...",
            savedDate: Date().addingTimeInterval(-3600),
            thumbnailURL: URL(string: "https://www.medium.com/image2.jpg"),
            publishedDate: Date().addingTimeInterval(-7200)
        ),
        Article(
            url: URL(string: "https://www.blog.com/article3")!,
            title: "The Future of Mobile Development",
            savedDate: Date(),
            publishedDate: Date().addingTimeInterval(-604800)
        )
    ]
}
