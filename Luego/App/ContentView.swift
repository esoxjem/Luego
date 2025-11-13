//
//  ContentView.swift
//  Luego
//
//  Created by Arun Sasidharan on 10/11/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ArticleListView(filter: .readingList)
            }
            .tabItem {
                Image(systemName: "list.bullet")
            }
            .tag(0)

            NavigationStack {
                ArticleListView(filter: .favorites)
            }
            .tabItem {
                Image(systemName: "heart")
            }
            .tag(1)

            NavigationStack {
                ArticleListView(filter: .archived)
            }
            .tabItem {
                Image(systemName: "archivebox.fill")
            }
            .tag(2)
        }
    }
}

