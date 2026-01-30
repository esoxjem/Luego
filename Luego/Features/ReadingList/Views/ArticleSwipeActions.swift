import SwiftUI

struct ArticleSwipeActions {
    let filter: ArticleFilter
    let viewModel: ArticleListViewModel
    var onDelete: ((Article) -> Void)?

    func favoriteButton(for article: Article) -> some View {
        let isFavorited = filter == .favorites
        return Button {
            Task {
                await viewModel.toggleFavorite(article)
            }
        } label: {
            Label(
                isFavorited ? "Unfavorite" : "Favorite",
                systemImage: isFavorited ? "heart.slash.fill" : "heart.fill"
            )
        }
        .tint(isFavorited ? .gray : .red)
    }

    func archiveButton(for article: Article) -> some View {
        let isArchived = filter == .archived
        return Button {
            Task {
                await viewModel.toggleArchive(article)
            }
        } label: {
            Label(
                isArchived ? "Unarchive" : "Archive",
                systemImage: isArchived ? "tray.and.arrow.up.fill" : "archivebox.fill"
            )
        }
        .tint(.blue)
    }

    func deleteButton(for article: Article) -> some View {
        Button(role: .destructive) {
            Task {
                onDelete?(article)
                await viewModel.deleteArticle(article)
            }
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
    }
}
