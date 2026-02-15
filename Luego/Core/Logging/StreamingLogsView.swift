#if os(macOS)
import SwiftUI

struct StreamingLogsView: View {
    let logStream: LogStream
    @State private var selectedCategory: String?

    private var filteredEntries: [LogEntry] {
        guard let category = selectedCategory else { return logStream.entries }
        return logStream.entries.filter { $0.category == category }
    }

    private var availableCategories: [String] {
        Array(Set(logStream.entries.map(\.category))).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            StreamingLogsHeader(
                entryCount: filteredEntries.count,
                entries: filteredEntries,
                availableCategories: availableCategories,
                selectedCategory: $selectedCategory,
                onClear: logStream.clear
            )

            Divider()

            StreamingLogsContent(entries: filteredEntries)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct StreamingLogsHeader: View {
    let entryCount: Int
    let entries: [LogEntry]
    let availableCategories: [String]
    @Binding var selectedCategory: String?
    let onClear: () -> Void

    @State private var showCopiedToast = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Text("Logs")
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

                if showCopiedToast {
                    Text("Copied to clipboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                Button(action: copyAllLogs) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .disabled(entries.isEmpty)

                Button(action: onClear) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if !availableCategories.isEmpty {
                LogCategoryFilter(
                    categories: availableCategories,
                    selectedCategory: $selectedCategory
                )
            }
        }
        .background(.bar)
    }

    private func copyAllLogs() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        let text = entries.map { entry in
            "\(formatter.string(from: entry.timestamp)) \(entry.category) \(entry.level.symbol) \(entry.message)"
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        withAnimation(.easeInOut(duration: 0.2)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedToast = false
            }
        }
    }
}

struct LogCategoryFilter: View {
    let categories: [String]
    @Binding var selectedCategory: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                FilterChip(label: "All", isSelected: selectedCategory == nil) {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = nil }
                }

                ForEach(categories, id: \.self) { category in
                    FilterChip(label: category, isSelected: selectedCategory == category) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? Color.accentColor.opacity(0.2)
                              : Color(nsColor: .separatorColor).opacity(0.15))
                )
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
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
