import SwiftUI
import WebKit
import MarkdownUI

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

extension Theme {
    static let reader = Theme.gitHub
        .text {
            FontSize(18)
        }
}

struct ReaderViewNew: View {
    @Bindable var viewModel: ReaderViewModel

    @State private var showWebView = false
    @State private var scrollPosition: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    @State private var saveTask: Task<Void, Never>?
    @State private var hasRestoredPosition = false

    private var formattedDate: String {
        let displayDate = viewModel.article.publishedDate ?? viewModel.article.savedDate
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter.string(from: displayDate)
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if showWebView {
                webView
            } else if let content = viewModel.articleContent {
                readerModeView(content: content)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            }
        }
        .navigationTitle(viewModel.article.title)
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
            await viewModel.loadContent()
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
        GeometryReader { outerGeo in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(viewModel.article.title)
                                .font(.title.weight(.bold))
                                .foregroundColor(.primary)

                            HStack {
                                Text(viewModel.article.domain)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(formattedDate)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if viewModel.article.content != nil {
                                Text(viewModel.article.estimatedReadingTime)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.bottom, 8)

                        Divider()

                        Markdown(content)
                            .markdownTheme(.reader)
                    }
                    .fontDesign(.serif)
                    .padding(.vertical)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                    .id("articleContent")
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
                                    restoreScrollPosition(scrollProxy: scrollProxy)
                                }
                        }
                    )
                }
                .onDisappear {
                    saveTask?.cancel()
                    let maxScroll = max(1, contentHeight - viewHeight)
                    let position = min(1.0, max(0.0, scrollPosition / maxScroll))
                    Task {
                        await viewModel.updateReadPosition(position)
                    }
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

            await viewModel.updateReadPosition(position)
        }
    }

    private func restoreScrollPosition(scrollProxy: ScrollViewProxy) {
        guard !hasRestoredPosition else { return }
        guard viewModel.article.readPosition > 0 else { return }
        guard contentHeight > 0 && viewHeight > 0 else { return }

        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run {
                let topAnchor = UnitPoint(x: 0, y: 0)
                let bottomAnchor = UnitPoint(x: 0, y: 1)

                let interpolatedAnchor = UnitPoint(
                    x: 0,
                    y: topAnchor.y + (bottomAnchor.y - topAnchor.y) * viewModel.article.readPosition
                )

                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy.scrollTo("articleContent", anchor: interpolatedAnchor)
                }
                hasRestoredPosition = true
            }
        }
    }

    private var webView: some View {
        WebViewRepresentable(url: viewModel.article.url)
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
                    await viewModel.loadContent()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func shareArticle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [viewModel.article.url],
            applicationActivities: nil
        )

        rootViewController.present(activityVC, animated: true)
    }
}
