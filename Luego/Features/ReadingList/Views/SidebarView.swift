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
                Button {
                    selection = filter
                } label: {
                    Label(filter.title, systemImage: filter.icon)
                }
                .listRowBackground(selection == filter ? Color.accentColor.opacity(0.2) : Color.clear)
            }
        }
        .navigationTitle("Luego")
        .safeAreaInset(edge: .bottom) {
            SidebarSyncFooter(
                state: syncStatusObserver?.state ?? .idle,
                lastSyncTime: syncStatusObserver?.lastSyncTime
            )
        }
    }
}

struct SidebarSyncFooter: View {
    let state: SyncState
    let lastSyncTime: Date?

    private var formattedTime: String? {
        guard let time = lastSyncTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

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
            .padding(.vertical, 8)
        }
        .background(.bar)
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
                SidebarSyncStatus(state: state, lastSyncTime: lastSyncTime)

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

struct SidebarSyncStatus: View {
    let state: SyncState
    let lastSyncTime: Date?

    private var formattedTime: String? {
        guard let time = lastSyncTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
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
        .padding(.top, 8)
    }
}
#endif
