import SwiftUI

struct SidebarView: View {
    @Binding var selection: ArticleFilter
    let onAddArticle: (() -> Void)?
    @Environment(SyncStatusObserver.self) private var syncStatusObserver: SyncStatusObserver?
    #if os(macOS)
    private let macSidebarTopInset: CGFloat = 56
    private let macSidebarBottomInset: CGFloat = 12
    private let macSidebarHorizontalInset: CGFloat = 6
    #endif

    init(selection: Binding<ArticleFilter>, onAddArticle: (() -> Void)? = nil) {
        _selection = selection
        self.onAddArticle = onAddArticle
    }

    var body: some View {
        #if os(macOS)
        macOSSidebar
        #else
        iPadSidebar
        #endif
    }

    #if os(macOS)
    private var macOSSidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                MacSidebarBrandAnchor()
                    .padding(.top, 10)

                MacAppSidebarGroup {
                    macSidebarFilterButton(.readingList)
                    macSidebarFilterButton(.favorites)
                    macSidebarFilterButton(.archived)
                }

                MacAppSidebarGroup {
                    macSidebarFilterButton(.discovery)

                    if let onAddArticle {
                        MacSidebarActionButton(
                            symbolName: "plus",
                            title: "Add Article",
                            action: onAddArticle
                        )
                    }
                }

                Spacer(minLength: 0)

                SidebarSettingsButton(
                    state: syncStatusObserver?.state ?? .idle,
                    lastSyncTime: syncStatusObserver?.lastSyncTime
                )
                .padding(.bottom, 4)
            }
            .padding(.horizontal, macSidebarHorizontalInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, macSidebarTopInset)
        .padding(.bottom, macSidebarBottomInset)
        .background(MacAppSidebarPanelBackground())
    }

    private func macSidebarFilterButton(_ filter: ArticleFilter) -> some View {
        MacSidebarFilterButton(
            filter: filter,
            isSelected: selection == filter,
            action: { selection = filter }
        )
    }
    #endif

    private var iPadSidebar: some View {
        List {
            ForEach(ArticleFilter.allCases, id: \.self) { filter in
                sidebarFilterButton(for: filter)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(sidebarRowBackground(isSelected: selection == filter))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.regularPanelBackground)
        .navigationTitle("Luego")
        .appNavigationChrome()
        .safeAreaInset(edge: .bottom) {
            SidebarSyncFooter(
                state: syncStatusObserver?.state ?? .idle,
                lastSyncTime: syncStatusObserver?.lastSyncTime
            )
        }
    }

    private func sidebarFilterButton(for filter: ArticleFilter) -> some View {
        let isSelected = selection == filter

        return Button {
            selection = filter
        } label: {
            HStack(spacing: 12) {
                Image(systemName: filter.icon)
                    .frame(width: 20)

                Text(filter.title)

                Spacer(minLength: 0)
            }
            .font(.nunito(.body, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.regularSelectionInk : Color.primary.opacity(0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func sidebarRowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isSelected ? Color.regularSelectionFill : Color.clear)
            .padding(.horizontal, 2)
            .padding(.vertical, 1)
    }
}

struct SyncStatusRow: View {
    let state: SyncState
    let lastSyncTime: Date?
    var verticalPadding: Edge.Set = .vertical

    private var formattedTime: String? {
        guard let time = lastSyncTime else { return nil }
        return DateFormatters.time.string(from: time)
    }

    var body: some View {
        HStack(spacing: 6) {
            SyncStatusIndicator(state: state, onErrorTap: nil)
                .font(.caption)

            if let timeText = formattedTime {
                Text("Synced at \(timeText)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(verticalPadding, 8)
    }
}

struct SidebarSyncFooter: View {
    let state: SyncState
    let lastSyncTime: Date?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            SyncStatusRow(state: state, lastSyncTime: lastSyncTime)
        }
        .background(Color.regularPanelBackground)
    }
}

#if os(macOS)
private struct MacSidebarBrandAnchor: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.72),
                            Color.mascotPurple.opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image("Kike")
                .resizable()
                .renderingMode(.original)
                .scaledToFill()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .blendMode(.screen)
                .offset(y: 0.5)
        }
        .frame(width: 32, height: 32)
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.5))
        }
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        .accessibilityHidden(true)
    }
}

private struct MacSidebarFilterButton: View {
    let filter: ArticleFilter
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var fillStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.regularSelectionFill.opacity(0.95),
                        Color.mascotPurple.opacity(0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        if isHovered {
            return AnyShapeStyle(Color.white.opacity(0.42))
        }

        return AnyShapeStyle(Color.clear)
    }

    private var strokeColor: Color {
        if isSelected {
            return Color.regularSelectionInk.opacity(0.16)
        }

        if isHovered {
            return Color.regularOutline.opacity(0.75)
        }

        return .clear
    }

    private var iconColor: Color {
        if isSelected {
            return .regularSelectionInk
        }

        if isHovered {
            return Color.primary.opacity(0.88)
        }

        return Color.primary.opacity(0.72)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: filter.icon)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(fillStyle)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(strokeColor)
                }
                .shadow(
                    color: isSelected ? Color.regularSelectionInk.opacity(0.16) : .clear,
                    radius: 10,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isHovered && !isSelected ? 1.03 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(filter.title)
        .accessibilityLabel(filter.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { hovered in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovered
            }
        }
    }
}

private struct MacSidebarActionButton: View {
    let symbolName: String
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    private var fillStyle: AnyShapeStyle {
        if isHovered {
            return AnyShapeStyle(Color.white.opacity(0.42))
        }

        return AnyShapeStyle(Color.clear)
    }

    private var strokeColor: Color {
        if isHovered {
            return Color.regularOutline.opacity(0.75)
        }

        return .clear
    }

    private var iconColor: Color {
        if isHovered {
            return Color.primary.opacity(0.88)
        }

        return Color.primary.opacity(0.72)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(fillStyle)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(strokeColor)
                }
                .scaleEffect(isHovered ? 1.03 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .onHover { hovered in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovered
            }
        }
    }
}

struct SidebarSettingsButton: View {
    let state: SyncState
    let lastSyncTime: Date?

    private var syncHelp: String {
        switch state {
        case .idle, .success:
            if let lastSyncTime {
                return "Synced at \(DateFormatters.time.string(from: lastSyncTime))"
            }
            return "Sync idle"
        case .syncing:
            return "Syncing with iCloud"
        case .error(let message, _):
            return "Sync error: \(message)"
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle:
            return .clear
        case .syncing:
            return Color.regularSelectionInk.opacity(0.9)
        case .success:
            return .green
        case .error:
            return .red
        }
    }

    var body: some View {
        SettingsLink {
            Image(systemName: "gearshape")
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color.primary.opacity(0.74))
                .frame(width: 36, height: 36)
                .overlay(alignment: .topTrailing) {
                    if state != .idle {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 9, height: 9)
                            .overlay {
                                Circle()
                                    .stroke(Color.paperCream, lineWidth: 1.5)
                            }
                            .offset(x: 2, y: -2)
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .help("Settings (⌘,)\n\(syncHelp)")
    }
}
#endif
