import SwiftUI

struct ReaderMarkdownImageView: View {
    let imageURL: URL?

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        if let imageURL, isWebURL(imageURL) {
            Group {
                if let loadedImage {
                    TrueSizeImage(image: loadedImage)
                } else if loadFailed {
                    MarkdownImagePlaceholder()
                } else {
                    MarkdownImageLoadingView()
                }
            }
            .task {
                await loadImage(from: imageURL)
            }
        } else {
            EmptyView()
        }
    }

    private func isWebURL(_ url: URL) -> Bool {
        url.scheme == "http" || url.scheme == "https"
    }

    private func loadImage(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                loadedImage = uiImage
            } else {
                loadFailed = true
            }
        } catch {
            loadFailed = true
        }
    }
}

struct TrueSizeImage: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: image.size.width)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
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
