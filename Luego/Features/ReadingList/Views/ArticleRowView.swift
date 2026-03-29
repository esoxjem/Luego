import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ArticleRowView: View {
    @ObservedObject var article: Article
    var isSelected: Bool = false

    var body: some View {
        #if os(macOS)
        macOSRowLayout
        #else
        iOSRowLayout
        #endif
    }

    #if os(macOS)
    private var macOSRowLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            ArticleThumbnailView(url: article.thumbnailURL)

            VStack(alignment: .leading, spacing: 3) {
                ArticleTitleRow(
                    title: article.title,
                    excerpt: article.excerpt,
                    isFavorite: article.isFavorite
                )

                ArticleMetadataRow(
                    domain: article.domain,
                    author: article.author,
                    readPercentage: Int(article.readPosition * 100),
                    formattedDate: formatDisplayDate(article)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
    #endif

    private var iOSRowLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            ArticleThumbnailView(url: article.thumbnailURL)

            VStack(alignment: .leading, spacing: 4) {
                ArticleTitleRow(
                    title: article.title,
                    excerpt: article.excerpt,
                    isFavorite: article.isFavorite,
                    isSelected: isSelected
                )

                ArticleMetadataRow(
                    domain: article.domain,
                    author: article.author,
                    readPercentage: Int(article.readPosition * 100),
                    formattedDate: formatDisplayDate(article),
                    estimatedReadingTime: article.estimatedReadingTime,
                    showReadingTime: article.content != nil
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
            return DateFormatters.time.string(from: displayDate)
        } else if calendar.isDateInYesterday(displayDate) {
            return "Yesterday"
        } else if let daysAgo = calendar.dateComponents([.day], from: displayDate, to: now).day, daysAgo < 7 {
            return DateFormatters.weekday.string(from: displayDate)
        } else {
            return DateFormatters.shortDate.string(from: displayDate)
        }
    }
}

struct ArticleTitleRow: View {
    let title: String
    let excerpt: String
    let isFavorite: Bool
    var isSelected: Bool = false
    @State private var measuredTitleHeight: CGFloat = 0

    private var titleLineHeight: CGFloat {
        #if os(iOS)
        return UIFont.app(.listTitle).lineHeight
        #else
        let font = NSFont.app(.listTitle)
        return font.ascender - font.descender + font.leading
        #endif
    }

    private var reservedTitleHeight: CGFloat {
        (titleLineHeight * 2) + 1
    }

    private var excerptSlotHeight: CGFloat {
        max(reservedTitleHeight - measuredTitleHeight, 0)
    }

    private var shouldShowExcerpt: Bool {
        measuredTitleHeight > 0 && measuredTitleHeight <= (titleLineHeight + 0.5) && !excerpt.isEmpty
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.app(.listTitle))
                    .foregroundStyle(isSelected ? Color.regularSelectionInk : Color.primary)
                    .lineLimit(2)
                    .lineSpacing(1)
                    .background {
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: ArticleTitleHeightPreferenceKey.self, value: geometry.size.height)
                        }
                    }

                if shouldShowExcerpt {
                    Text(excerpt)
                        .font(.app(.listExcerpt))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(height: excerptSlotHeight, alignment: .bottomLeading)
                }
            }
            .frame(height: reservedTitleHeight, alignment: .topLeading)
            .onPreferenceChange(ArticleTitleHeightPreferenceKey.self) { measuredTitleHeight = $0 }

            Spacer(minLength: 4)

            if isFavorite {
                Image(systemName: "heart.fill")
                    .font(.app(.listMetadata))
                    .foregroundStyle(.pink)
            }
        }
    }
}

private struct ArticleTitleHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ArticleMetadataRow: View {
    let domain: String
    let author: String?
    let readPercentage: Int
    let formattedDate: String
    var estimatedReadingTime: String? = nil
    var showReadingTime: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 0) {
                Text(domain)
                    .lineLimit(1)

                if let author, !author.isEmpty {
                    Text(" · ")
                        .foregroundStyle(.quaternary)
                    Text(author)
                        .lineLimit(1)
                }

                Spacer()
            }

            HStack(spacing: 0) {
                Text("Read \(readPercentage)%")
                    .foregroundStyle(.blue)

                if showReadingTime, let time = estimatedReadingTime {
                    Text(" · ")
                        .foregroundStyle(.quaternary)
                    Text(time)
                }

                Text(" · ")
                    .foregroundStyle(.quaternary)
                Text(formattedDate)

                Spacer()
            }
        }
        .font(.app(.listMetadata))
        .foregroundStyle(.tertiary)
    }
}

struct ArticleThumbnailView: View {
    let url: URL?

    private let thumbnailSize: CGFloat = 72

    private var secureURL: URL? {
        guard let url else { return nil }
        guard url.scheme == "http" else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        return components?.url ?? url
    }

    var body: some View {
        thumbnailContent
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let url = secureURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderView
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
            .overlay {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.quaternary)
            }
    }
}
