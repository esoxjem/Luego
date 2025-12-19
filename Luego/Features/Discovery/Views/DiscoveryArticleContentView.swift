import SwiftUI
import MarkdownUI

struct DiscoveryArticleContentView: View {
    let article: EphemeralArticle
    let viewModel: DiscoveryViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DiscoveryArticleHeaderView(
                    title: article.title,
                    url: article.url,
                    feedTitle: article.feedTitle,
                    formattedDate: formattedDate
                )

                Divider()

                Markdown(article.content)
                    .markdownTheme(.reader)
                    .markdownImageProvider(DiscoveryImageProvider(viewModel: viewModel))
            }
            .fontDesign(.serif)
            .padding(.vertical)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.gitHubBackground)
    }

    private var formattedDate: String {
        guard let date = article.publishedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM-yy"
        return formatter.string(from: date)
    }
}

struct DiscoveryArticleHeaderView: View {
    let title: String
    let url: URL
    let feedTitle: String
    let formattedDate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundColor(.primary)

            HStack {
                SourceAttributionChip(feedTitle: feedTitle, url: url)

                Spacer()

                if !formattedDate.isEmpty {
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SourceAttributionChip: View {
    let feedTitle: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text("via \(feedTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
    }
}

struct DiscoveryMarkdownImageView: View {
    let imageURL: URL?
    let viewModel: DiscoveryViewModel

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        if let imageURL, isWebURL(imageURL) {
            Group {
                if let loadedImage {
                    DiscoveryTrueSizeImage(image: loadedImage) {
                        viewModel.selectedImageURL = imageURL
                    }
                } else if loadFailed {
                    DiscoveryImagePlaceholder()
                } else {
                    DiscoveryImageLoadingView()
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

struct DiscoveryTrueSizeImage: View {
    let image: UIImage
    let onTap: () -> Void

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: image.size.width)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture(perform: onTap)
    }
}

struct DiscoveryImageLoadingView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.1))
            .frame(height: 200)
            .overlay {
                ProgressView()
            }
    }
}

struct DiscoveryImagePlaceholder: View {
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

struct DiscoveryImageProvider: ImageProvider {
    let viewModel: DiscoveryViewModel

    func makeImage(url: URL?) -> some View {
        DiscoveryMarkdownImageView(imageURL: url, viewModel: viewModel)
    }
}
