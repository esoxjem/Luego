import SwiftUI
import NetworkImage

struct MarkdownImageView: View {
    let imageURL: URL?
    let viewModel: ReaderViewModel

    var body: some View {
        if let imageURL, isWebURL(imageURL) {
            NetworkImage(url: imageURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            viewModel.selectedImageURL = imageURL
                        }
                } else {
                    MarkdownImagePlaceholder()
                }
            }
        } else {
            EmptyView()
        }
    }

    private func isWebURL(_ url: URL) -> Bool {
        url.scheme == "http" || url.scheme == "https"
    }
}

struct MarkdownImageLoadingView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.1))
            .frame(height: 200)
            .overlay {
                ProgressView()
            }
    }
}

struct MarkdownImagePlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.15))
            .frame(height: 100)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .imageScale(.large)
            }
    }
}
