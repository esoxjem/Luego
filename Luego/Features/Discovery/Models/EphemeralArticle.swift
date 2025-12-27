import Foundation

struct EphemeralArticle: Sendable {
    let url: URL
    let title: String
    let content: String
    let thumbnailURL: URL?
    let publishedDate: Date?
    let feedTitle: String

    var domain: String {
        url.host() ?? url.absoluteString
    }

    var estimatedReadingTime: String {
        let wordCount = content.split { $0.isWhitespace || $0.isNewline }.count
        let minutes = max(1, wordCount / 200)
        return "\(minutes) min read"
    }
}
