import SwiftUI
import NetworkImage

struct FullscreenImageViewer: View {
    let imageURL: URL
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            ZoomableImageView(imageURL: imageURL)

            VStack {
                FullscreenImageToolbar(onDismiss: onDismiss)
                Spacer()
            }
        }
    }
}

struct ZoomableImageView: View {
    let imageURL: URL

    var body: some View {
        ZoomableScrollView {
            NetworkImage(url: imageURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    FullscreenImageLoadingView()
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
    }
}

struct FullscreenImageToolbar: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .blur(radius: 8)
                    )
            }
            .padding()
        }
    }
}

struct FullscreenImageLoadingView: View {
    var body: some View {
        ZStack {
            Color.black
            ProgressView()
                .tint(.white)
        }
    }
}
