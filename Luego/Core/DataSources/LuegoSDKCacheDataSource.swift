import Foundation

protocol LuegoSDKCacheDataSourceProtocol: Sendable {
    func loadBundle(name: String) -> Data?
    func saveBundle(name: String, data: Data)
    func loadRules() -> Data?
    func saveRules(_ data: Data)
    func loadVersions() -> SDKVersionsResponse?
    func saveVersions(_ versions: SDKVersionsResponse)
    func bundleExists(name: String) -> Bool
    func rulesExist() -> Bool
    func allBundlesExist() -> Bool
    func clearAll()
}

@MainActor
final class LuegoSDKCacheDataSource: LuegoSDKCacheDataSourceProtocol {
    private let fileManager = FileManager.default

    private var sdkDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return fileManager.temporaryDirectory.appendingPathComponent("LuegoSDK")
        }
        return appSupport.appendingPathComponent("LuegoSDK")
    }

    private var bundlesDirectory: URL {
        sdkDirectory.appendingPathComponent("bundles")
    }

    private var rulesFileURL: URL {
        sdkDirectory.appendingPathComponent("rules.json")
    }

    private var versionsFileURL: URL {
        sdkDirectory.appendingPathComponent("versions.json")
    }

    init() {
        ensureDirectoriesExist()
    }

    private func ensureDirectoriesExist() {
        do {
            try fileManager.createDirectory(at: bundlesDirectory, withIntermediateDirectories: true)
        } catch {
            Logger.cache.error("⚠ Failed to create directories: \(error)")
        }
    }

    func loadBundle(name: String) -> Data? {
        let fileURL = bundlesDirectory.appendingPathComponent("\(name).js")
        return try? Data(contentsOf: fileURL)
    }

    func saveBundle(name: String, data: Data) {
        let fileURL = bundlesDirectory.appendingPathComponent("\(name).js")
        do {
            try data.write(to: fileURL)
        } catch {
            Logger.cache.error("⚠ Failed to save bundle '\(name)': \(error)")
        }
    }

    func loadRules() -> Data? {
        try? Data(contentsOf: rulesFileURL)
    }

    func saveRules(_ data: Data) {
        do {
            try data.write(to: rulesFileURL)
        } catch {
            Logger.cache.error("⚠ Failed to save rules: \(error)")
        }
    }

    func loadVersions() -> SDKVersionsResponse? {
        guard let data = try? Data(contentsOf: versionsFileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(SDKVersionsResponse.self, from: data)
    }

    func saveVersions(_ versions: SDKVersionsResponse) {
        do {
            let data = try JSONEncoder().encode(versions)
            try data.write(to: versionsFileURL)
        } catch {
            Logger.cache.error("⚠ Failed to save versions: \(error)")
        }
    }

    func bundleExists(name: String) -> Bool {
        let fileURL = bundlesDirectory.appendingPathComponent("\(name).js")
        return fileManager.fileExists(atPath: fileURL.path)
    }

    func rulesExist() -> Bool {
        fileManager.fileExists(atPath: rulesFileURL.path)
    }

    func allBundlesExist() -> Bool {
        AppConfiguration.sdkBundleNames.allSatisfy { bundleExists(name: $0) }
    }

    func clearAll() {
        try? fileManager.removeItem(at: sdkDirectory)
        ensureDirectoriesExist()

        Logger.cache.info("Cache cleared")
    }
}
