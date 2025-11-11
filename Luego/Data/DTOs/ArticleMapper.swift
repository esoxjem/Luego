import Foundation
import SwiftData

extension Article {
    func toDomain() -> Domain.Article {
        Domain.Article(
            id: self.id,
            url: self.url,
            title: self.title,
            content: self.content,
            savedDate: self.savedDate,
            thumbnailURL: self.thumbnailURL,
            publishedDate: self.publishedDate,
            readPosition: self.readPosition
        )
    }

    static func fromDomain(_ article: Domain.Article) -> Article {
        Article(
            id: article.id,
            url: article.url,
            title: article.title,
            content: article.content,
            savedDate: article.savedDate,
            thumbnailURL: article.thumbnailURL,
            publishedDate: article.publishedDate,
            readPosition: article.readPosition
        )
    }
}
