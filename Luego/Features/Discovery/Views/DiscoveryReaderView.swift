import SwiftUI
import MarkdownUI

struct DiscoveryReaderView: View {
    @Bindable var viewModel: DiscoveryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    DiscoveryLoadingView()
                } else if let article = viewModel.ephemeralArticle {
                    DiscoveryArticleContentView(article: article, viewModel: viewModel)
                } else if let error = viewModel.errorMessage {
                    DiscoveryErrorView(
                        message: error,
                        onTryAnother: { Task { await viewModel.loadAnotherArticle() } }
                    )
                } else {
                    DiscoveryLoadingView()
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                if viewModel.ephemeralArticle != nil {
                    ToolbarItem(placement: .primaryAction) {
                        DiscoveryToolbar(
                            isSaved: viewModel.isSaved,
                            onSave: { Task { await viewModel.saveToReadingList() } },
                            onShuffle: { Task { await viewModel.loadAnotherArticle() } },
                            onShare: shareArticle,
                            onOpenInBrowser: openInBrowser
                        )
                    }
                }
            }
            .task {
                if viewModel.ephemeralArticle == nil && !viewModel.isLoading {
                    await viewModel.fetchRandomArticle()
                }
            }
            .fullScreenCover(item: $viewModel.selectedImageURL) { url in
                FullscreenImageViewer(
                    imageURL: url,
                    onDismiss: { viewModel.selectedImageURL = nil }
                )
            }
        }
    }

    private func shareArticle() {
        guard let article = viewModel.ephemeralArticle else { return }

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

    private func openInBrowser() {
        guard let article = viewModel.ephemeralArticle else { return }
        openURL(article.url)
    }
}

struct DiscoveryLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Finding something interesting...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct DiscoveryErrorView: View {
    let message: String
    let onTryAnother: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Could not load article", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Another", action: onTryAnother)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct DiscoveryToolbar: View {
    let isSaved: Bool
    let onSave: () -> Void
    let onShuffle: () -> Void
    let onShare: () -> Void
    let onOpenInBrowser: () -> Void

    var body: some View {
        Menu {
            if isSaved {
                Label("Saved to List", systemImage: "checkmark")
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onSave) {
                    Label("Save to List", systemImage: "plus")
                }
            }

            Button(action: onShuffle) {
                Label("Try Another", systemImage: "die.face.5")
            }

            Button(action: onShare) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button(action: onOpenInBrowser) {
                Label("Open in Browser", systemImage: "safari")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}
