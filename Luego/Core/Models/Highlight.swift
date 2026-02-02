import Foundation
import SwiftData

enum HighlightColor: String, Codable, CaseIterable {
    case yellow, green, blue, pink
}

@Model
final class Highlight {
    var id: UUID = UUID()
    var startOffset: Int = 0
    var endOffset: Int = 0
    var text: String = ""
    var color: HighlightColor = HighlightColor.yellow
    var createdAt: Date = Date()
    var article: Article?

    init(range: NSRange, text: String, color: HighlightColor = .yellow) {
        self.id = UUID()
        self.startOffset = range.location
        self.endOffset = range.location + range.length
        self.text = text
        self.color = color
        self.createdAt = Date()
    }
}
