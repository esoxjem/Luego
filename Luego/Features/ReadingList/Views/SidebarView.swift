import SwiftUI

struct SidebarView: View {
    @Binding var selection: ArticleFilter

    // macOS and iPad sidebars use different implementations:
    // - macOS: List(selection:) for native keyboard navigation, sections for HIG compliance
    // - iPad: Button-based for consistent tap behavior across iOS navigation patterns

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
            Section("Library") {
                filterRow(.readingList)
                filterRow(.favorites)
                filterRow(.archived)
            }
            Section("Discover") {
                filterRow(.discovery)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Luego")
        .safeAreaInset(edge: .bottom) {
            SettingsLink {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.bar)
            .accessibilityLabel("Settings")
        }
    }

    private func filterRow(_ filter: ArticleFilter) -> some View {
        Label(filter.title, systemImage: filter.icon).tag(filter)
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
