import Foundation

final class OPMLDataSource: NSObject, @unchecked Sendable {
    private var articles: [SmallWebArticleEntry] = []

    func parse(_ data: Data) -> [SmallWebArticleEntry] {
        articles = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
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
}
