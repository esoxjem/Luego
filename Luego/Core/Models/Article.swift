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
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var url: URL
    var title: String
    var content: String?
    var savedDate: Date
    var thumbnailURL: URL?
    var publishedDate: Date?
    var readPosition: Double = 0.0
    var isFavorite: Bool = false
    var isArchived: Bool = false

    var domain: String {
        url.host() ?? url.absoluteString
    }

    var estimatedReadingTime: String {
        guard let content = content, !content.isEmpty else {
            return "0 min"
        }

        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let wordCount = words.count
        let wordsPerMinute = 200
        let minutes = max(1, Int(ceil(Double(wordCount) / Double(wordsPerMinute))))

        return "\(minutes) min"
    }

    init(id: UUID = UUID(), url: URL, title: String, content: String? = nil, savedDate: Date = Date(), thumbnailURL: URL? = nil, publishedDate: Date? = nil, readPosition: Double = 0.0, isFavorite: Bool = false, isArchived: Bool = false) {
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
    }
}

extension Article: Equatable {
    static func == (lhs: Article, rhs: Article) -> Bool {
        lhs.id == rhs.id
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
