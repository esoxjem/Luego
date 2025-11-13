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

    var body: some View {
        ArticleListContent(
            viewModel: viewModel,
            diContainer: diContainer,
            onAddArticle: { showingAddArticle = true }
        )
        .navigationTitle("Luego")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            AddArticleToolbarButton(onTap: { showingAddArticle = true })
        }
        .onAppear {
            configureNavigationBarAppearance()
        }
        .sheet(isPresented: $showingAddArticle) {
            if let viewModel {
                AddArticleView(viewModel: viewModel)
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
}

struct ArticleListContent: View {
    let viewModel: ArticleListViewModel?
    let diContainer: DIContainer?
    let onAddArticle: () -> Void

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.articles.isEmpty {
                    ArticleListEmptyState(onAddArticle: onAddArticle)
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
            ForEach(viewModel.articles) { article in
                NavigationLink {
                    ArticleReaderDestination(article: article, diContainer: diContainer)
                } label: {
                    ArticleRowView(article: article)
                }
            }
            .onDelete { indexSet in
                Task {
                    await viewModel.deleteArticle(at: indexSet)
                }
            }
        }
        .scrollContentBackground(.hidden)
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

    var body: some View {
        ContentUnavailableView {
            Label("No Articles", systemImage: "doc.text")
        } description: {
            Text("Save your first article to get started")
        } actions: {
            Button("Add Article") {
                onAddArticle()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct AddArticleToolbarButton: ToolbarContent {
    let onTap: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                onTap()
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}
