import Foundation

final class OPMLDataSource: NSObject, @unchecked Sendable {
    private var articles: [SmallWebArticleEntry] = []

    func parse(_ data: Data) -> [SmallWebArticleEntry] {
        articles = []
        let sanitizedData = sanitizeXMLAmpersands(in: data)
        let parser = XMLParser(data: sanitizedData)
        parser.delegate = self
        parser.parse()
        return articles
    }

    private func sanitizeXMLAmpersands(in data: Data) -> Data {
        guard var xmlString = String(data: data, encoding: .utf8) else { return data }
        xmlString = xmlString.replacingOccurrences(
            of: "&(?!(amp|lt|gt|quot|apos|#[0-9]+|#x[0-9a-fA-F]+);)",
            with: "&amp;",
            options: .regularExpression
        )
        return xmlString.data(using: .utf8) ?? data
    }
}

extension OPMLDataSource: XMLParserDelegate {
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName == "outline" else { return }
        guard let urlString = attributeDict["xmlUrl"],
              let articleUrl = URL(string: urlString) else { return }

        let title = attributeDict["title"] ?? attributeDict["text"] ?? articleUrl.host() ?? "Unknown"
        let htmlUrl = attributeDict["htmlUrl"].flatMap { URL(string: $0) }

        articles.append(SmallWebArticleEntry(title: title, articleUrl: articleUrl, htmlUrl: htmlUrl))
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        #if DEBUG
        print("[Discovery] XML Parse Error at line \(parser.lineNumber), column \(parser.columnNumber): \(parseError.localizedDescription)")
        #endif
    }
}
