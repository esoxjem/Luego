import SwiftUI
import SwiftData
import WebKit

struct ReaderView: View {
    let article: Article
    @Bindable var viewModel: ArticleListViewModel

    @State private var articleContent: String?
    @State private var isLoading = true
    @State private var showWebView = false
    @State private var errorMessage: String?

    private var formattedDate: String {
        let displayDate = article.publishedDate ?? article.savedDate
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter.string(from: displayDate)
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if showWebView {
                webView
            } else if let content = articleContent {
                readerModeView(content: content)
            } else if let error = errorMessage {
                errorView(message: error)
            }
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !showWebView {
                        Button {
                            showWebView = true
                        } label: {
                            Label("Show Web View", systemImage: "safari")
                        }
                    }

                    Button {
                        shareArticle()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await loadArticleContent()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading article...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func readerModeView(content: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(article.title)
                        .font(.system(.title, design: .serif, weight: .bold))
                        .foregroundColor(.primary)

                    HStack {
                        Text(article.domain)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if article.content != nil {
                        Text(article.estimatedReadingTime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Text(content)
                    .font(.system(.body, design: .serif))
                    .lineSpacing(8)
                    .foregroundColor(.primary)
            }
            .padding()
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
    }

    private var webView: some View {
        WebViewRepresentable(url: article.url)
            .ignoresSafeArea(edges: .bottom)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Failed to Load Article", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Open in Web View") {
                showWebView = true
            }
            .buttonStyle(.borderedProminent)

            Button("Retry") {
                Task {
                    await loadArticleContent()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func loadArticleContent() async {
        isLoading = true
        errorMessage = nil

        do {
            let content = try await viewModel.fetchArticleContent(for: article)
            articleContent = content
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func shareArticle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [article.url],
            applicationActivities: nil
        )

        rootViewController.present(activityVC, animated: true)
    }
}

struct WebViewRepresentable: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Article.self, configurations: config)
    let viewModel = ArticleListViewModel(modelContext: container.mainContext)

    for article in Article.sampleArticles {
        container.mainContext.insert(article)
    }

    return NavigationStack {
        ReaderView(
            article: Article.sampleArticles[0],
            viewModel: viewModel
        )
    }
}

#Preview("Web View") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Article.self, configurations: config)
    let viewModel = ArticleListViewModel(modelContext: container.mainContext)

    for article in Article.sampleArticles {
        container.mainContext.insert(article)
    }

    return NavigationStack {
        ReaderView(
            article: Article.sampleArticles[0],
            viewModel: viewModel
        )
    }
}
