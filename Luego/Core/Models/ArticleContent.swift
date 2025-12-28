//
//  ArticleContent.swift
//  Luego
//
//  Created by Claude on 2025-11-10.
//

import Foundation

struct ArticleContent {
    let title: String
    let thumbnailURL: URL?
    let description: String?
    let content: String
    let publishedDate: Date?
    let author: String?
    let wordCount: Int?

    init(
        title: String,
        thumbnailURL: URL? = nil,
        description: String? = nil,
        content: String,
        publishedDate: Date? = nil,
        author: String? = nil,
        wordCount: Int? = nil
    ) {
        self.title = title
        self.thumbnailURL = thumbnailURL
        self.description = description
        self.content = content
        self.publishedDate = publishedDate
        self.author = author
        self.wordCount = wordCount
    }
}
