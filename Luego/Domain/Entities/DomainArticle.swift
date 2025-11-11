import Foundation

extension Domain {
    struct Article: Identifiable, Equatable, Sendable {
        let id: UUID
        let url: URL
        var title: String
        var content: String?
        let savedDate: Date
        var thumbnailURL: URL?
        var publishedDate: Date?
        var readPosition: Double

        var domain: String {
            url.host() ?? url.absoluteString
        }

        var estimatedReadingTime: String {
            guard let content = content, !content.isEmpty else {
                return "0 min"
            }

            let words = content.components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            let wordCount = words.count
            let wordsPerMinute = 200
            let minutes = max(1, Int(ceil(Double(wordCount) / Double(wordsPerMinute))))

            return "\(minutes) min"
        }

        init(
            id: UUID = UUID(),
            url: URL,
            title: String,
            content: String? = nil,
            savedDate: Date = Date(),
            thumbnailURL: URL? = nil,
            publishedDate: Date? = nil,
            readPosition: Double = 0.0
        ) {
            self.id = id
            self.url = url
            self.title = title
            self.content = content
            self.savedDate = savedDate
            self.thumbnailURL = thumbnailURL
            self.publishedDate = publishedDate
            self.readPosition = readPosition
        }
    }
}
