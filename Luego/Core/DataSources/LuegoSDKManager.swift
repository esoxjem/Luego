import Foundation

protocol LuegoSDKManagerProtocol: Sendable {
    func ensureSDKReady() async
    func isSDKAvailable() -> Bool
    func loadBundles() -> [String: String]?
    func loadRules() -> Data?
    func getVersionInfo() -> SDKVersionInfo?
}

struct SDKVersionInfo: Sendable {
    let parserVersion: String
    let rulesVersion: String
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
        do {
            #if DEBUG
            print("[SDK] ─────────────────────────────────────────────")
            print("[SDK] Checking for updates...")
            #endif

            let remoteVersions = try await sdkDataSource.fetchVersions()
            let localVersions = cacheDataSource.loadVersions()

            #if DEBUG
            logVersionComparison(remote: remoteVersions, local: localVersions)
            #endif

            var downloadedBundles: [String] = []
            var skippedBundles: [String] = []

            for bundleName in AppConfiguration.sdkBundleNames {
                let remoteVersion = remoteVersions.bundles[bundleName]?.version
                let localVersion = localVersions?.bundles[bundleName]?.version
                let fileExists = cacheDataSource.bundleExists(name: bundleName)

                let versionMismatch = localVersion != remoteVersion
                let needsDownload = versionMismatch || !fileExists

                if needsDownload {
                    #if DEBUG
                    let reason = !fileExists ? "missing" : "outdated"
                    print("[SDK] ↓ Downloading \(bundleName) (\(reason))")
                    #endif

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

            #if DEBUG
            logReadySummary(
                remoteVersions: remoteVersions,
                downloadedBundles: downloadedBundles,
                skippedBundles: skippedBundles,
                rulesRefreshed: rulesRefreshed
            )
            #endif
        } catch {
            #if DEBUG
            print("[SDK] ✗ Update failed: \(error.localizedDescription)")
            print("[SDK] ─────────────────────────────────────────────")
            #endif
        }
    }

    private func refreshRulesIfNeeded(remoteVersion: String, localVersion: String?) async -> Bool {
        let versionMismatch = localVersion != remoteVersion
        let fileExists = cacheDataSource.rulesExist()

        guard versionMismatch || !fileExists else { return false }

        #if DEBUG
        let reason = !fileExists ? "missing" : "outdated"
        print("[SDK] ↓ Downloading rules (\(reason))")
        #endif

        do {
            let rules = try await sdkDataSource.fetchRules()
            cacheDataSource.saveRules(rules)
            return true
        } catch {
            #if DEBUG
            print("[SDK] ⚠ Rules refresh failed: \(error)")
            #endif
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
                #if DEBUG
                print("[SDK] ⚠ Failed to load bundle: \(name)")
                #endif
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

    #if DEBUG
    private func logVersionComparison(remote: SDKVersionsResponse, local: SDKVersionsResponse?) {
        let parserRemote = remote.bundles["parser"]?.version ?? "?"
        let rulesRemote = remote.rules.version

        if let local = local {
            let parserLocal = local.bundles["parser"]?.version ?? "?"
            let rulesLocal = local.rules.version

            let parserMatch = parserRemote == parserLocal
            let rulesMatch = rulesRemote == rulesLocal

            print("[SDK] Parser: \(parserLocal) → \(parserRemote) \(parserMatch ? "✓" : "↑")")
            print("[SDK] Rules:  \(rulesLocal) → \(rulesRemote) \(rulesMatch ? "✓" : "↑")")
        } else {
            print("[SDK] Parser: (none) → \(parserRemote) ↓")
            print("[SDK] Rules:  (none) → \(rulesRemote) ↓")
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
            print("[SDK] ✓ Ready (v\(parserVersion), rules: \(rulesVersion)) - all cached")
        } else {
            var updates: [String] = []
            if !downloadedBundles.isEmpty {
                updates.append("\(downloadedBundles.count) bundle(s)")
            }
            if rulesRefreshed {
                updates.append("rules")
            }
            print("[SDK] ✓ Ready (v\(parserVersion), rules: \(rulesVersion)) - updated: \(updates.joined(separator: ", "))")
        }
        print("[SDK] ─────────────────────────────────────────────")
    }
    #endif
}
