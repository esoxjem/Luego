import Foundation

extension ArticleMetadata {
    func toDomain() -> Domain.ArticleMetadata {
        Domain.ArticleMetadata(
            title: self.title,
            thumbnailURL: self.thumbnailURL,
            description: self.description,
            publishedDate: self.publishedDate
        )
    }

    static func fromDomain(_ metadata: Domain.ArticleMetadata) -> ArticleMetadata {
        ArticleMetadata(
            title: metadata.title,
            thumbnailURL: metadata.thumbnailURL,
            description: metadata.description,
            publishedDate: metadata.publishedDate
        )
    }
}

extension ArticleContent {
    func toDomain() -> Domain.ArticleContent {
        Domain.ArticleContent(
            title: self.title,
            thumbnailURL: self.thumbnailURL,
            description: self.description,
            content: self.content,
            publishedDate: self.publishedDate
        )
    }

    static func fromDomain(_ content: Domain.ArticleContent) -> ArticleContent {
        ArticleContent(
            title: content.title,
            thumbnailURL: content.thumbnailURL,
            description: content.description,
            content: content.content,
            publishedDate: content.publishedDate
        )
    }
}
