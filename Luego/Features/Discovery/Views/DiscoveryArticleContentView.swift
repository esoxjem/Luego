import SwiftUI
import MarkdownUI

struct DiscoveryArticleContentView: View {
    let article: EphemeralArticle
    let viewModel: DiscoveryViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DiscoveryArticleHeaderView(
                    title: article.title,
                    url: article.url,
                    feedTitle: article.feedTitle,
                    formattedDate: formattedDate
                )

                Divider()

                Markdown(stripFirstH1FromMarkdown(article.content, matchingTitle: article.title))
                    .markdownTheme(.reader)
                    .markdownImageProvider(ReaderImageProvider(imageHandler: viewModel))
            }
            .fontDesign(.serif)
            .padding(.vertical)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.gitHubBackground)
    }

    private var formattedDate: String {
        guard let date = article.publishedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter.string(from: date)
    }
}

struct DiscoveryArticleHeaderView: View {
    let title: String
    let url: URL
    let feedTitle: String
    let formattedDate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundColor(.primary)

            HStack {
                SourceAttributionChip(feedTitle: feedTitle, url: url)

                Spacer()

                if !formattedDate.isEmpty {
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SourceAttributionChip: View {
    let feedTitle: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text("via \(feedTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

