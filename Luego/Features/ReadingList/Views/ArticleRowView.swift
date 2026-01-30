import SwiftUI

struct ArticleRowView: View {
    let article: Article

    private var isUnread: Bool {
        article.readPosition == 0 && article.content != nil
    }

    var body: some View {
        #if os(macOS)
        macOSRowLayout
        #else
        iOSRowLayout
        #endif
    }

    #if os(macOS)
    private var macOSRowLayout: some View {
        VStack(alignment: .leading, spacing: 2) {
            ArticleTitleRow(
                title: article.title,
                isFavorite: article.isFavorite,
                isUnread: isUnread
            )

            ArticleMetadataRowCompact(
                domain: article.domain,
                formattedDate: formatDisplayDate(article)
            )

            if !article.excerpt.isEmpty {
                Text(article.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
    #endif

    private var iOSRowLayout: some View {
        HStack(alignment: .top, spacing: 10) {
            UnreadIndicator(isUnread: isUnread)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                ArticleTitleRow(
                    title: article.title,
                    isFavorite: article.isFavorite,
                    isUnread: isUnread
                )

                if !article.excerpt.isEmpty {
                    Text(article.excerpt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                ArticleMetadataRow(
                    domain: article.domain,
                    author: article.author,
                    formattedDate: formatDisplayDate(article),
                    estimatedReadingTime: article.estimatedReadingTime,
                    hasContent: article.content != nil
                )
            }
        }
        .padding(.vertical, 6)
    }

    private func formatDisplayDate(_ article: Article) -> String {
        let displayDate = article.publishedDate ?? article.savedDate
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(displayDate) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: displayDate)
        } else if calendar.isDateInYesterday(displayDate) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: displayDate, to: now).day, daysAgo < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: displayDate)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: displayDate)
        }
    }
}

struct UnreadIndicator: View {
    let isUnread: Bool

    var body: some View {
        Circle()
            .fill(isUnread ? Color.accentColor : Color.clear)
            .frame(width: 8, height: 8)
    }
}

struct ArticleTitleRow: View {
    let title: String
    let isFavorite: Bool
    let isUnread: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.headline)
                .fontWeight(isUnread ? .semibold : .medium)
                .foregroundStyle(isUnread ? Color.primary : Color.primary.opacity(0.85))
                .lineLimit(2)

            Spacer(minLength: 4)

            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct ArticleMetadataRow: View {
    let domain: String
    let author: String?
    let formattedDate: String
    let estimatedReadingTime: String
    let hasContent: Bool

    var body: some View {
        HStack(spacing: 0) {
            Text(domain)
                .lineLimit(1)

            if let author, !author.isEmpty {
                Text(" · ")
                    .foregroundStyle(.quaternary)
                Text(author)
                    .lineLimit(1)
            }

            if hasContent {
                Text(" · ")
                    .foregroundStyle(.quaternary)
                Text(estimatedReadingTime)
            }

            Text(" · ")
                .foregroundStyle(.quaternary)
            Text(formattedDate)

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}

#if os(macOS)
struct ArticleMetadataRowCompact: View {
    let domain: String
    let formattedDate: String

    var body: some View {
        HStack(spacing: 0) {
            Text(domain)
                .lineLimit(1)

            Text(" · ")
                .foregroundStyle(.quaternary)

            Text(formattedDate)

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}
#endif
