import SwiftUI
import Textual

struct ReaderMarkdownContentView: View {
    let markdown: String
    let title: String
    let baseURL: URL

    private var cleanedMarkdown: String {
        stripFirstH1FromMarkdown(markdown, matchingTitle: title)
    }

    var body: some View {
        StructuredText(markdown: cleanedMarkdown, baseURL: baseURL)
            .readerContentStyle(baseURL: baseURL)
    }
}
