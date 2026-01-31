import Foundation

struct SharedURL: Codable, Sendable {
    let url: URL
    let timestamp: Date
}

@MainActor
protocol SharedStorageDataSourceProtocol: Sendable {
    func saveSharedURL(_ url: URL)
    func getSharedURLs() -> [SharedURL]
    func getSharedURLs(after timestamp: Date) -> [SharedURL]
    func clearSharedURLs()
    func getLastSyncTimestamp() -> Date?
    func setLastSyncTimestamp(_ timestamp: Date)
}

@MainActor
final class SharedStorage: SharedStorageDataSourceProtocol {
    static let shared = SharedStorage()

    #if os(iOS)
    private let appGroupIdentifier = "group.com.esoxjem.Luego"
    private let sharedURLsKey = "sharedURLs"
    private let lastSyncTimestampKey = "lastSyncTimestamp"
    #endif

    private init() {}

    func saveSharedURL(_ url: URL) {
        #if os(iOS)
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        var sharedURLs = getSharedURLs()
        let sharedURL = SharedURL(url: url, timestamp: Date())
        sharedURLs.append(sharedURL)

        if let encoded = try? JSONEncoder().encode(sharedURLs) {
            userDefaults.set(encoded, forKey: sharedURLsKey)
        }
        #endif
    }

    func getSharedURLs() -> [SharedURL] {
        #if os(iOS)
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = userDefaults.data(forKey: sharedURLsKey),
              let sharedURLs = try? JSONDecoder().decode([SharedURL].self, from: data) else {
            return []
        }
        return sharedURLs
        #else
        return []
        #endif
    }

    func getSharedURLs(after timestamp: Date) -> [SharedURL] {
        getSharedURLs().filter { $0.timestamp > timestamp }
    }

    func clearSharedURLs() {
        #if os(iOS)
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        userDefaults.removeObject(forKey: sharedURLsKey)
        #endif
    }

    func getLastSyncTimestamp() -> Date? {
        #if os(iOS)
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return nil
        }
        return userDefaults.object(forKey: lastSyncTimestampKey) as? Date
        #else
        return nil
        #endif
    }

    func setLastSyncTimestamp(_ timestamp: Date) {
        #if os(iOS)
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        userDefaults.set(timestamp, forKey: lastSyncTimestampKey)
        #endif
    }
}
