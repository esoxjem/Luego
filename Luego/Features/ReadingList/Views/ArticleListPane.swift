import SwiftUI
import SwiftData

struct ArticleListPane: View {
    let filter: ArticleFilter
    @Binding var selectedArticle: Article?
    let onDiscover: () -> Void
    @Environment(\.diContainer) private var diContainer
    @Query(sort: \Article.savedDate, order: .reverse) private var allArticles: [Article]
    @State private var viewModel: ArticleListViewModel?
    @State private var showingAddArticle = false
    @State private var showingSettings = false

    private var filteredArticles: [Article] {
        filter.filtered(allArticles)
    }

    var body: some View {
        Group {
            if let viewModel {
                if filteredArticles.isEmpty {
                    ArticleListEmptyState(onDiscover: onDiscover, filter: filter)
                } else {
                    SelectableArticleList(
                        articles: filteredArticles,
                        viewModel: viewModel,
                        selection: $selectedArticle,
                        filter: filter
                    )
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(filter.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if filter == .readingList {
                    Button(action: onDiscover) {
                        Image(systemName: "die.face.5")
                    }
                    .accessibilityLabel("Inspire Me")
                }
                Button {
                    showingAddArticle = true
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingAddArticle) {
            if let viewModel {
                AddArticleView(viewModel: viewModel, existingArticles: allArticles)
            }
        }
        .sheet(isPresented: $showingSettings) {
            if let container = diContainer {
                NavigationStack {
                    SettingsView(viewModel: container.makeSettingsViewModel())
                }
            }
        }
        .task {
            if viewModel == nil, let container = diContainer {
                viewModel = container.makeArticleListViewModel()
            }
        }
    }
}

struct SelectableArticleList: View {
    let articles: [Article]
    let viewModel: ArticleListViewModel
    @Binding var selection: Article?
    let filter: ArticleFilter

    var body: some View {
        List {
            ForEach(articles) { article in
                Button {
                    selection = article
                } label: {
                    ArticleRowView(article: article)
                }
                .listRowBackground(selection?.id == article.id ? Color.accentColor.opacity(0.2) : Color.clear)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    favoriteButton(for: article)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    archiveButton(for: article)
                    deleteButton(for: article)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func favoriteButton(for article: Article) -> some View {
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

    private func archiveButton(for article: Article) -> some View {
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

    private func deleteButton(for article: Article) -> some View {
        Button(role: .destructive) {
            Task {
                if selection?.id == article.id {
                    selection = nil
                }
                await viewModel.deleteArticle(article)
            }
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
    }
}
