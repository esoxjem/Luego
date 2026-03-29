//
//  LuegoApp.swift
//  Luego
//
//  Created by Arun Sasidharan on 10/11/25.
//

import SwiftUI
import CloudKit

@main
struct LuegoApp: App {
    let database: AppDatabase
    @State private var diContainer: DIContainer
    #if os(macOS)
    @State private var appUpdateController = AppUpdateController()
    #endif

    init() {
        AppTypography.registerFonts()
        Self.configurePlatformAppearance()

        do {
            let database = try AppDatabase.makeDefault()
            self.database = database
            let container = DIContainer(database: database)
            try container.syncEngineManager.start()
            let legacyMigration = LegacySwiftDataArticleMigration(
                database: database,
                store: container.articleStore,
                syncEngineManager: container.syncEngineManager
            )
            do {
                let importedCount = try legacyMigration.migrateIfNeeded()
                Logger.cloudKit.info("Launch migration — imported \(importedCount) legacy SwiftData articles")
            } catch {
                Logger.cloudKit.error("Launch migration — failed to import legacy SwiftData articles: \(error.localizedDescription)")
            }
            self._diContainer = State(initialValue: container)
        } catch {
            fatalError("Could not create AppDatabase: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.diContainer, diContainer)
                .environment(diContainer.syncObserver)
                .task(id: "sdkInit") {
                    await diContainer.sdkManager.ensureSDKReady()
                }
                .task(id: "initialSync") {
                    _ = try? await diContainer.syncEngineManager.refresh(mode: .smart)
                }
                .task(id: "launchDiagnostics") {
                    await logLaunchDiagnostics()
                }
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        #endif

        #if os(macOS)
        Settings {
            SettingsView(
                viewModel: diContainer.makeSettingsViewModel(),
                syncStatusObserver: diContainer.syncObserver
            )
        }
        .commands {
            CommandGroup(replacing: .sidebar) {
            }
            #if !DEBUG
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Check for Updates…") {
                    appUpdateController.checkForUpdates()
                }
            }
            #endif
        }
        #endif
    }
}

private extension LuegoApp {
    static func configurePlatformAppearance() {
        AppNavigationAppearance.configurePlatformAppearance()
    }
}

extension LuegoApp {
    @MainActor
    private func logLaunchDiagnostics() async {
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        Logger.cloudKit.info("Launch diagnostics — App: \(bundleID) v\(appVersion) (\(buildNumber))")
        Logger.cloudKit.info("Launch diagnostics — CloudKit container: \(AppConfiguration.cloudKitContainerIdentifier)")

        let container = CKContainer(identifier: AppConfiguration.cloudKitContainerIdentifier)
        let diagnostics = await CloudKitRuntimeDiagnostics.collect(
            container: container,
            containerIdentifier: AppConfiguration.cloudKitContainerIdentifier
        )
        Logger.cloudKit.info("Launch diagnostics — \(diagnostics.summaryLine)")
        for line in diagnostics.detailLines {
            Logger.cloudKit.info("Launch diagnostics — \(line)")
        }

        do {
            let subscriptions = try await container.privateCloudDatabase.allSubscriptions()
            Logger.cloudKit.info("Launch diagnostics — active subscriptions: \(subscriptions.count)")
            for subscription in subscriptions {
                Logger.cloudKit.debug("Launch diagnostics — subscription: \(subscription.subscriptionID), type: \(subscription.subscriptionType.rawValue)")
            }
        } catch {
            Logger.cloudKit.warning("Launch diagnostics — failed to fetch subscriptions: \(error.localizedDescription)")
        }

        do {
            let count = try diContainer.articleStore.countArticles()
            Logger.cloudKit.info("Launch diagnostics — article count at startup: \(count)")

            #if DEBUG
            do {
                let articles = try diContainer.articleStore.fetchAllArticles()
                let sortedArticles = articles.sorted { lhs, rhs in
                    let lhsURL = lhs.url.absoluteString
                    let rhsURL = rhs.url.absoluteString

                    if lhsURL == rhsURL {
                        return lhs.id.uuidString < rhs.id.uuidString
                    }

                    return lhsURL < rhsURL
                }

                Logger.cloudKit.info("Launch diagnostics — article identity count: \(sortedArticles.count)")

                for article in sortedArticles {
                    Logger.cloudKit.info("Launch diagnostics — article identity: \(article.id.uuidString) | \(article.url.absoluteString)")
                }
            } catch {
                Logger.cloudKit.error("Launch diagnostics — failed to fetch article identities: \(error.localizedDescription)")
            }
            #endif
        } catch {
            Logger.cloudKit.error("Launch diagnostics — failed to count articles: \(error.localizedDescription)")
        }

        #if os(iOS)
        Logger.cloudKit.info("Launch diagnostics — Platform: iOS")
        #elseif os(macOS)
        Logger.cloudKit.info("Launch diagnostics — Platform: macOS")
        #endif
    }

}

private struct DIContainerKey: EnvironmentKey {
    @MainActor
    static let defaultValue: DIContainer? = nil
}

extension EnvironmentValues {
    var diContainer: DIContainer? {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}
