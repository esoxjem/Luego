#if os(macOS)
import SwiftUI

struct StreamingLogsView: View {
    let logStream: LogStream

    var body: some View {
        VStack(spacing: 0) {
            StreamingLogsHeader(
                entryCount: logStream.entries.count,
                onClear: logStream.clear
            )

            Divider()

            StreamingLogsContent(entries: logStream.entries)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct StreamingLogsHeader: View {
    let entryCount: Int
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)
                .font(.caption)

            Text("Streaming Logs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text("\(entryCount)")
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                )

            Spacer()

            Button(action: onClear) {
                Label("Clear", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct StreamingLogsContent: View {
    let entries: [LogEntry]

    var body: some View {
        if entries.isEmpty {
            StreamingLogsEmptyState()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(entries) { entry in
                            LogEntryRow(entry: entry)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("streamingLogsBottom")
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: entries.count) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("streamingLogsBottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct StreamingLogsEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "text.alignleft")
                .font(.title3)
                .foregroundStyle(.quaternary)
            Text("Waiting for logs…")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(entry.timestamp, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(entry.category)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
                .lineLimit(1)

            Text(entry.level.symbol)
                .frame(width: 18, alignment: .center)

            Text(entry.message)
                .foregroundStyle(foregroundColor)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(rowBackground)
    }

    private var foregroundColor: Color {
        switch entry.level {
        case .error: .red
        case .warning: .orange
        default: .primary
        }
    }

    private var rowBackground: some ShapeStyle {
        switch entry.level {
        case .error: AnyShapeStyle(Color.red.opacity(0.06))
        case .warning: AnyShapeStyle(Color.orange.opacity(0.04))
        default: AnyShapeStyle(Color.clear)
        }
    }
}
#endif
