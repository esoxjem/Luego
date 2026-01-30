---
status: resolved
priority: p2
issue_id: "009"
tags: [code-review, concurrency, race-condition, swift]
dependencies: []
---

# Debounce Task Not Cancelled in All State Transitions

## Problem Statement

In `SyncStatusObserver`, the debounce task is only cancelled when a new success event arrives, not when transitioning to syncing or error states. This can lead to incorrect state transitions.

**Why it matters:** The sync status indicator could briefly show incorrect state, confusing users.

## Findings

### Evidence

**File:** `Luego/Core/DataSources/SyncStatusObserver.swift` (lines 67-85)
```swift
if event.endDate == nil {
    updateState(.syncing)  // debounceTask NOT cancelled
    Logger.cloudKit.debug("\(eventType) started")
} else if let error = event.error {
    // debounceTask NOT cancelled
    let (message, needsSignIn) = classifyError(error)
    updateState(.error(message: message, needsSignIn: needsSignIn))
} else {
    lastSyncTime = Date()
    updateState(.success)

    debounceTask?.cancel()  // Only cancelled here
    debounceTask = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        if state == .success { updateState(.idle) }
    }
}
```

### Scenario

1. Sync completes successfully, debounceTask starts sleeping (3 seconds)
2. New sync starts (state becomes `.syncing`)
3. Debounce task wakes up, may attempt state check
4. State confusion possible during rapid sync events

## Proposed Solutions

### Option A: Cancel in All Transitions (Recommended)

Cancel the debounce task when entering any new state.

```swift
if event.endDate == nil {
    debounceTask?.cancel()
    updateState(.syncing)
} else if let error = event.error {
    debounceTask?.cancel()
    updateState(.error(message: message, needsSignIn: needsSignIn))
} else {
    debounceTask?.cancel()
    lastSyncTime = Date()
    updateState(.success)
    debounceTask = Task { /* ... */ }
}
```

**Pros:**
- Clean state machine behavior
- No lingering tasks
- Simple fix

**Cons:**
- None

**Effort:** Trivial
**Risk:** None

## Recommended Action

Implement Option A - cancel debounce task in all state transitions.

## Technical Details

**Affected Files:**
- `Luego/Core/DataSources/SyncStatusObserver.swift`

## Acceptance Criteria

- [ ] Debounce task cancelled when entering syncing state
- [ ] Debounce task cancelled when entering error state
- [ ] No stale tasks running after state changes
- [ ] State transitions remain correct

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by performance-oracle and data-integrity agents |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
