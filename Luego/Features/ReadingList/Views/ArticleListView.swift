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
        Group {
            if let viewModel {
                if viewModel.articles.isEmpty {
                    emptyState
                } else {
                    articleList(viewModel: viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Luego")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
        .task {
            if viewModel == nil, let container = diContainer {
                viewModel = container.makeArticleListViewModel()
                await viewModel?.loadArticles()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, let viewModel {
                Task {
                    await viewModel.syncSharedArticles()
                }
            }
        }
    }

    private func articleList(viewModel: ArticleListViewModel) -> some View {
        List {
            ForEach(viewModel.articles) { article in
                NavigationLink {
                    if let container = diContainer {
                        let readerViewModel = container.makeReaderViewModel(article: article)
                        ReaderView(viewModel: readerViewModel)
                    }
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Articles", systemImage: "doc.text")
        } description: {
            Text("Save your first article to get started")
        } actions: {
            Button("Add Article") {
                showingAddArticle = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        let serifFont = UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
            .withDesign(.serif)!
            .withSymbolicTraits(.traitBold)!,
            size: 0)

        appearance.largeTitleTextAttributes = [
            .font: serifFont
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
