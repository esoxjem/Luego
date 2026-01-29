---
title: Optimize Read Position Sync Throttling
type: fix
date: 2026-01-29
priority: p3
---

# Optimize Read Position Sync Throttling

## Overview

Improve read position sync efficiency by increasing debounce from 1 second to 2 seconds and adding conditional saves to reduce unnecessary CloudKit transactions.

## Problem Statement

During article reading, the current 1-second debounce triggers a save every time scrolling pauses for >1 second. While CloudKit batches at the wire level, each `modelContext.save()` still:
- Writes to SQLite
- Creates a persistent history transaction
- Queues an export operation

A 10-minute reading session generates ~20-30 saves. This isn't critical (CloudKit handles it), but can be reduced with minimal effort.

## Research Findings

| Question | Answer |
|----------|--------|
| Does CloudKit batch automatically? | Yes, at wire level - save() queues locally, system batches exports |
| Is 1-second debounce causing problems? | No, but community consensus suggests 2 seconds is safer |
| Should we worry about throttling? | No, NSPersistentCloudKitContainer handles retries automatically |

**Apple's behavior**: Changes queue in SQLite (`ANSCKEXPORT...` tables), system opportunistically uploads based on network/battery/device state. QoS is `.utility` (won't compete with UI).

**Community consensus**: 2-second minimum between operations with conditional saves.

## Proposed Solution

Two small changes to `ReaderView.swift`:

### Change 1: Increase Debounce to 2 Seconds

```swift
// Before
try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

// After
try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
```

### Change 2: Add Conditional Save (>1% Change)

```swift
private func updateReadPosition() {
    let newPosition = calculateReadPosition()

    // Only save if position changed by more than 1%
    guard abs(newPosition - lastSavedPosition) > 0.01 else { return }

    saveTask?.cancel()
    saveTask = Task {
        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
        guard !Task.isCancelled else { return }

        await viewModel.updateReadPosition(newPosition)
        lastSavedPosition = newPosition
    }
}
```

## Technical Considerations

- **Minimal change**: Two modifications to one file
- **No architectural impact**: Same data flow, just better filtering
- **Backwards compatible**: Position still syncs, just less frequently
- **Risk**: None - position saved on view disappear regardless

## Acceptance Criteria

- [x] Debounce increased from 1s to 2s in `ReaderView.swift`
- [x] Conditional save added (>1% position change threshold)
- [x] Track `lastSavedPosition` state variable added
- [x] Existing `handleDisappear()` save behavior unchanged
- [ ] Manual test: read article, verify position syncs correctly

## Files to Modify

| File | Change |
|------|--------|
| `Luego/Features/Reader/Views/ReaderView.swift` | Update `updateReadPosition()` method |

## Implementation

```swift
// Luego/Features/Reader/Views/ReaderView.swift

// Add state variable (near other @State properties)
@State private var lastSavedPosition: Double = 0

// Update the method
private func updateReadPosition() {
    let newPosition = calculateReadPosition()

    // Only save if position changed significantly (>1%)
    guard abs(newPosition - lastSavedPosition) > 0.01 else { return }

    saveTask?.cancel()
    saveTask = Task {
        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds (was 1s)
        guard !Task.isCancelled else { return }

        await viewModel.updateReadPosition(newPosition)
        lastSavedPosition = newPosition
    }
}

// In handleAppear(), initialize lastSavedPosition
private func handleAppear() {
    // ... existing code ...
    lastSavedPosition = article.readPosition
}
```

## Expected Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Saves per 10-min session | ~20-30 | ~8-12 | ~60% reduction |
| Position accuracy | High | High | Unchanged |
| Sync reliability | High | High | Unchanged |

## References

- Original todo: `todos/005-pending-p3-read-position-throttling.md`
- Apple TN3163: [Understanding NSPersistentCloudKitContainer synchronization](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer)
- Community guidance: 2-second minimum between CloudKit operations
