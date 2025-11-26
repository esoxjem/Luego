import SwiftUI
import MarkdownUI

struct ReaderView: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.openURL) private var openURL
    @State private var scrollPosition: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    @State private var saveTask: Task<Void, Never>?
    @State private var hasRestoredPosition = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ArticleLoadingView()
            } else if let content = viewModel.articleContent {
                ArticleReaderModeView(
                    article: viewModel.article,
                    content: content,
                    formattedDate: formattedDate,
                    scrollPosition: $scrollPosition,
                    contentHeight: $contentHeight,
                    viewHeight: $viewHeight,
                    saveTask: $saveTask,
                    hasRestoredPosition: $hasRestoredPosition,
                    onUpdateReadPosition: updateReadPosition,
                    onRestoreScrollPosition: restoreScrollPosition,
                    onDisappear: handleDisappear
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
                    onOpenInBrowser: openInBrowser,
                    onRefresh: refreshContent,
                    onShare: shareArticle
                )
            }
        }
        .task {
            await viewModel.loadContent()
        }
    }
}

struct ArticleReaderModeView: View {
    let article: Article
    let content: String
    let formattedDate: String
    @Binding var scrollPosition: CGFloat
    @Binding var contentHeight: CGFloat
    @Binding var viewHeight: CGFloat
    @Binding var saveTask: Task<Void, Never>?
    @Binding var hasRestoredPosition: Bool
    let onUpdateReadPosition: () -> Void
    let onRestoreScrollPosition: (ScrollViewProxy) -> Void
    let onDisappear: () -> Void

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

                        Markdown(stripFirstH1FromMarkdown(content, matchingTitle: article.title))
                            .markdownTheme(.reader)
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
                .background(Color.gitHubBackground)
                .onDisappear(perform: onDisappear)
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
    let onOpenInBrowser: () -> Void
    let onRefresh: () -> Void
    let onShare: () -> Void

    var body: some View {
        Menu {
            Button(action: onRefresh) {
                Label("Refresh Content", systemImage: "arrow.clockwise")
            }

            Button(action: onOpenInBrowser) {
                Label("Open in Browser", systemImage: "safari")
            }

            Button(action: onShare) {
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
                Link(destination: url) {
                    Text(domain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .underline()
                }

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
                .onChange(of: geo.frame(in: .global).minY) { oldValue, newValue in
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

    private func handleDisappear() {
        saveTask?.cancel()
        let maxScroll = max(1, contentHeight - viewHeight)
        let position = min(1.0, max(0.0, scrollPosition / maxScroll))
        Task {
            await viewModel.updateReadPosition(position)
        }
    }

    private func refreshContent() {
        Task {
            await viewModel.refreshContent()
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

private func stripFirstH1FromMarkdown(_ markdown: String, matchingTitle: String) -> String {
    let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)

    guard let firstLineIndex = lines.firstIndex(where: { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("# ")
    }) else {
        return markdown
    }

    let firstH1Line = lines[firstLineIndex]
    let h1Text = firstH1Line
        .trimmingCharacters(in: .whitespaces)
        .dropFirst(2)
        .trimmingCharacters(in: .whitespaces)

    let normalizedH1 = normalizeForComparison(String(h1Text))
    let normalizedTitle = normalizeForComparison(matchingTitle)

    guard areSimilar(normalizedH1, normalizedTitle) else {
        return markdown
    }

    var resultLines = Array(lines)
    resultLines.remove(at: firstLineIndex)

    while firstLineIndex < resultLines.count {
        let nextLine = resultLines[firstLineIndex].trimmingCharacters(in: .whitespaces)
        if nextLine.isEmpty {
            resultLines.remove(at: firstLineIndex)
        } else {
            break
        }
    }

    return resultLines.joined(separator: "\n")
}

private func normalizeForComparison(_ text: String) -> String {
    return text
        .lowercased()
        .components(separatedBy: .punctuationCharacters)
        .joined()
        .components(separatedBy: .whitespaces)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

private func areSimilar(_ text1: String, _ text2: String) -> Bool {
    if text1 == text2 {
        return true
    }

    let words1 = Set(text1.split(separator: " "))
    let words2 = Set(text2.split(separator: " "))
    let intersection = words1.intersection(words2)
    let union = words1.union(words2)

    guard !union.isEmpty else { return false }

    let similarity = Double(intersection.count) / Double(union.count)
    return similarity > 0.7
}

extension Color {
    static let gitHubBackground = Color(
        light: .white,
        dark: Color(red: 0x18 / 255.0, green: 0x19 / 255.0, blue: 0x1d / 255.0)
    )
}

extension Theme {
    static let reader = Theme.gitHub
        .text {
            FontSize(18)
        }
}
