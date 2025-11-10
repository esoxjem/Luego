//
//  Article.swift
//  Readit
//
//  Created by Claude on 2025-11-10.
//

import Foundation
import SwiftData

@Model
class Article {
    @Attribute(.unique) var id: UUID
    var url: URL
    var title: String
    var content: String?
    var savedDate: Date
    var thumbnailURL: URL?

    var domain: String {
        url.host() ?? url.absoluteString
    }

    init(id: UUID = UUID(), url: URL, title: String, content: String? = nil, savedDate: Date = Date(), thumbnailURL: URL? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.content = content
        self.savedDate = savedDate
        self.thumbnailURL = thumbnailURL
    }
}

extension Article {
    static let sampleArticles: [Article] = [
        Article(
            url: URL(string: "https://www.example.com/article1")!,
            title: "Understanding SwiftUI State Management",
            content: "Sample content about SwiftUI state...",
            savedDate: Date().addingTimeInterval(-86400), // 1 day ago
            thumbnailURL: URL(string: "https://www.example.com/image1.jpg")
        ),
        Article(
            url: URL(string: "https://www.medium.com/article2")!,
            title: "Building iOS Apps in 2025",
            content: "Sample content about iOS development...",
            savedDate: Date().addingTimeInterval(-3600), // 1 hour ago
            thumbnailURL: URL(string: "https://www.medium.com/image2.jpg")
        ),
        Article(
            url: URL(string: "https://www.blog.com/article3")!,
            title: "The Future of Mobile Development",
            savedDate: Date()
        )
    ]
}
