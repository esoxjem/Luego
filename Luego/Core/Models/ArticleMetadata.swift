//
//  ArticleMetadata.swift
//  Luego
//
//  Created by Claude on 2025-11-10.
//

import Foundation

struct ArticleMetadata {
    let title: String
    let thumbnailURL: URL?
    let description: String?
    let publishedDate: Date?
}

enum ArticleMetadataError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError(Error)
    case noMetadata

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided is not valid"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse the article content"
        case .noMetadata:
            return "Could not find article metadata"
        }
    }
}
