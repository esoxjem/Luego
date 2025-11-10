import SwiftUI

struct ArticleRowView: View {
    let article: Article

    private var formattedDate: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(article.savedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(article.savedDate) {
            return "Yesterday"
        } else if calendar.isDate(article.savedDate, equalTo: now, toGranularity: .weekOfYear) {
            return "This Week"
        } else if let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
                  calendar.isDate(article.savedDate, equalTo: oneWeekAgo, toGranularity: .weekOfYear) {
            return "Last Week"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: article.savedDate)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let thumbnailURL = article.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { phase in
                        switch phase {
                        case .empty:
                            thumbnailPlaceholder
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            thumbnailPlaceholder
                        @unknown default:
                            thumbnailPlaceholder
                        }
                    }
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(article.domain)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview {
    List {
        ForEach(Article.sampleArticles) { article in
            ArticleRowView(article: article)
        }
    }
}
