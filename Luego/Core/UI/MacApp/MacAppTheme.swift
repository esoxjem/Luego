import SwiftUI

#if os(macOS)
struct MacAppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.85),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            MacAppMeshBackdrop()
        }
        .ignoresSafeArea()
    }
}

struct MacAppMeshBackdrop: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.accentColor.opacity(0.15), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 420, height: 420)
                .blur(radius: 30)
                .offset(x: -180, y: -220)

            Circle()
                .fill(LinearGradient(colors: [Color.blue.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 360, height: 360)
                .blur(radius: 40)
                .offset(x: 220, y: -120)

            Circle()
                .fill(LinearGradient(colors: [Color.mint.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
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

struct MacAppSidebarBackground: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.45))
                    .frame(width: 1)
            }
    }
}
#endif
