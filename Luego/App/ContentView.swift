//
//  ContentView.swift
//  Luego
//
//  Created by Arun Sasidharan on 10/11/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.diContainer) private var diContainer

    @State private var selectedFilter: ArticleFilter = .readingList
    @State private var selectedArticle: Article?
    @State private var selectedTab = 0
    @State private var shouldAnimateHomeEmptyStateOnLaunch = true

    #if os(macOS)
    @State private var addArticleSheet: MacAddArticleSheetState?
    @AppStorage("streaming_logs_enabled") private var streamingLogsEnabled = false
    @AppStorage("mac_article_list_column_width") private var storedArticleListColumnWidth = 300.0
    @State private var articleListDragStartWidth: Double?
    @State private var isArticleListDividerHovered = false
    private let sidebarColumnWidth: CGFloat = 56
    private let minimumArticleListColumnWidth: CGFloat = 260
    private let maximumArticleListColumnWidth: CGFloat = 520
    private let minimumDetailPaneWidth: CGFloat = 480
    private let splitDividerWidth: CGFloat = 12
    private let regularLayoutMinimumWidth: CGFloat = 1000
    private let regularLayoutMinimumHeight: CGFloat = 700
    #endif

    var body: some View {
        let root = ZStack {
            Color.paperCream
                .ignoresSafeArea()

            Group {
                if horizontalSizeClass == .regular {
                    #if os(macOS)
                    regularLayoutWithStreamingLogs
                    #else
                    iPadLayout
                    #endif
                } else {
                    iPhoneLayout
                }
            }
        }

        #if os(macOS)
        root
            .font(.nunito(.body))
            .sheet(item: $addArticleSheet) { addArticleSheet in
                MacAddArticleSheet(viewModel: addArticleSheet.viewModel)
            }
        #else
        root
            .font(.nunito(.body))
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private var regularLayoutWithStreamingLogs: some View {
        if streamingLogsEnabled {
            VSplitView {
                macOSLayout
                    .frame(minHeight: 360)

                StreamingLogsView(logStream: LogStream.shared)
                    .frame(minHeight: 220)
            }
            .frame(minWidth: regularLayoutMinimumWidth, minHeight: regularLayoutMinimumHeight)
        } else {
            macOSLayout
                .frame(minWidth: regularLayoutMinimumWidth, minHeight: regularLayoutMinimumHeight)
        }
    }

    @ViewBuilder
    private var macOSLayout: some View {
        if selectedFilter == .discovery {
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: sidebarColumnWidth)

                    Divider()

                    DiscoveryPane()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                SidebarView(selection: $selectedFilter, onAddArticle: presentAddArticleSheet)
                    .frame(width: sidebarColumnWidth)
            }
            .tint(Color.regularSelectionInk)
            .appNavigationChrome()
        } else {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width

                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Color.clear
                            .frame(width: sidebarColumnWidth)

                        Divider()

                        ArticleListPane(
                            filter: selectedFilter,
                            selectedArticle: $selectedArticle,
                            onDiscover: { selectedFilter = .discovery },
                            shouldAnimateEmptyStateOnFirstAppearance: shouldAnimateHomeEmptyStateOnLaunch,
                            onEmptyStateAnimationConsumed: { shouldAnimateHomeEmptyStateOnLaunch = false }
                        )
                        .frame(width: articleListColumnWidth(for: totalWidth))

                        articleListResizeHandle(totalWidth: totalWidth)

                        DetailPane(article: selectedArticle)
                            .frame(minWidth: minimumDetailPaneWidth, maxWidth: .infinity, maxHeight: .infinity)
                    }

                    SidebarView(selection: $selectedFilter, onAddArticle: presentAddArticleSheet)
                        .frame(width: sidebarColumnWidth)
                }
                .onAppear {
                    clampStoredArticleListWidth(for: totalWidth)
                }
                .onChange(of: totalWidth) { _, newWidth in
                    clampStoredArticleListWidth(for: newWidth)
                }
            }
            .tint(Color.regularSelectionInk)
            .appNavigationChrome()
        }
    }

    private func presentAddArticleSheet() {
        guard let container = diContainer else { return }
        addArticleSheet = MacAddArticleSheetState(viewModel: container.makeArticleListViewModel())
    }

    private func articleListColumnWidth(for totalWidth: CGFloat) -> CGFloat {
        clamp(CGFloat(storedArticleListColumnWidth), within: articleListColumnWidthBounds(for: totalWidth))
    }

    private func articleListColumnWidthBounds(for totalWidth: CGFloat) -> ClosedRange<CGFloat> {
        let maxWidthFromWindow = totalWidth - sidebarColumnWidth - splitDividerWidth - minimumDetailPaneWidth
        let upperBound = max(
            minimumArticleListColumnWidth,
            min(maximumArticleListColumnWidth, maxWidthFromWindow)
        )

        return minimumArticleListColumnWidth...upperBound
    }

    private func clampStoredArticleListWidth(for totalWidth: CGFloat) {
        storedArticleListColumnWidth = Double(articleListColumnWidth(for: totalWidth))
    }

    private func updateArticleListColumnWidth(with translation: CGFloat, totalWidth: CGFloat) {
        let startWidth = articleListDragStartWidth ?? storedArticleListColumnWidth
        articleListDragStartWidth = startWidth

        let updatedWidth = clamp(
            CGFloat(startWidth) + translation,
            within: articleListColumnWidthBounds(for: totalWidth)
        )

        storedArticleListColumnWidth = Double(updatedWidth)
    }

    private func articleListResizeHandle(totalWidth: CGFloat) -> some View {
        ZStack {
            Color.clear

            Rectangle()
                .fill(splitDividerColor)
                .frame(width: 1)
        }
        .frame(width: splitDividerWidth)
        .background(splitDividerBackground)
        .contentShape(Rectangle())
        .onHover { isHovered in
            isArticleListDividerHovered = isHovered
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    updateArticleListColumnWidth(with: value.translation.width, totalWidth: totalWidth)
                }
                .onEnded { value in
                    updateArticleListColumnWidth(with: value.translation.width, totalWidth: totalWidth)
                    articleListDragStartWidth = nil
                }
        )
    }

    private var splitDividerColor: Color {
        if articleListDragStartWidth != nil {
            return Color.regularSelectionInk.opacity(0.32)
        }

        if isArticleListDividerHovered {
            return Color.regularOutline.opacity(0.82)
        }

        return Color.regularOutline.opacity(0.56)
    }

    private var splitDividerBackground: Color {
        if articleListDragStartWidth != nil {
            return Color.regularSelectionFill.opacity(0.28)
        }

        if isArticleListDividerHovered {
            return Color.regularSelectionFill.opacity(0.18)
        }

        return .clear
    }

    private func clamp(_ value: CGFloat, within range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
    #endif

    @ViewBuilder
    private var iPadLayout: some View {
        if selectedFilter == .discovery {
            NavigationSplitView {
                SidebarView(selection: $selectedFilter)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            } detail: {
                DiscoveryPane()
            }
            .tint(Color.regularSelectionInk)
            .appNavigationChrome()
        } else {
            NavigationSplitView {
                SidebarView(selection: $selectedFilter)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            } content: {
                ArticleListPane(
                    filter: selectedFilter,
                    selectedArticle: $selectedArticle,
                    onDiscover: { selectedFilter = .discovery },
                    shouldAnimateEmptyStateOnFirstAppearance: shouldAnimateHomeEmptyStateOnLaunch,
                    onEmptyStateAnimationConsumed: { shouldAnimateHomeEmptyStateOnLaunch = false }
                )
                .navigationSplitViewColumnWidth(min: 300, ideal: 320, max: 400)
            } detail: {
                DetailPane(article: selectedArticle)
                    .navigationSplitViewColumnWidth(min: 500, ideal: 500)
            }
            .tint(Color.regularSelectionInk)
            .appNavigationChrome()
        }
    }

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            Tab(ArticleFilter.readingList.navigationTitle, systemImage: "list.bullet", value: 0) {
                iPhoneTabBackground {
                    iPhoneTabNavigationStack {
                        ArticleListView(
                            filter: .readingList,
                            shouldAnimateEmptyStateOnFirstAppearance: shouldAnimateHomeEmptyStateOnLaunch,
                            onEmptyStateAnimationConsumed: { shouldAnimateHomeEmptyStateOnLaunch = false }
                        )
                    }
                }
            }

            Tab(ArticleFilter.favorites.navigationTitle, systemImage: "heart", value: 1) {
                iPhoneTabBackground {
                    iPhoneTabNavigationStack {
                        ArticleListView(filter: .favorites)
                    }
                }
            }

            Tab(ArticleFilter.archived.navigationTitle, systemImage: "archivebox.fill", value: 2) {
                iPhoneTabBackground {
                    iPhoneTabNavigationStack {
                        ArticleListView(filter: .archived)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            iPhoneTabBar
        }
    }

    private func iPhoneTabBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.paperCream
                .ignoresSafeArea()

            content()
        }
    }

    private func iPhoneTabNavigationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
        }
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
    }

    private var iPhoneTabBar: some View {
        #if os(iOS)
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 4) {
                iPhoneTabButton(systemImage: "list.bullet", label: "Reading List", tab: 0)
                iPhoneTabButton(systemImage: "heart.fill", label: "Favorites", tab: 1)
                iPhoneTabButton(systemImage: "archivebox.fill", label: "Archived", tab: 2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        .padding(.horizontal, 60)
        .padding(.top, 4)
        .padding(.bottom, 8)
        #else
        HStack(spacing: 4) {
            iPhoneTabButton(systemImage: "list.bullet", label: "Reading List", tab: 0)
            iPhoneTabButton(systemImage: "heart.fill", label: "Favorites", tab: 1)
            iPhoneTabButton(systemImage: "archivebox.fill", label: "Archived", tab: 2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        #if os(iOS)
        .glassEffect(.regular.interactive(), in: Capsule())
        #else
        .background(
            Capsule()
                .fill(Color.white.opacity(0.7))
        )
        #endif
        .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        .padding(.horizontal, 60)
        .padding(.top, 4)
        .padding(.bottom, 8)
        #endif
    }

    @ViewBuilder
    private func iPhoneTabButton(systemImage: String, label: String, tab: Int) -> some View {
        let isSelected = selectedTab == tab

        #if os(iOS)
        if isSelected {
            Button {
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.05)) {
                    selectedTab = tab
                }
            } label: {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(Color.mascotPurpleInk)
            }
            .tint(Color.mascotPurple.opacity(0.72))
            .buttonStyle(.glassProminent)
            .contentShape(Capsule())
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isSelected)
        } else {
            Button {
                withAnimation(.snappy(duration: 0.28, extraBounce: 0.05)) {
                    selectedTab = tab
                }
            } label: {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(Color.primary.opacity(0.82))
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .accessibilityLabel(label)
            .accessibilityRemoveTraits(.isSelected)
        }
        #else
        Button {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.05)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .foregroundStyle(isSelected ? Color.mascotPurpleInk : Color.primary.opacity(0.82))
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        #endif
    }
}

#if os(macOS)
private struct MacAddArticleSheetState: Identifiable {
    let id = UUID()
    let viewModel: ArticleListViewModel
}

private struct MacAddArticleSheet: View {
    let viewModel: ArticleListViewModel
    @Query(sort: \Article.savedDate, order: .reverse) private var allArticles: [Article]

    var body: some View {
        AddArticleView(viewModel: viewModel, existingArticles: allArticles)
            .accessibilityIdentifier("addArticle.container")
            .frame(minWidth: 460, idealWidth: 520, minHeight: 300, idealHeight: 340)
    }
}
#endif
