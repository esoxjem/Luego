import Foundation
import CryptoKit

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
    let generatedAt: String
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
                let remoteChecksum = remoteVersions.bundles[bundleName]?.checksum
                let localChecksum = localVersions?.bundles[bundleName]?.checksum
                let fileExists = cacheDataSource.bundleExists(name: bundleName)

                let checksumMismatch = localChecksum != remoteChecksum
                let needsDownload = checksumMismatch || !fileExists

                if needsDownload {
                    #if DEBUG
                    let reason = !fileExists ? "missing" : "outdated"
                    print("[SDK] ↓ Downloading \(bundleName) (\(reason))")
                    #endif

                    let data = try await sdkDataSource.downloadBundle(name: bundleName)

                    guard let expectedChecksum = remoteChecksum else {
                        #if DEBUG
                        print("[SDK] ⚠ No checksum for bundle: \(bundleName), saving without validation")
                        #endif
                        cacheDataSource.saveBundle(name: bundleName, data: data)
                        downloadedBundles.append(bundleName)
                        continue
                    }

                    guard validateChecksum(data: data, expected: expectedChecksum) else {
                        throw LuegoSDKError.checksumMismatch(bundleName: bundleName)
                    }

                    cacheDataSource.saveBundle(name: bundleName, data: data)
                    downloadedBundles.append(bundleName)
                } else {
                    skippedBundles.append(bundleName)
                }
            }

            let rulesRefreshed = await refreshRulesIfNeeded()
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

    private func refreshRulesIfNeeded() async -> Bool {
        guard shouldRefreshRules() else { return false }

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

    private func shouldRefreshRules() -> Bool {
        guard let lastRefresh = cacheDataSource.getRulesTimestamp() else {
            return true
        }
        return Date().timeIntervalSince(lastRefresh) > AppConfiguration.sdkRulesRefreshInterval
    }

    private func validateChecksum(data: Data, expected: String) -> Bool {
        let hash = SHA256.hash(data: data)
        let fullHash = hash.compactMap { String(format: "%02x", $0) }.joined()

        let isValid = fullHash == expected || fullHash.hasPrefix(expected)

        #if DEBUG
        if !isValid {
            print("[SDK] ⚠ Checksum mismatch: expected \(expected), got \(fullHash)")
        }
        #endif

        return isValid
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
            rulesVersion: versions.rules.version,
            generatedAt: versions.generatedAt
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
