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
    @AppStorage("streaming_logs_enabled") private var streamingLogsEnabled = false
    #endif

    var body: some View {
        ZStack {
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
        .font(.nunito(.body))
    }

    #if os(macOS)
    @ViewBuilder
    private var regularLayoutWithStreamingLogs: some View {
        if streamingLogsEnabled {
            VSplitView {
                iPadLayout
                    .frame(minHeight: 360)

                StreamingLogsView(logStream: LogStream.shared)
                    .frame(minHeight: 220)
            }
            .frame(minWidth: 1000, minHeight: 700)
        } else {
            iPadLayout
        }
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
        }
    }

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            Tab("", systemImage: "list.bullet", value: 0) {
                iPhoneTabBackground {
                    NavigationStack {
                        ArticleListView(
                            filter: .readingList,
                            shouldAnimateEmptyStateOnFirstAppearance: shouldAnimateHomeEmptyStateOnLaunch,
                            onEmptyStateAnimationConsumed: { shouldAnimateHomeEmptyStateOnLaunch = false }
                        )
                    }
                }
            }

            Tab("", systemImage: "heart", value: 1) {
                iPhoneTabBackground {
                    NavigationStack {
                        ArticleListView(filter: .favorites)
                    }
                }
            }

            Tab("", systemImage: "archivebox.fill", value: 2) {
                iPhoneTabBackground {
                    NavigationStack {
                        ArticleListView(filter: .archived)
                    }
                }
            }
        }
    }

    private func iPhoneTabBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.paperCream
                .ignoresSafeArea()

            content()
        }
    }
}
