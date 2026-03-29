//
//  ContentView.swift
//  Luego
//
//  Created by Arun Sasidharan on 10/11/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedFilter: ArticleFilter = .readingList
    @State private var selectedArticle: Article?
    @State private var selectedTab = 0
    @State private var shouldAnimateHomeEmptyStateOnLaunch = true

    var body: some View {
        ZStack {
            Color.paperCream
                .ignoresSafeArea()

            Group {
                if horizontalSizeClass == .regular {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
        }
        .font(.app(.body))
    }

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
        .toolbar(.hidden, for: .tabBar)
    }

    private var iPhoneTabBar: some View {
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
    }

    @ViewBuilder
    private func iPhoneTabButton(systemImage: String, label: String, tab: Int) -> some View {
        let isSelected = selectedTab == tab

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
    }
}
