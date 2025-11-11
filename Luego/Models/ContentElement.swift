import Foundation

enum ContentElement: Identifiable {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case heading4(String)
    case heading5(String)
    case heading6(String)
    case blockquote(String)
    case listItem(String)
    case paragraph(String)

    var id: String {
        UUID().uuidString
    }

    static func parse(_ content: String) -> [ContentElement] {
        let sections = content.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        var elements: [ContentElement] = []

        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("# ") {
                let text = String(trimmed.dropFirst(2))
                elements.append(categorizeHeading(text))
            } else if trimmed.hasPrefix("> ") {
                let text = String(trimmed.dropFirst(2))
                elements.append(.blockquote(text))
            } else if trimmed.contains("\n• ") {
                let items = trimmed.components(separatedBy: "\n")
                    .filter { $0.hasPrefix("• ") }
                    .map { String($0.dropFirst(2)) }
                elements.append(contentsOf: items.map { .listItem($0) })
            } else if !trimmed.isEmpty {
                elements.append(.paragraph(trimmed))
            }
        }

        return elements
    }

    private static func categorizeHeading(_ text: String) -> ContentElement {
        let wordCount = text.components(separatedBy: .whitespaces).count

        if text.count > 60 || wordCount > 10 {
            return .heading3(text)
        } else if text.count > 40 || wordCount > 7 {
            return .heading2(text)
        } else {
            return .heading1(text)
        }
    }
}
