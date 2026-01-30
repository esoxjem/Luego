import SwiftUI

struct SidebarView: View {
    @Binding var selection: ArticleFilter

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
            SidebarSettingsButton()
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
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.5)

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
        .background(.bar)
    }
}
#endif
