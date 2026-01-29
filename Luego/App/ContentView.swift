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

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    @ViewBuilder
    private var iPadLayout: some View {
        if selectedFilter == .discovery {
            NavigationSplitView {
                SidebarView(selection: $selectedFilter)
            } detail: {
                DiscoveryPane()
            }
        } else {
            NavigationSplitView {
                SidebarView(selection: $selectedFilter)
            } content: {
                ArticleListPane(
                    filter: selectedFilter,
                    selectedArticle: $selectedArticle,
                    onDiscover: { selectedFilter = .discovery }
                )
            } detail: {
                DetailPane(article: selectedArticle)
            }
        }
    }

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            Tab("", systemImage: "list.bullet", value: 0) {
                NavigationStack {
                    ArticleListView(filter: .readingList)
                }
            }

            Tab("", systemImage: "heart", value: 1) {
                NavigationStack {
                    ArticleListView(filter: .favorites)
                }
            }

            Tab("", systemImage: "archivebox.fill", value: 2) {
                NavigationStack {
                    ArticleListView(filter: .archived)
                }
            }
        }
    }
}

