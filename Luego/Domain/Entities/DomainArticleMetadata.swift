import Foundation

extension Domain {
    struct ArticleMetadata: Equatable, Sendable {
        let title: String
        let thumbnailURL: URL?
        let description: String?
        let publishedDate: Date?

        init(
            title: String,
            thumbnailURL: URL? = nil,
            description: String? = nil,
            publishedDate: Date? = nil
        ) {
            self.title = title
            self.thumbnailURL = thumbnailURL
            self.description = description
            self.publishedDate = publishedDate
        }
    }
}
