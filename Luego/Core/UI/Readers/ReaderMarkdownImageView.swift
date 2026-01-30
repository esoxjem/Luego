import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}

struct ReaderMarkdownImageView: View {
    let imageURL: URL?

    @State private var loadedImage: PlatformImage?
    @State private var loadFailed = false

    private static let imageCache = NSCache<NSURL, PlatformImage>()

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
        if let cached = Self.imageCache.object(forKey: url as NSURL) {
            loadedImage = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = PlatformImage(data: data) {
                Self.imageCache.setObject(image, forKey: url as NSURL)
                loadedImage = image
            } else {
                loadFailed = true
            }
        } catch {
            loadFailed = true
        }
    }
}

struct TrueSizeImage: View {
    let image: PlatformImage

    var body: some View {
        Image(platformImage: image)
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
