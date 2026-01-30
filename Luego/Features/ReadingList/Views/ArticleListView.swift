//
//  ArticleListView.swift
//  Luego
//
//  Created by Claude Code on 11/12/25.
//

import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#endif

struct ArticleListView: View {
    @Environment(\.diContainer) private var diContainer
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Article.savedDate, order: .reverse) private var allArticles: [Article]
    @State private var viewModel: ArticleListViewModel?
    @State private var discoveryViewModel: DiscoveryViewModel?
    @State private var showingAddArticle = false
    @State private var showingDiscovery = false
    @State private var showingSettings = false
    let filter: ArticleFilter

    private var filteredArticles: [Article] {
        filter.filtered(allArticles)
    }

    var body: some View {
        ArticleListContent(
            articles: filteredArticles,
            viewModel: viewModel,
            diContainer: diContainer,
            filter: filter,
            onDiscover: { showingDiscovery = true }
        )
        .navigationTitle(filter.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if filter == .readingList {
                    Button {
                        showingDiscovery = true
                    } label: {
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
        #if os(iOS)
        .onAppear {
            configureNavigationBarAppearance()
        }
        #endif
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
        #if os(iOS)
        .fullScreenCover(isPresented: $showingDiscovery) {
            if let vm = discoveryViewModel {
                DiscoveryReaderView(viewModel: vm)
            }
        }
        #else
        .sheet(isPresented: $showingDiscovery) {
            if let vm = discoveryViewModel {
                DiscoveryReaderView(viewModel: vm)
                    .frame(minWidth: 600, minHeight: 500)
            }
        }
        #endif
        .onChange(of: showingDiscovery) { _, isShowing in
            if isShowing, discoveryViewModel == nil, let container = diContainer {
                discoveryViewModel = container.makeDiscoveryViewModel()
            } else if !isShowing {
                discoveryViewModel = nil
            }
        }
        .task {
            initializeViewModelIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task {
                await handleScenePhaseChange(newPhase)
            }
        }
    }

    private func initializeViewModelIfNeeded() {
        guard viewModel == nil, let container = diContainer else { return }
        viewModel = container.makeArticleListViewModel()
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) async {
        guard phase == .active, let viewModel else { return }
        await viewModel.syncSharedArticles()
    }

    #if os(iOS)
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
    #endif
}

struct ArticleListContent: View {
    let articles: [Article]
    let viewModel: ArticleListViewModel?
    let diContainer: DIContainer?
    let filter: ArticleFilter
    let onDiscover: () -> Void

    var body: some View {
        Group {
            if let viewModel {
                if articles.isEmpty {
                    ArticleListEmptyState(onDiscover: onDiscover, filter: filter)
                } else {
                    ArticleList(articles: articles, viewModel: viewModel, diContainer: diContainer, filter: filter)
                }
            } else {
                ProgressView()
            }
        }
    }
}

struct ArticleList: View {
    let articles: [Article]
    let viewModel: ArticleListViewModel
    let diContainer: DIContainer?
    let filter: ArticleFilter

    var body: some View {
        List {
            ForEach(articles) { article in
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
    let onDiscover: () -> Void
    let filter: ArticleFilter

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: 8) {
                Image(systemName: filter.emptyStateIcon)
                    .font(.system(size: 64))
                    .foregroundStyle(filter.emptyStateIconColor)
                Text(filter.emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        } description: {
            Text(filter.emptyStateDescription)
        } actions: {
            if filter == .readingList {
                Button("Inspire Me") {
                    onDiscover()
                }
                #if os(iOS)
                .buttonStyle(.glassProminent)
                #else
                .buttonStyle(.borderedProminent)
                #endif
                .tint(.purple)
            }
        }
    }
}

