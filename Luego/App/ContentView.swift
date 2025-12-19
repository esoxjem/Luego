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

