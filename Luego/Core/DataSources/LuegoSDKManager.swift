import Foundation

protocol LuegoSDKManagerProtocol: Sendable {
    func ensureSDKReady() async
    func checkForUpdates() async -> SDKUpdateResult
    func isSDKAvailable() -> Bool
    func loadBundles() -> [String: String]?
    func loadRules() -> Data?
    func getVersionInfo() -> SDKVersionInfo?
}

struct SDKVersionInfo: Sendable {
    let parserVersion: String
    let rulesVersion: String
}

enum SDKUpdateResult: Sendable {
    case updated(parserVersion: String, rulesVersion: String, bundlesUpdated: Int, rulesUpdated: Bool)
    case alreadyUpToDate(parserVersion: String, rulesVersion: String)
    case failed(Error)
}

@MainActor
final class LuegoSDKManager: LuegoSDKManagerProtocol {
    private let sdkDataSource: LuegoSDKDataSourceProtocol
    private let cacheDataSource: LuegoSDKCacheDataSourceProtocol

    init(
        sdkDataSource: LuegoSDKDataSourceProtocol,
        cacheDataSource: LuegoSDKCacheDataSourceProtocol
    ) {
        self.sdkDataSource = sdkDataSource
        self.cacheDataSource = cacheDataSource
    }

    func ensureSDKReady() async {
        _ = await checkForUpdates()
    }

    func checkForUpdates() async -> SDKUpdateResult {
        do {
            Logger.sdk.debugPublic("─────────────────────────────────────────────")
            Logger.sdk.debugPublic("Checking for updates...")

            let remoteVersions = try await sdkDataSource.fetchVersions()
            let localVersions = cacheDataSource.loadVersions()

            logVersionComparison(remote: remoteVersions, local: localVersions)

            var downloadedBundles: [String] = []
            var skippedBundles: [String] = []

            for bundleName in AppConfiguration.sdkBundleNames {
                let remoteVersion = remoteVersions.bundles[bundleName]?.version
                let localVersion = localVersions?.bundles[bundleName]?.version
                let fileExists = cacheDataSource.bundleExists(name: bundleName)

                let versionMismatch = localVersion != remoteVersion
                let needsDownload = versionMismatch || !fileExists

                if needsDownload {
                    let reason = !fileExists ? "missing" : "outdated"
                    Logger.sdk.debugPublic("↓ Downloading \(bundleName) (\(reason))")

                    let data = try await sdkDataSource.downloadBundle(name: bundleName)
                    cacheDataSource.saveBundle(name: bundleName, data: data)
                    downloadedBundles.append(bundleName)
                } else {
                    skippedBundles.append(bundleName)
                }
            }

            let rulesRefreshed = await refreshRulesIfNeeded(
                remoteVersion: remoteVersions.rules.version,
                localVersion: localVersions?.rules.version
            )
            cacheDataSource.saveVersions(remoteVersions)

            logReadySummary(
                remoteVersions: remoteVersions,
                downloadedBundles: downloadedBundles,
                skippedBundles: skippedBundles,
                rulesRefreshed: rulesRefreshed
            )

            let parserVersion = remoteVersions.bundles["parser"]?.version ?? "?"
            let rulesVersion = remoteVersions.rules.version

            if downloadedBundles.isEmpty && !rulesRefreshed {
                return .alreadyUpToDate(parserVersion: parserVersion, rulesVersion: rulesVersion)
            } else {
                return .updated(
                    parserVersion: parserVersion,
                    rulesVersion: rulesVersion,
                    bundlesUpdated: downloadedBundles.count,
                    rulesUpdated: rulesRefreshed
                )
            }
        } catch {
            Logger.sdk.errorPublic("✗ Update failed: \(error.localizedDescription)")
            Logger.sdk.debugPublic("─────────────────────────────────────────────")
            return .failed(error)
        }
    }

    private func refreshRulesIfNeeded(remoteVersion: String, localVersion: String?) async -> Bool {
        let versionMismatch = localVersion != remoteVersion
        let fileExists = cacheDataSource.rulesExist()

        guard versionMismatch || !fileExists else { return false }

        let reason = !fileExists ? "missing" : "outdated"
        Logger.sdk.debugPublic("↓ Downloading rules (\(reason))")

        do {
            let rules = try await sdkDataSource.fetchRules()
            cacheDataSource.saveRules(rules)
            return true
        } catch {
            Logger.sdk.warningPublic("⚠ Rules refresh failed: \(error)")
            return false
        }
    }

    func isSDKAvailable() -> Bool {
        cacheDataSource.allBundlesExist()
    }

    func loadBundles() -> [String: String]? {
        guard isSDKAvailable() else { return nil }

        var bundles: [String: String] = [:]
        for name in AppConfiguration.sdkBundleNames {
            guard let data = cacheDataSource.loadBundle(name: name),
                  let script = String(data: data, encoding: .utf8) else {
                Logger.sdk.warningPublic("⚠ Failed to load bundle: \(name)")
                return nil
            }
            bundles[name] = script
        }
        return bundles
    }

    func loadRules() -> Data? {
        cacheDataSource.loadRules()
    }

    func getVersionInfo() -> SDKVersionInfo? {
        guard let versions = cacheDataSource.loadVersions(),
              let parserInfo = versions.bundles["parser"] else {
            return nil
        }

        return SDKVersionInfo(
            parserVersion: parserInfo.version,
            rulesVersion: versions.rules.version
        )
    }

    private func logVersionComparison(remote: SDKVersionsResponse, local: SDKVersionsResponse?) {
        let parserRemote = remote.bundles["parser"]?.version ?? "?"
        let rulesRemote = remote.rules.version

        if let local = local {
            let parserLocal = local.bundles["parser"]?.version ?? "?"
            let rulesLocal = local.rules.version

            let parserMatch = parserRemote == parserLocal
            let rulesMatch = rulesRemote == rulesLocal

            Logger.sdk.debugPublic("Parser: \(parserLocal) → \(parserRemote) \(parserMatch ? "✓" : "↑")")
            Logger.sdk.debugPublic("Rules:  \(rulesLocal) → \(rulesRemote) \(rulesMatch ? "✓" : "↑")")
        } else {
            Logger.sdk.debugPublic("Parser: (none) → \(parserRemote) ↓")
            Logger.sdk.debugPublic("Rules:  (none) → \(rulesRemote) ↓")
        }
    }

    private func logReadySummary(
        remoteVersions: SDKVersionsResponse,
        downloadedBundles: [String],
        skippedBundles: [String],
        rulesRefreshed: Bool
    ) {
        let parserVersion = remoteVersions.bundles["parser"]?.version ?? "?"
        let rulesVersion = remoteVersions.rules.version

        if downloadedBundles.isEmpty && !rulesRefreshed {
            Logger.sdk.debugPublic("✓ Ready (v\(parserVersion), rules: \(rulesVersion)) - all cached")
        } else {
            var updates: [String] = []
            if !downloadedBundles.isEmpty {
                updates.append("\(downloadedBundles.count) bundle(s)")
            }
            if rulesRefreshed {
                updates.append("rules")
            }
            Logger.sdk.debugPublic("✓ Ready (v\(parserVersion), rules: \(rulesVersion)) - updated: \(updates.joined(separator: ", "))")
        }
        Logger.sdk.debugPublic("─────────────────────────────────────────────")
    }
}
