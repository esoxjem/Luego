import SwiftUI
import SwiftData
import WebKit

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ReaderView: View {
    @Bindable var article: Article
    @Bindable var viewModel: ArticleListViewModel

    @State private var articleContent: String?
    @State private var isLoading = true
    @State private var showWebView = false
    @State private var errorMessage: String?
    @State private var scrollPosition: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    @State private var saveTask: Task<Void, Never>?
    @State private var hasRestoredPosition = false

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

    private struct ContentParagraph: Identifiable {
        let id = UUID()
        let text: String
        let markers: [Int]
    }

    private func splitContentIntoSections(_ content: String) -> [ContentParagraph] {
        let paragraphs = content.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        let targetMarkerCount = 101
        var result: [ContentParagraph] = []

        let totalLength = content.count
        let markerInterval = Double(totalLength) / Double(targetMarkerCount - 1)

        var currentLength = 0
        var nextMarkerIndex = 0

        for paragraph in paragraphs {
            var markersForParagraph: [Int] = []
            let paragraphEndLength = currentLength + paragraph.count

            while nextMarkerIndex < targetMarkerCount {
                let markerPosition = Double(nextMarkerIndex) * markerInterval
                if markerPosition <= Double(paragraphEndLength) {
                    markersForParagraph.append(nextMarkerIndex)
                    nextMarkerIndex += 1
                } else {
                    break
                }
            }

            result.append(ContentParagraph(text: paragraph, markers: markersForParagraph))
            currentLength = paragraphEndLength + 2
        }

        while nextMarkerIndex < targetMarkerCount {
            result.append(ContentParagraph(text: "", markers: [nextMarkerIndex]))
            nextMarkerIndex += 1
        }

        return result
    }

    private func restoreScrollPosition(proxy: ScrollViewProxy) {
        guard !hasRestoredPosition && article.readPosition > 0 else { return }

        hasRestoredPosition = true
        let targetPosition = article.readPosition

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let markerIndex = Int(targetPosition * 100)
            let clampedIndex = min(markerIndex, 100)

            withAnimation(.easeOut(duration: 0.5)) {
                proxy.scrollTo("marker_\(clampedIndex)", anchor: .top)
            }
        }
    }

    private func readerModeView(content: String) -> some View {
        GeometryReader { outerGeo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Color.clear
                            .frame(height: 1)
                            .id("top")

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

                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(splitContentIntoSections(content)) { paragraph in
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(paragraph.markers, id: \.self) { markerIndex in
                                        Color.clear
                                            .frame(height: 1)
                                            .id("marker_\(markerIndex)")
                                    }

                                    if !paragraph.text.isEmpty {
                                        Text(paragraph.text)
                                            .font(.system(.body, design: .serif))
                                            .lineSpacing(8)
                                            .foregroundColor(.primary)
                                            .padding(.bottom, 16)
                                    }
                                }
                            }
                        }
                        .onAppear {
                            if !hasRestoredPosition {
                                restoreScrollPosition(proxy: proxy)
                            }
                        }
                }
                .padding()
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .global).minY) { oldValue, newValue in
                                contentHeight = geo.size.height
                                viewHeight = outerGeo.size.height
                                scrollPosition = max(0, -newValue)
                                updateReadPosition()
                            }
                            .onAppear {
                                contentHeight = geo.size.height
                                viewHeight = outerGeo.size.height
                            }
                    }
                )
                }
                .onDisappear {
                    saveTask?.cancel()
                    let maxScroll = max(1, contentHeight - viewHeight)
                    let position = min(1.0, max(0.0, scrollPosition / maxScroll))
                    viewModel.updateReadPosition(for: article, position: position)
                }
            }
        }
    }

    private func updateReadPosition() {
        saveTask?.cancel()

        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            guard !Task.isCancelled else { return }

            let maxScroll = max(1, contentHeight - viewHeight)
            let position = min(1.0, max(0.0, scrollPosition / maxScroll))

            await MainActor.run {
                viewModel.updateReadPosition(for: article, position: position)
            }
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
