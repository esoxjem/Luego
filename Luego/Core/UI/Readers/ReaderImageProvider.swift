import SwiftUI
import MarkdownUI

struct ReaderImageProvider: ImageProvider {
    let imageHandler: any ImageSelectionHandler

    func makeImage(url: URL?) -> some View {
        ReaderMarkdownImageView(imageURL: url, imageHandler: imageHandler)
    }
}
