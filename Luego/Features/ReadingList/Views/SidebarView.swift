import SwiftUI

struct SidebarView: View {
    @Binding var selection: ArticleFilter

    var body: some View {
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
