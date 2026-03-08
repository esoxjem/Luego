import SwiftUI

struct SidebarView: View {
    @Binding var selection: ArticleFilter
    @Environment(SyncStatusObserver.self) private var syncStatusObserver: SyncStatusObserver?

    var body: some View {
        #if os(macOS)
        macOSSidebar
        #else
        iPadSidebar
        #endif
    }

    #if os(macOS)
    private var macOSSidebar: some View {
        List(selection: $selection) {
            Section {
                filterRow(.readingList)
                filterRow(.favorites)
                filterRow(.archived)
            } header: {
                SidebarSectionHeader(title: "Library")
            }

            Section {
                filterRow(.discovery)
            } header: {
                SidebarSectionHeader(title: "Discover")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Luego")
        .safeAreaInset(edge: .bottom) {
            SidebarSettingsButton(
                state: syncStatusObserver?.state ?? .idle,
                lastSyncTime: syncStatusObserver?.lastSyncTime
            )
        }
    }

    private func filterRow(_ filter: ArticleFilter) -> some View {
        Label(filter.title, systemImage: filter.icon)
            .tag(filter)
    }
    #endif

    private var iPadSidebar: some View {
        List {
            ForEach(ArticleFilter.allCases, id: \.self) { filter in
                iPadFilterButton(for: filter)
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

    private func iPadFilterButton(for filter: ArticleFilter) -> some View {
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
struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.tertiary)
            .kerning(0.8)
            .padding(.top, 4)
    }
}

struct SidebarSettingsButton: View {
    let state: SyncState
    let lastSyncTime: Date?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

            VStack(spacing: 8) {
                SyncStatusRow(state: state, lastSyncTime: lastSyncTime, verticalPadding: .top)

                SettingsLink {
                    HStack {
                        Image(systemName: "gear")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text("Settings")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("⌘,")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
        }
        .background(.bar)
    }
}

#endif
