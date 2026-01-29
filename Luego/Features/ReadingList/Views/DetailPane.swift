import SwiftUI

struct DetailPane: View {
    let article: Article?
    @Environment(\.diContainer) private var diContainer
    @State private var readerViewModel: ReaderViewModel?

    var body: some View {
        Group {
            if let article = article {
                readerContent(for: article)
            } else {
                EmptyDetailView()
            }
        }
        .onChange(of: article?.id) { _, _ in
            if let newArticle = article, let container = diContainer {
                readerViewModel = container.makeReaderViewModel(article: newArticle)
            } else {
                readerViewModel = nil
            }
        }
        .task {
            if let article = article, readerViewModel == nil, let container = diContainer {
                readerViewModel = container.makeReaderViewModel(article: article)
            }
        }
    }

    @ViewBuilder
    private func readerContent(for article: Article) -> some View {
        if let vm = readerViewModel {
            ReaderView(viewModel: vm)
        } else {
            ProgressView()
        }
    }
}

struct EmptyDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "No Article Selected",
            systemImage: "doc.text",
            description: Text("Select an article to start reading")
        )
    }
}
