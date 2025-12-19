import SwiftUI
import MarkdownUI

struct ReaderImageProvider: ImageProvider {
    func makeImage(url: URL?) -> some View {
        ReaderMarkdownImageView(imageURL: url)
    }
}
