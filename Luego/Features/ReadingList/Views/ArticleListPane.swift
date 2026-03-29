import SwiftUI

struct ArticleListPane: View {
    let filter: ArticleFilter
    @Binding var selectedArticle: Article?
    let onDiscover: () -> Void
    let shouldAnimateEmptyStateOnFirstAppearance: Bool
    let onEmptyStateAnimationConsumed: () -> Void
    @Environment(\.diContainer) private var diContainer
    @Environment(SyncStatusObserver.self) private var syncStatusObserver: SyncStatusObserver?
    @State private var viewModel: ArticleListViewModel?
    @State private var showingAddArticle = false
    @State private var showingSettings = false

    private var filteredArticles: [Article] {
        filter.filtered(viewModel?.articles ?? [])
    }

    private var restoreStatusText: String? {
        guard filter == .readingList, syncStatusObserver?.state == .restoring else { return nil }
        return "Restoring articles from iCloud."
    }

    var body: some View {
        Group {
            if let viewModel {
                if filteredArticles.isEmpty {
                    emptyState(for: viewModel)
                } else {
                    SelectableArticleList(
                        articles: filteredArticles,
                        viewModel: viewModel,
                        selection: $selectedArticle,
                        filter: filter,
                        onRefresh: { await viewModel.refreshArticles() }
                    )
                }
            } else {
                ProgressView()
            }
        }
        #if os(iOS)
        .background(Color.regularPanelBackground)
        .appNavigationStyle(.contentLargeTitle)
        #endif
        #if os(macOS)
        .background(MacAppBackground())
        #endif
        .navigationTitle(filter.navigationTitle)
        #if !os(macOS)
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
#if !os(macOS)
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                #endif
            }
        }
        #endif
        #if !os(macOS)
        .sheet(isPresented: $showingAddArticle) {
            if let viewModel {
                AddArticleView(viewModel: viewModel)
            }
        }
        #endif
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
            viewModel?.startObservingArticles()
        }
    }

    @ViewBuilder
    private func emptyState(for viewModel: ArticleListViewModel) -> some View {
        let content = ArticleListEmptyState(
            onDiscover: onDiscover,
            filter: filter,
            restoreStatusText: restoreStatusText,
            shouldAnimateCopyOnFirstAppearance: filter == .readingList && shouldAnimateEmptyStateOnFirstAppearance,
            onCopyAnimationConsumed: onEmptyStateAnimationConsumed
        )

        #if os(iOS)
        RefreshableEmptyStateContainer(onRefresh: { await viewModel.refreshArticles() }) {
            content
        }
        #else
        content
        #endif
    }
}

struct SelectableArticleList: View {
    let articles: [Article]
    let viewModel: ArticleListViewModel
    @Binding var selection: Article?
    let filter: ArticleFilter
    let onRefresh: () async -> Void

    private var swipeActions: ArticleSwipeActions {
        ArticleSwipeActions(
            filter: filter,
            viewModel: viewModel,
            onDelete: { article in
                if selection?.id == article.id {
                    selection = nil
                }
            }
        )
    }

    var body: some View {
        List {
            ForEach(articles) { article in
                Button {
                    selection = article
                } label: {
                    ArticleRowView(article: article, isSelected: selection?.id == article.id)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(selectionBackground(isSelected: selection?.id == article.id))
                #if os(macOS)
                .contextMenu {
                    contextMenuItems(for: article)
                }
                #else
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    swipeActions.favoriteButton(for: article)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    swipeActions.archiveButton(for: article)
                    swipeActions.deleteButton(for: article)
                }
                #endif
            }
        }
        #if os(macOS)
        .listStyle(.plain)
        #endif
        .scrollContentBackground(.hidden)
        .background(Color.regularPanelBackground)
        #if os(iOS)
        .refreshable {
            await onRefresh()
        }
        #endif
    }

    private func selectionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(isSelected ? Color.regularSelectionFill : Color.clear)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
    }

    #if os(macOS)
    @ViewBuilder
    private func contextMenuItems(for article: Article) -> some View {
        let isFavorited = article.isFavorite
        let isArchived = filter == .archived

        Button {
            Task { await viewModel.toggleFavorite(article) }
        } label: {
            Label(
                isFavorited ? "Remove from Favorites" : "Add to Favorites",
                systemImage: isFavorited ? "star.slash" : "star"
            )
        }

        Button {
            Task { await viewModel.toggleArchive(article) }
        } label: {
            Label(
                isArchived ? "Unarchive" : "Archive",
                systemImage: isArchived ? "tray.and.arrow.up" : "archivebox"
            )
        }

        Divider()

        Button(role: .destructive) {
            Task {
                if selection?.id == article.id {
                    selection = nil
                }
                await viewModel.deleteArticle(article)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    #endif
}
