import SwiftUI

#if os(macOS)
struct MacAppBackground: View {
    var body: some View {
        ZStack {
            Color.paperCream
            MacAppMeshBackdrop()
        }
        .ignoresSafeArea()
    }
}

struct MacAppMeshBackdrop: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.mascotPurple.opacity(0.22), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 420, height: 420)
                .blur(radius: 30)
                .offset(x: -180, y: -220)

            Circle()
                .fill(LinearGradient(colors: [Color.regularSelectionInk.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 360, height: 360)
                .blur(radius: 40)
                .offset(x: 220, y: -120)

            Circle()
                .fill(LinearGradient(colors: [Color.mascotPurple.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 380, height: 380)
                .blur(radius: 50)
                .offset(x: 40, y: 260)
        }
        .allowsHitTesting(false)
    }
}

struct MacAppCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .separatorColor).opacity(0.55),
                            Color(nsColor: .separatorColor).opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

struct MacAppPane<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        MacAppCard {
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct MacAppSidebarPanelBackground: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.paperCream,
                        Color.white.opacity(0.7),
                        Color.mascotPurple.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.42),
                        Color.clear,
                        Color.mascotPurple.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.28))
                    .frame(width: 1)
            }
    }
}

struct MacAppSidebarGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 8) {
            content
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.mascotPurple.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.regularOutline.opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
#endif
