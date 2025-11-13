import SwiftUI
import NetworkImage

struct ArticleRowView: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArticleThumbnailView(thumbnailURL: article.thumbnailURL)
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
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .serif))
                    .lineLimit(2)

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

    var body: some View {
        if let thumbnailURL {
            NetworkImage(url: thumbnailURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ThumbnailPlaceholder()
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
