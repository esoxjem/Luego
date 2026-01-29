import SwiftUI

struct DiscoveryPane: View {
    @Environment(\.diContainer) private var diContainer
    @Environment(\.openURL) private var openURL
    @State private var viewModel: DiscoveryViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                DiscoveryInlineView(viewModel: vm, openURL: openURL)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil, let container = diContainer {
                viewModel = container.makeDiscoveryViewModel()
            }
        }
        .navigationTitle("Discovery")
    }
}

struct DiscoveryInlineView: View {
    @Bindable var viewModel: DiscoveryViewModel
    var openURL: OpenURLAction

    var body: some View {
        Group {
            if viewModel.isLoading {
                DiscoveryLoadingContentView(viewModel: viewModel)
            } else if let article = viewModel.ephemeralArticle {
                DiscoveryArticleContentView(article: article)
            } else if let error = viewModel.errorMessage {
                DiscoveryErrorView(
                    message: error,
                    onTryAnother: { Task { await viewModel.loadAnotherArticle() } }
                )
            } else {
                DiscoveryLoadingContentView(viewModel: viewModel)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.ephemeralArticle != nil && !viewModel.isLoading {
                HStack {
                    Spacer()
                    DiscoveryBottomBar(
                        isSaved: viewModel.isSaved,
                        onShuffle: { Task { await viewModel.loadAnotherArticle() } },
                        onSave: { Task { await viewModel.saveToReadingList() } }
                    )
                }
                .padding(.trailing)
            }
        }
        .toolbar {
            if viewModel.ephemeralArticle != nil {
                ToolbarItem(placement: .primaryAction) {
                    DiscoveryToolbarMenu(
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
