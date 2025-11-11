import Foundation

extension Domain {
    struct ArticleContent: Equatable, Sendable {
        let title: String
        let thumbnailURL: URL?
        let description: String?
        let content: String
        let publishedDate: Date?

        init(
            title: String,
            thumbnailURL: URL? = nil,
            description: String? = nil,
            content: String,
            publishedDate: Date? = nil
        ) {
            self.title = title
            self.thumbnailURL = thumbnailURL
            self.description = description
            self.content = content
            self.publishedDate = publishedDate
        }
    }
}
