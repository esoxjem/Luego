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

    init() {
        let schema = Schema([
            Article.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.esoxjem.Luego")
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
        }
        #endif
    }
}

extension LuegoApp {
    @MainActor
    private func logLaunchDiagnostics() async {
        do {
            let status = try await CKContainer(identifier: "iCloud.com.esoxjem.Luego").accountStatus()
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
        } catch {
            Logger.cloudKit.error("Launch diagnostics — failed to count articles: \(error.localizedDescription)")
        }

        do {
            let container = CKContainer(identifier: "iCloud.com.esoxjem.Luego")
            let subscriptions = try await container.privateCloudDatabase.allSubscriptions()
            Logger.cloudKit.info("Launch diagnostics — active subscriptions: \(subscriptions.count)")
            for subscription in subscriptions {
                Logger.cloudKit.debug("Launch diagnostics — subscription: \(subscription.subscriptionID), type: \(subscription.subscriptionType.rawValue)")
            }
        } catch {
            Logger.cloudKit.warning("Launch diagnostics — failed to fetch subscriptions: \(error.localizedDescription)")
        }
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
