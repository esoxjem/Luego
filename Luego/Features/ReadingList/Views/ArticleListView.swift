//
//  ArticleListView.swift
//  Luego
//
//  Created by Claude Code on 11/12/25.
//

import SwiftUI

struct ArticleListView: View {
    @Environment(\.diContainer) private var diContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ArticleListViewModel?
    @State private var showingAddArticle = false
    @State private var showingDiscovery = false
    let filter: ArticleFilter

    var body: some View {
        ArticleListContent(
            viewModel: viewModel,
            diContainer: diContainer,
            onAddArticle: { showingAddArticle = true }
        )
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if filter == .readingList {
                    Button {
                        showingDiscovery = true
                    } label: {
                        Image(systemName: "die.face.5")
                    }
                }
                Button {
                    showingAddArticle = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            configureNavigationBarAppearance()
        }
        .sheet(isPresented: $showingAddArticle) {
            if let viewModel {
                AddArticleView(viewModel: viewModel)
            }
        }
        .fullScreenCover(isPresented: $showingDiscovery) {
            if let container = diContainer {
                DiscoveryReaderView(viewModel: container.makeDiscoveryViewModel())
            }
        }
        .task {
            await initializeViewModelIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task {
                await handleScenePhaseChange(newPhase)
            }
        }
    }

    private func initializeViewModelIfNeeded() async {
        guard viewModel == nil, let container = diContainer else { return }
        viewModel = container.makeArticleListViewModel()
        viewModel?.setFilter(filter)
        await viewModel?.loadArticles()
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) async {
        guard phase == .active, let viewModel else { return }
        await viewModel.syncSharedArticles()
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [.font: serifBoldLargeTitleFont]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    private var serifBoldLargeTitleFont: UIFont {
        UIFont(
            descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
                .withDesign(.serif)!
                .withSymbolicTraits(.traitBold)!,
            size: 0
        )
    }

    private var navigationTitle: String {
        switch filter {
        case .readingList:
            return "Luego"
        case .favorites:
            return "Favourites"
        case .archived:
            return "Archived"
        }
    }
}

struct ArticleListContent: View {
    let viewModel: ArticleListViewModel?
    let diContainer: DIContainer?
    let onAddArticle: () -> Void

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.filteredArticles.isEmpty {
                    ArticleListEmptyState(onAddArticle: onAddArticle, filter: viewModel.filter)
                } else {
                    ArticleList(viewModel: viewModel, diContainer: diContainer)
                }
            } else {
                ProgressView()
            }
        }
    }
}

struct ArticleList: View {
    let viewModel: ArticleListViewModel
    let diContainer: DIContainer?

    var body: some View {
        List {
            ForEach(viewModel.filteredArticles) { article in
                NavigationLink {
                    ArticleReaderDestination(article: article, diContainer: diContainer)
                } label: {
                    ArticleRowView(article: article)
                }
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
        Button {
            Task {
                await viewModel.toggleFavorite(article)
            }
        } label: {
            Label(
                article.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: article.isFavorite ? "heart.slash.fill" : "heart.fill"
            )
        }
        .tint(article.isFavorite ? .gray : .red)
    }

    private func archiveButton(for article: Article) -> some View {
        Button {
            Task {
                await viewModel.toggleArchive(article)
            }
        } label: {
            Label(
                article.isArchived ? "Unarchive" : "Archive",
                systemImage: article.isArchived ? "tray.and.arrow.up.fill" : "archivebox.fill"
            )
        }
        .tint(.blue)
    }

    private func deleteButton(for article: Article) -> some View {
        Button(role: .destructive) {
            Task {
                await viewModel.deleteArticle(article)
            }
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
    }
}

struct ArticleReaderDestination: View {
    let article: Article
    let diContainer: DIContainer?

    var body: some View {
        if let container = diContainer {
            let readerViewModel = container.makeReaderViewModel(article: article)
            ReaderView(viewModel: readerViewModel)
        }
    }
}

struct ArticleListEmptyState: View {
    let onAddArticle: () -> Void
    let filter: ArticleFilter

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 8) {
                Image(systemName: emptyStateIcon)
                    .font(.system(size: 64))
                    .foregroundStyle(iconColor)
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        } description: {
            Text(emptyStateDescription)
        } actions: {
            if filter == .readingList {
                Button("Add Article") {
                    onAddArticle()
                }
                .buttonStyle(.glassProminent)
                .tint(.purple)
            }
        }
    }

    private var iconColor: Color {
        switch filter {
        case .readingList:
            return .gray
        case .favorites:
            return .pink
        case .archived:
            return .blue
        }
    }

    private var emptyStateTitle: String {
        switch filter {
        case .readingList:
            return "No Articles"
        case .favorites:
            return "No Favorites"
        case .archived:
            return "No Archived Articles"
        }
    }

    private var emptyStateIcon: String {
        switch filter {
        case .readingList:
            return "doc.text.fill"
        case .favorites:
            return "heart.fill"
        case .archived:
            return "archivebox.fill"
        }
    }

    private var emptyStateDescription: String {
        switch filter {
        case .readingList:
            return "Save your first article to get started"
        case .favorites:
            return "Articles you favorite will appear here"
        case .archived:
            return "Archived articles will appear here"
        }
    }
}

