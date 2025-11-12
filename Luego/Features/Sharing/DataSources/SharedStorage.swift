import Foundation
import os

struct SharedURL: Codable {
    let url: URL
    let timestamp: Date
}

final class SharedStorage {
    static let shared = SharedStorage()

    private let appGroupIdentifier = "group.com.esoxjem.Luego"
    private let sharedURLsKey = "sharedURLs"
    private let logger = Logger(subsystem: "com.esoxjem.Luego", category: "SharedStorage")

    private init() {}

    func saveSharedURL(_ url: URL) {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            logger.error("Failed to access shared UserDefaults with app group: \(self.appGroupIdentifier)")
            return
        }

        var sharedURLs = getSharedURLs()
        let sharedURL = SharedURL(url: url, timestamp: Date())
        sharedURLs.append(sharedURL)

        if let encoded = try? JSONEncoder().encode(sharedURLs) {
            userDefaults.set(encoded, forKey: sharedURLsKey)
            userDefaults.synchronize()
        }
    }

    func getSharedURLs() -> [SharedURL] {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = userDefaults.data(forKey: sharedURLsKey),
              let sharedURLs = try? JSONDecoder().decode([SharedURL].self, from: data) else {
            return []
        }
        return sharedURLs
    }

    func clearSharedURLs() {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        userDefaults.removeObject(forKey: sharedURLsKey)
        userDefaults.synchronize()
    }
}
