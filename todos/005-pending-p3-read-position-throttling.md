---
status: completed
priority: p3
issue_id: "005"
tags: [code-review, performance, icloud-sync]
dependencies: []
resolved_date: 2026-01-29
resolution: Implemented Option A (2s debounce) + conditional saves (>1% change threshold)
---

# Consider Increasing Read Position Save Throttling

## Problem Statement

Read position updates during article reading may generate excessive CloudKit transactions. While there is a 1-second debounce in the View layer, each save still creates a CloudKit export transaction.

During a 10-minute reading session, a user might trigger 20-30 read position saves, each becoming a CloudKit sync operation.

## Findings

**File:** `Luego/Features/Reader/Views/ReaderView.swift` (lines 227-237)

```swift
private func updateReadPosition() {
    saveTask?.cancel()

    saveTask = Task {
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second debounce
        guard !Task.isCancelled else { return }

        let position = calculateReadPosition()
        await viewModel.updateReadPosition(position)
    }
}
```

**File:** `Luego/Features/Reader/Services/ReaderService.swift` (lines 49-50)

```swift
article.readPosition = position
try modelContext.save()  // Each save = CloudKit transaction
```

**Impact:**
- Battery drain from frequent sync attempts
- Network traffic for each position update
- Potential conflicts if reading on two devices

## Proposed Solutions

### Option A: Increase Debounce Time
**Effort:** Small | **Risk:** Low

Change debounce from 1 second to 5-10 seconds:

```swift
try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
```

**Pros:**
- Simple one-line change
- 80% reduction in sync transactions

**Cons:**
- Position slightly less up-to-date if app crashes

### Option B: Save Only on Significant Changes
**Effort:** Small | **Risk:** Low

Only save when position changes by >10%:

```swift
let threshold = 0.1
if abs(newPosition - article.readPosition) > threshold {
    await viewModel.updateReadPosition(newPosition)
}
```

**Pros:**
- Reduces unnecessary saves
- Position still reasonably accurate

**Cons:**
- Small position changes not saved

### Option C: Save Only on View Disappear (Already Implemented)
**Effort:** None | **Risk:** Low

The code already saves on `handleDisappear()`. Could remove continuous saving entirely and rely only on this.

**Pros:**
- Minimal sync transactions
- Already implemented

**Cons:**
- Position lost if app crashes during reading

### Option D: No Change (Monitor)
**Effort:** None | **Risk:** Low

The plan document claims SwiftData batches writes automatically. While this is partially misleading (batching is on the wire, not at the application level), CloudKit is designed to handle frequent updates.

**Pros:**
- No code change
- May not be a real problem

**Cons:**
- Unknown battery/network impact

## Recommended Action

Start with **Option D** - monitor battery and network usage in real-world testing. If issues emerge, implement **Option A** (increase debounce to 5 seconds).

## Technical Details

**Affected Files:**
- `Luego/Features/Reader/Views/ReaderView.swift`

**Measurement:**
- Track CloudKit transactions during reading sessions
- Monitor battery usage with and without sync

## Acceptance Criteria

- [ ] Measure sync transaction frequency during 10-minute reading session
- [ ] Compare battery usage with/without CloudKit enabled
- [ ] If excessive, increase debounce time

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-29 | Created from code review | SwiftData batching is at wire level, not app level; each save() creates transaction |

## Resources

- PR Branch: `icloud-sync`
- [NSPersistentCloudKitContainer synchronization](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer)
