import SwiftUI

struct ContentElementView: View {
    let element: ContentElement
    let markers: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(markers, id: \.self) { markerIndex in
                Color.clear
                    .frame(height: 1)
                    .id("marker_\(markerIndex)")
            }

            elementView
        }
    }

    @ViewBuilder
    private var elementView: some View {
        switch element {
        case .heading1(let text):
            Text(text)
                .font(.system(.title, design: .serif, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 24)
                .padding(.bottom, 12)

        case .heading2(let text):
            Text(text)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 20)
                .padding(.bottom, 10)

        case .heading3(let text):
            Text(text)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 16)
                .padding(.bottom, 8)

        case .heading4(let text):
            Text(text)
                .font(.system(.headline, design: .serif, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 14)
                .padding(.bottom, 6)

        case .heading5(let text):
            Text(text)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 12)
                .padding(.bottom, 6)

        case .heading6(let text):
            Text(text)
                .font(.system(.subheadline, design: .serif, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 6)

        case .blockquote(let text):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 4)

                Text(text)
                    .font(.system(.body, design: .serif))
                    .italic()
                    .foregroundColor(.secondary)
                    .lineSpacing(6)
            }
            .padding(.vertical, 12)

        case .listItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.system(.body, design: .serif, weight: .bold))
                    .foregroundColor(.primary)

                Text(text)
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.primary)
                    .lineSpacing(6)
            }
            .padding(.bottom, 4)

        case .paragraph(let text):
            Text(text)
                .font(.system(.body, design: .serif))
                .lineSpacing(8)
                .foregroundColor(.primary)
                .padding(.bottom, 16)
        }
    }
}
