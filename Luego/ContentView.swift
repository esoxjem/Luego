//
//  ContentView.swift
//  Luego
//
//  Created by Arun Sasidharan on 10/11/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Article.savedDate, order: .reverse) private var articles: [Article]
    @State private var viewModel: ArticleListViewModel?
    @State private var showingAddArticle = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if articles.isEmpty {
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
                    AddArticleView(viewModel: viewModel)
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = ArticleListViewModel(modelContext: modelContext)
                }
            }
        }
    }

    private func articleList(viewModel: ArticleListViewModel) -> some View {
        List {
            ForEach(articles) { article in
                NavigationLink {
                    ReaderView(article: article, viewModel: viewModel)
                } label: {
                    ArticleRowView(article: article)
                }
                .id(article.id.uuidString + String(article.readPosition))
            }
            .onDelete { indexSet in
                viewModel.deleteArticle(at: indexSet)
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
