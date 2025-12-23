import Testing
import Foundation
@testable import Luego

@Suite("SeenItemTracker Tests")
@MainActor
struct SeenItemTrackerTests {
    func createTracker(resetThreshold: Double = 0.8) -> SeenItemTracker {
        let uniqueKey = "test_seen_\(UUID().uuidString)"
        return SeenItemTracker(storageKey: uniqueKey, resetThreshold: resetThreshold)
    }

    @Test("filterUnseen returns all items when none seen")
    func filterUnseenReturnsAllWhenNoneSeen() {
        let tracker = createTracker()
        let items = ["a", "b", "c"]

        let unseen = tracker.filterUnseen(items) { $0 }

        #expect(unseen.count == 3)
        #expect(unseen.contains("a"))
        #expect(unseen.contains("b"))
        #expect(unseen.contains("c"))
    }

    @Test("filterUnseen excludes seen items")
    func filterUnseenExcludesSeen() {
        let tracker = createTracker()
        tracker.markAsSeen("b")
        let items = ["a", "b", "c"]

        let unseen = tracker.filterUnseen(items) { $0 }

        #expect(unseen.count == 2)
        #expect(unseen.contains("a"))
        #expect(!unseen.contains("b"))
        #expect(unseen.contains("c"))
    }

    @Test("filterUnseen works with custom identifier")
    func filterUnseenWithCustomIdentifier() {
        let tracker = createTracker()
        let items = [("id1", "name1"), ("id2", "name2"), ("id3", "name3")]
        tracker.markAsSeen("id2")

        let unseen = tracker.filterUnseen(items) { $0.0 }

        #expect(unseen.count == 2)
    }

    @Test("markAsSeen increases seenCount")
    func markAsSeenIncreasesCount() {
        let tracker = createTracker()

        #expect(tracker.seenCount == 0)

        tracker.markAsSeen("item1")
        #expect(tracker.seenCount == 1)

        tracker.markAsSeen("item2")
        #expect(tracker.seenCount == 2)
    }

    @Test("markAsSeen same item does not increase count")
    func markAsSeenSameItemNoDuplicate() {
        let tracker = createTracker()

        tracker.markAsSeen("item1")
        tracker.markAsSeen("item1")

        #expect(tracker.seenCount == 1)
    }

    @Test("resetIfNeeded resets when threshold reached")
    func resetIfNeededResetsAtThreshold() {
        let tracker = createTracker(resetThreshold: 0.8)
        for i in 0..<8 {
            tracker.markAsSeen("item\(i)")
        }

        let didReset = tracker.resetIfNeeded(totalCount: 10, unseenCount: 2)

        #expect(didReset == true)
        #expect(tracker.seenCount == 0)
    }

    @Test("resetIfNeeded does not reset below threshold")
    func resetIfNeededDoesNotResetBelowThreshold() {
        let tracker = createTracker(resetThreshold: 0.8)
        for i in 0..<5 {
            tracker.markAsSeen("item\(i)")
        }

        let didReset = tracker.resetIfNeeded(totalCount: 10, unseenCount: 5)

        #expect(didReset == false)
        #expect(tracker.seenCount == 5)
    }

    @Test("resetIfNeeded resets when no unseen items")
    func resetIfNeededResetsWhenNoUnseen() {
        let tracker = createTracker()
        tracker.markAsSeen("item1")
        tracker.markAsSeen("item2")

        let didReset = tracker.resetIfNeeded(totalCount: 2, unseenCount: 0)

        #expect(didReset == true)
        #expect(tracker.seenCount == 0)
    }

    @Test("clear removes all seen items")
    func clearRemovesAll() {
        let tracker = createTracker()
        tracker.markAsSeen("a")
        tracker.markAsSeen("b")

        tracker.clear()

        #expect(tracker.seenCount == 0)
    }

    @Test("clear allows items to be unseen again")
    func clearAllowsItemsToBeUnseenAgain() {
        let tracker = createTracker()
        tracker.markAsSeen("item1")
        let items = ["item1", "item2"]

        tracker.clear()
        let unseen = tracker.filterUnseen(items) { $0 }

        #expect(unseen.count == 2)
    }

    @Test("stableHash produces consistent results")
    func stableHashConsistent() {
        let tracker = createTracker()
        tracker.markAsSeen("test_identifier")
        let items = ["test_identifier", "other"]

        let unseen = tracker.filterUnseen(items) { $0 }

        #expect(unseen.count == 1)
        #expect(unseen[0] == "other")
    }
}
