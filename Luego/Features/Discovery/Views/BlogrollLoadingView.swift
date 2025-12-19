import SwiftUI

struct BlogrollLoadingView: View {
    var pendingURL: URL?
    var loadingText: String
    @State private var isAnimating = false

    var body: some View {
        VStack {
            Spacer()

            BlogrollLoadingAnimation(isAnimating: $isAnimating)
                .frame(width: 88, height: 31)

            Spacer()

            VStack(spacing: 16) {
                Text(loadingText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let domain = pendingURL?.host() {
                    LoadingDomainChip(domain: domain)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: pendingURL)
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

struct BlogrollLoadingAnimation: View {
    @Binding var isAnimating: Bool
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        BlogrollLogoView()
            .frame(width: 31, height: 31)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onChange(of: isAnimating, initial: true) { _, newValue in
                if newValue {
                    startAnimation()
                }
            }
    }

    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            scale = 1.15
        }

        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}

struct BlogrollLogoView: View {
    private let topLeftColor = Color(red: 62/255, green: 175/255, blue: 124/255)
    private let topRightColor = Color(red: 237/255, green: 229/255, blue: 116/255)
    private let bottomLeftColor = Color(red: 245/255, green: 255/255, blue: 196/255)
    private let bottomRightColor = Color(red: 44/255, green: 62/255, blue: 80/255)

    var body: some View {
        GeometryReader { geometry in
            let halfWidth = geometry.size.width / 2
            let halfHeight = geometry.size.height / 2

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(topLeftColor)
                        .frame(width: halfWidth, height: halfHeight)

                    Rectangle()
                        .fill(topRightColor)
                        .frame(width: halfWidth, height: halfHeight)
                }

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(bottomLeftColor)
                        .frame(width: halfWidth, height: halfHeight)

                    Rectangle()
                        .fill(bottomRightColor)
                        .frame(width: halfWidth, height: halfHeight)
                }
            }
        }
    }
}
