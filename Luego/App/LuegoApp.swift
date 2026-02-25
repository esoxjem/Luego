//
//  LuegoApp.swift
//  Luego
//
//  Created by Arun Sasidharan on 10/11/25.
//

import SwiftUI
import SwiftData
import CloudKit

@main
struct LuegoApp: App {
    let sharedModelContainer: ModelContainer
    @State private var diContainer: DIContainer
    #if os(macOS)
    @State private var appUpdateController = AppUpdateController()
    #endif

    init() {
        let schema = Schema([
            Article.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(AppConfiguration.cloudKitContainerIdentifier)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            self._diContainer = State(initialValue: DIContainer(modelContext: container.mainContext))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
                .task(id: "launchDiagnostics") {
                    await logLaunchDiagnostics()
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        #endif

        #if os(macOS)
        Settings {
            SettingsView(
                viewModel: diContainer.makeSettingsViewModel(),
                syncStatusObserver: diContainer.syncObserver
            )
            .modelContainer(sharedModelContainer)
        }
        .commands {
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

extension LuegoApp {
    @MainActor
    private func logLaunchDiagnostics() async {
        // Log app identity info
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        Logger.cloudKit.info("Launch diagnostics — App: \(bundleID) v\(appVersion) (\(buildNumber))")

        // Log CloudKit container info
        Logger.cloudKit.info("Launch diagnostics — CloudKit container: \(AppConfiguration.cloudKitContainerIdentifier)")

        do {
            let status = try await CKContainer(identifier: AppConfiguration.cloudKitContainerIdentifier).accountStatus()
            let statusName = switch status {
            case .available: "available"
            case .noAccount: "noAccount"
            case .restricted: "restricted"
            case .couldNotDetermine: "couldNotDetermine"
            case .temporarilyUnavailable: "temporarilyUnavailable"
            @unknown default: "unknown(\(status.rawValue))"
            }
            Logger.cloudKit.info("Launch diagnostics — iCloud account status: \(statusName)")
        } catch {
            Logger.cloudKit.error("Launch diagnostics — failed to check iCloud account: \(error.localizedDescription)")
        }

        do {
            let descriptor = FetchDescriptor<Article>()
            let count = try sharedModelContainer.mainContext.fetchCount(descriptor)
            Logger.cloudKit.info("Launch diagnostics — article count at startup: \(count)")

            #if DEBUG
            do {
                let articles = try sharedModelContainer.mainContext.fetch(descriptor)
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

        do {
            let container = CKContainer(identifier: AppConfiguration.cloudKitContainerIdentifier)
            let subscriptions = try await container.privateCloudDatabase.allSubscriptions()
            Logger.cloudKit.info("Launch diagnostics — active subscriptions: \(subscriptions.count)")
            for subscription in subscriptions {
                Logger.cloudKit.debug("Launch diagnostics — subscription: \(subscription.subscriptionID), type: \(subscription.subscriptionType.rawValue)")
            }
        } catch {
            Logger.cloudKit.warning("Launch diagnostics — failed to fetch subscriptions: \(error.localizedDescription)")
        }

        // Log platform info for cross-device comparison
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
