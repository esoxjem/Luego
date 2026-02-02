import SwiftUI

struct HighlightMenuView: View {
    let onColorSelected: (HighlightColor) -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    onColorSelected(color)
                } label: {
                    Circle()
                        .fill(swiftUIColor(for: color))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Highlight \(color.rawValue)")
            }

            if let onDelete {
                Divider().frame(height: 24)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete highlight")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func swiftUIColor(for color: HighlightColor) -> Color {
        switch color {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .pink: return .pink
        }
    }
}
