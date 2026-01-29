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

    private var iPadLayout: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedFilter)
        } content: {
            contentPane
        } detail: {
            DetailPaneView(article: selectedArticle)
        }
    }

    @ViewBuilder
    private var contentPane: some View {
        if selectedFilter.isArticleList {
            ArticleListPane(
                filter: selectedFilter,
                selectedArticle: $selectedArticle
            )
        } else {
            DiscoveryPane()
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

