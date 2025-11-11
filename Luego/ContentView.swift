//
//  ContentView.swift
//  Luego
//
//  Created by Arun Sasidharan on 10/11/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.diContainer) private var diContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: ArticleListViewModel?
    @State private var showingAddArticle = false

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddArticle = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddArticle) {
                if let viewModel {
                    AddArticleViewNew(viewModel: viewModel)
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
    }

    private func articleList(viewModel: ArticleListViewModel) -> some View {
        List {
            ForEach(viewModel.articles) { article in
                NavigationLink {
                    ReaderViewWrapper(article: article)
                } label: {
                    ArticleRowViewWrapper(article: article)
                }
                .id(article.id.uuidString + String(article.readPosition))
            }
            .onDelete { indexSet in
                Task {
                    await viewModel.deleteArticle(at: indexSet)
                }
            }
        }
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
}

struct ReaderViewWrapper: View {
    let article: Domain.Article
    @Environment(\.diContainer) private var diContainer

    var body: some View {
        Group {
            if let container = diContainer {
                let readerViewModel = container.makeReaderViewModel(article: article)
                ReaderViewNew(viewModel: readerViewModel)
            } else {
                Text("Error: DI Container not available")
            }
        }
    }
}

struct ArticleRowViewWrapper: View {
    let article: Domain.Article

    var body: some View {
        ArticleRowViewNew(article: article)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Article.self, inMemory: true)
}

#Preview("With Articles") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Article.self, configurations: config)

    for article in Article.sampleArticles {
        container.mainContext.insert(article)
    }

    return ContentView()
        .modelContainer(container)
}
