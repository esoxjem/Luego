import SwiftUI

struct ArticleRowView: View {
    let article: Article

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

            VStack(alignment: .leading, spacing: 2) {
                ArticleTitleRow(
                    title: article.title,
                    isFavorite: article.isFavorite
                )

                ArticleMetadataRow(
                    domain: article.domain,
                    author: article.author,
                    readPercentage: Int(article.readPosition * 100),
                    formattedDate: formatDisplayDate(article)
                )

                if !article.excerpt.isEmpty {
                    Text(article.excerpt)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
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
                    isFavorite: article.isFavorite
                )

                if !article.excerpt.isEmpty {
                    Text(article.excerpt)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

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
    let isFavorite: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(.headline, design: .serif))
                .fontWeight(.medium)
                .lineLimit(2)

            Spacer(minLength: 4)

            if isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.pink)
            }
        }
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
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}

struct ArticleThumbnailView: View {
    let url: URL?

    @State private var loadedImage: PlatformImage?
    @State private var loadFailed = false

    private static let imageCache = NSCache<NSURL, PlatformImage>()

    private let thumbnailSize: CGFloat = 72

    var body: some View {
        Group {
            if let url, isWebURL(url) {
                thumbnailContainer {
                    if let loadedImage {
                        loadedImageView(loadedImage)
                    } else if loadFailed {
                        placeholderView
                    } else {
                        loadingView
                    }
                }
                .task {
                    await loadImage(from: url)
                }
            } else {
                thumbnailContainer {
                    placeholderView
                }
            }
        }
    }

    private func thumbnailContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: thumbnailSize, height: thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private func loadedImageView(_ image: PlatformImage) -> some View {
        Image(platformImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }

    private var loadingView: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.1))
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

    private func isWebURL(_ url: URL) -> Bool {
        url.scheme == "http" || url.scheme == "https"
    }

    private func loadImage(from url: URL) async {
        if let cached = Self.imageCache.object(forKey: url as NSURL) {
            loadedImage = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = PlatformImage(data: data) {
                Self.imageCache.setObject(image, forKey: url as NSURL)
                loadedImage = image
            } else {
                loadFailed = true
            }
        } catch {
            loadFailed = true
        }
    }
}
