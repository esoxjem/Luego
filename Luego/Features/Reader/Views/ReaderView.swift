import SwiftUI

struct ReaderView: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.openURL) private var openURL
    @State private var scrollPosition: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    @State private var saveTask: Task<Void, Never>?
    @State private var hasRestoredPosition = false
    @State private var lastSavedPosition: Double = 0

    var body: some View {
        Group {
            if viewModel.isLoading {
                ArticleLoadingView()
            } else if let content = viewModel.articleContent {
                ArticleReaderModeView(
                    article: viewModel.article,
                    content: content,
                    formattedDate: formattedDate,
                    highlights: viewModel.highlights,
                    showHighlightMenu: viewModel.showHighlightMenu,
                    scrollPosition: $scrollPosition,
                    contentHeight: $contentHeight,
                    viewHeight: $viewHeight,
                    saveTask: $saveTask,
                    hasRestoredPosition: $hasRestoredPosition,
                    onUpdateReadPosition: updateReadPosition,
                    onRestoreScrollPosition: restoreScrollPosition,
                    onDisappear: handleDisappear,
                    onSelectionChange: { range in viewModel.selectedRange = range },
                    onHighlightColor: { color in viewModel.createHighlight(color: color) }
                )
            } else if let error = viewModel.errorMessage {
                ArticleErrorView(
                    message: error,
                    onOpenInBrowser: openInBrowser,
                    onRetry: { Task { await viewModel.loadContent() } }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ReaderViewToolbar(
                    articleURL: viewModel.article.url,
                    articleTitle: viewModel.article.title,
                    onOpenInBrowser: openInBrowser,
                    onRefresh: refreshContent
                )
            }
        }
        .task(id: viewModel.article.id) {
            await viewModel.loadContent()
        }
    }
}

struct ArticleReaderModeView: View {
    let article: Article
    let content: String
    let formattedDate: String
    let highlights: [Highlight]
    let showHighlightMenu: Bool
    @Binding var scrollPosition: CGFloat
    @Binding var contentHeight: CGFloat
    @Binding var viewHeight: CGFloat
    @Binding var saveTask: Task<Void, Never>?
    @Binding var hasRestoredPosition: Bool
    let onUpdateReadPosition: () -> Void
    let onRestoreScrollPosition: (ScrollViewProxy) -> Void
    let onDisappear: () -> Void
    let onSelectionChange: (NSRange) -> Void
    let onHighlightColor: (HighlightColor) -> Void

    var body: some View {
        GeometryReader { outerGeo in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ArticleHeaderView(
                            title: article.title,
                            domain: article.domain,
                            url: article.url,
                            formattedDate: formattedDate
                        )

                        Divider()

                        SelectableTextView(
                            markdown: stripFirstH1FromMarkdown(content, matchingTitle: article.title),
                            highlights: highlights,
                            onSelectionChange: onSelectionChange
                        )
                    }
                    .fontDesign(.serif)
                    .padding(.vertical)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .id("articleContent")
                    .background(
                        ScrollPositionTracker(
                            contentHeight: $contentHeight,
                            viewHeight: $viewHeight,
                            scrollPosition: $scrollPosition,
                            outerGeometry: outerGeo,
                            onPositionChange: onUpdateReadPosition,
                            onAppear: { onRestoreScrollPosition(scrollProxy) }
                        )
                    )
                }
                .coordinateSpace(name: "scrollView")
                .background(Color.gitHubBackground)
                .onDisappear(perform: onDisappear)
                .overlay(alignment: .top) {
                    if showHighlightMenu {
                        HighlightMenuView(
                            onColorSelected: onHighlightColor,
                            onDelete: nil
                        )
                        .padding(.top, 60)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.2), value: showHighlightMenu)
                    }
                }
            }
        }
    }
}

struct ArticleLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading article...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct ArticleErrorView: View {
    let message: String
    let onOpenInBrowser: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Failed to Load Article", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Open in Browser", action: onOpenInBrowser)
                .buttonStyle(.borderedProminent)

            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
    }
}

struct ReaderViewToolbar: View {
    let articleURL: URL
    let articleTitle: String
    let onOpenInBrowser: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        Menu {
            Button(action: onRefresh) {
                Label("Refresh Content", systemImage: "arrow.clockwise")
            }

            Button(action: onOpenInBrowser) {
                Label("Open in Browser", systemImage: "safari")
            }

            ShareLink(item: articleURL, subject: Text(articleTitle)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

struct ArticleHeaderView: View {
    let title: String
    let domain: String
    let url: URL
    let formattedDate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundColor(.primary)

            HStack {
                DomainChip(domain: domain, url: url)

                Spacer()

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ScrollPositionTracker: View {
    @Binding var contentHeight: CGFloat
    @Binding var viewHeight: CGFloat
    @Binding var scrollPosition: CGFloat
    let outerGeometry: GeometryProxy
    let onPositionChange: () -> Void
    let onAppear: () -> Void

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onChange(of: geo.frame(in: .named("scrollView")).minY) { oldValue, newValue in
                    contentHeight = geo.size.height
                    viewHeight = outerGeometry.size.height
                    scrollPosition = max(0, -newValue)
                    onPositionChange()
                }
                .onAppear {
                    contentHeight = geo.size.height
                    viewHeight = outerGeometry.size.height
                    onAppear()
                }
        }
    }
}

extension ReaderView {
    private func openInBrowser() {
        openURL(viewModel.article.url)
    }

    private var formattedDate: String {
        let displayDate = viewModel.article.publishedDate ?? viewModel.article.savedDate
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter.string(from: displayDate)
    }

    private func updateReadPosition() {
        let newPosition = calculateReadPosition()

        guard abs(newPosition - lastSavedPosition) > 0.01 else { return }

        saveTask?.cancel()

        saveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }

            await viewModel.updateReadPosition(newPosition)
            lastSavedPosition = newPosition
        }
    }

    private func restoreScrollPosition(scrollProxy: ScrollViewProxy) {
        guard !hasRestoredPosition else { return }
        guard viewModel.article.readPosition > 0 else { return }
        guard contentHeight > 0 && viewHeight > 0 else { return }

        let savedPosition = viewModel.article.readPosition
        lastSavedPosition = savedPosition

        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run {
                let topAnchor = UnitPoint(x: 0, y: 0)
                let bottomAnchor = UnitPoint(x: 0, y: 1)

                let interpolatedAnchor = UnitPoint(
                    x: 0,
                    y: topAnchor.y + (bottomAnchor.y - topAnchor.y) * savedPosition
                )

                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy.scrollTo("articleContent", anchor: interpolatedAnchor)
                }
                hasRestoredPosition = true
            }
        }
    }

    private func handleDisappear() {
        saveTask?.cancel()

        let position = calculateReadPosition()
        Task {
            await viewModel.updateReadPosition(position)
        }
    }

    private func calculateReadPosition() -> Double {
        guard contentHeight > 0 else { return 0.0 }

        let visibleBottomPosition = scrollPosition + viewHeight
        let rawPosition = visibleBottomPosition / contentHeight
        let clampedPosition = min(1.0, max(0.0, rawPosition))

        return clampedPosition >= 0.95 ? 1.0 : clampedPosition
    }

    private func refreshContent() {
        Task {
            await viewModel.refreshContent()
        }
    }
}

