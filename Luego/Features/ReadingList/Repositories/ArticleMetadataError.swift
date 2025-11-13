//
//  ArticleMetadataError.swift
//  Luego
//
//  Created by Arun Sasidharan on 13/11/25.
//

import Foundation

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
