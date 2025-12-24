import Foundation
import SwiftUI

enum ArticleFilter {
    case readingList
    case favorites
    case archived

    var title: String {
        switch self {
        case .readingList: "Luego"
        case .favorites: "Favourites"
        case .archived: "Archived"
        }
    }

    var emptyStateIcon: String {
        switch self {
        case .readingList: "doc.text.fill"
        case .favorites: "heart.fill"
        case .archived: "archivebox.fill"
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .readingList: "No Articles"
        case .favorites: "No Favorites"
        case .archived: "No Archived Articles"
        }
    }

    var emptyStateDescription: String {
        switch self {
        case .readingList: "Save your first article to get started"
        case .favorites: "Articles you favorite will appear here"
        case .archived: "Archived articles will appear here"
        }
    }

    var emptyStateIconColor: Color {
        switch self {
        case .readingList: .gray
        case .favorites: .pink
        case .archived: .blue
        }
    }

    func filtered(_ articles: [Article]) -> [Article] {
        switch self {
        case .readingList: articles.filter { !$0.isFavorite && !$0.isArchived }
        case .favorites: articles.filter { $0.isFavorite }
        case .archived: articles.filter { $0.isArchived }
        }
    }
}
