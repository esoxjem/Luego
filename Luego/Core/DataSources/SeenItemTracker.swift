import Foundation

@MainActor
final class SeenItemTracker {
    private let storageKey: String
    private let resetThreshold: Double
    private var seenHashes: Set<UInt64> = []

    init(storageKey: String, resetThreshold: Double = 0.8) {
        self.storageKey = storageKey
        self.resetThreshold = resetThreshold
        loadSeenItems()
    }

    func filterUnseen<T>(_ items: [T], identifierFor: (T) -> String) -> [T] {
        items.filter { !seenHashes.contains(stableHash(identifierFor($0))) }
    }

    func markAsSeen(_ identifier: String) {
        seenHashes.insert(stableHash(identifier))
        saveSeenItems()
    }

    func resetIfNeeded(totalCount: Int, unseenCount: Int) -> Bool {
        let seenRatio = Double(totalCount - unseenCount) / Double(totalCount)
        guard seenRatio >= resetThreshold || unseenCount == 0 else { return false }
        seenHashes.removeAll()
        saveSeenItems()
        return true
    }

    func clear() {
        seenHashes.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    var seenCount: Int { seenHashes.count }

    private func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }

    private func loadSeenItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let hashes = try? JSONDecoder().decode(Set<UInt64>.self, from: data) else {
            return
        }
        seenHashes = hashes
    }

    private func saveSeenItems() {
        guard let data = try? JSONEncoder().encode(seenHashes) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
