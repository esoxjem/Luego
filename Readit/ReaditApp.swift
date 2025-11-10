//
//  ReaditApp.swift
//  Readit
//
//  Created by Arun Sasidharan on 10/11/25.
//

import SwiftUI
import SwiftData

@main
struct ReaditApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Article.self)
    }
}
