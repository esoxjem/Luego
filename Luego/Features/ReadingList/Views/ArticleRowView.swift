import SwiftUI
import NetworkImage

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArticleThumbnailView(thumbnailURL: article.thumbnailURL, faviconURL: article.faviconURL)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            ArticleContentView(
                title: article.title,
                domain: article.domain,
                readPercentage: Int(article.readPosition * 100),
                formattedDate: formatDisplayDate(article),
                estimatedReadingTime: article.estimatedReadingTime,
                hasContent: article.content != nil,
                isFavorite: article.isFavorite
            )
        }
        .padding(.vertical, 4)
    }

    private func formatDisplayDate(_ article: Article) -> String {
        let displayDate = article.publishedDate ?? article.savedDate
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter.string(from: displayDate)
    }
}

struct ArticleContentView: View {
    let title: String
    let domain: String
    let readPercentage: Int
    let formattedDate: String
    let estimatedReadingTime: String
    let hasContent: Bool
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(.headline, design: .serif))
                    .lineLimit(2)

                Spacer()

                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.pink)
                }
            }

            Text(domain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("Read \(readPercentage)%")
                .font(.caption)
                .foregroundStyle(.blue)

            ArticleMetadataFooter(
                formattedDate: formattedDate,
                estimatedReadingTime: estimatedReadingTime,
                hasContent: hasContent
            )
        }
    }
}

struct ArticleMetadataFooter: View {
    let formattedDate: String
    let estimatedReadingTime: String
    let hasContent: Bool

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            if hasContent {
                Text(estimatedReadingTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct ArticleThumbnailView: View {
    let thumbnailURL: URL?
    let faviconURL: URL?

    var body: some View {
        if let thumbnailURL {
            NetworkImage(url: thumbnailURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    FaviconFallbackView(faviconURL: faviconURL)
                }
            }
        } else {
            FaviconFallbackView(faviconURL: faviconURL)
        }
    }
}

struct FaviconFallbackView: View {
    let faviconURL: URL?

    var body: some View {
        if let faviconURL {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .overlay {
                    NetworkImage(url: faviconURL) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        } else {
            ThumbnailPlaceholder()
        }
    }
}

struct ThumbnailPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
            }
    }
}
