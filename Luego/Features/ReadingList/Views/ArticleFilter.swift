import Foundation
import SwiftUI

enum ArticleFilter: CaseIterable, Hashable {
    case readingList
    case favorites
    case archived
    case discovery

    var title: String {
        switch self {
        case .readingList: "All Articles"
        case .favorites: "Favourites"
        case .archived: "Archived"
        case .discovery: "Discovery"
        }
    }

    var icon: String {
        switch self {
        case .readingList: "list.bullet"
        case .favorites: "heart"
        case .archived: "archivebox.fill"
        case .discovery: "die.face.5"
        }
    }

    var emptyStateIcon: String {
        switch self {
        case .readingList: "doc.text.fill"
        case .favorites: "heart.fill"
        case .archived: "archivebox.fill"
        case .discovery: "die.face.5"
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .readingList: "No Articles"
        case .favorites: "No Favorites"
        case .archived: "No Archived Articles"
        case .discovery: "Discover Something New"
        }
    }

    var emptyStateDescription: String {
        switch self {
        case .readingList: "Save your first article to get started"
        case .favorites: "Articles you favorite will appear here"
        case .archived: "Archived articles will appear here"
        case .discovery: "Tap shuffle to find interesting articles"
        }
    }

    var emptyStateIconColor: Color {
        switch self {
        case .readingList: .gray
        case .favorites: .pink
        case .archived: .blue
        case .discovery: .purple
        }
    }

    func filtered(_ articles: [Article]) -> [Article] {
        switch self {
        case .readingList: articles.filter { !$0.isFavorite && !$0.isArchived }
        case .favorites: articles.filter { $0.isFavorite }
        case .archived: articles.filter { $0.isArchived }
        case .discovery: []
        }
    }
}
