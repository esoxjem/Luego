---
status: resolved
priority: p2
issue_id: "010"
tags: [code-review, testing, sync, coverage]
dependencies: []
---

# Missing Tests for SyncStatusObserver

## Problem Statement

`SyncStatusObserver` (130 lines) contains non-trivial logic including state machine transitions, debouncing, error classification, and accessibility announcements, but has no test coverage.

**Why it matters:** Critical sync status functionality is untested. Regressions could go unnoticed.

## Findings

### Evidence

**File:** `Luego/Core/DataSources/SyncStatusObserver.swift`

Components lacking tests:
- State machine: idle → syncing → success → idle
- Error classification: notAuthenticated vs other errors
- Debounce behavior: 3-second delay before returning to idle
- Accessibility announcements for state changes

**Search Result:**
```bash
grep -r "SyncStatusObserver" LuegoTests/
# No results
```

### Testable Behaviors

1. Initial state is `.idle`
2. Receiving start event transitions to `.syncing`
3. Receiving end event without error transitions to `.success`
4. Success state transitions to `.idle` after 3 seconds
5. Receiving error event transitions to `.error`
6. `notAuthenticated` error sets `needsSignIn = true`
7. `dismissError()` returns to `.idle`

## Proposed Solutions

### Option A: Add Unit Tests (Recommended)

Create test file for SyncStatusObserver.

```swift
// LuegoTests/Core/DataSources/SyncStatusObserverTests.swift
@Suite struct SyncStatusObserverTests {
    @Test @MainActor
    func initialStateIsIdle() async {
        let observer = SyncStatusObserver()
        #expect(observer.state == .idle)
    }

    @Test @MainActor
    func dismissErrorResetsToIdle() async {
        // Setup error state
        // Call dismissError()
        // Verify idle
    }

    // ... more tests
}
```

**Pros:**
- Catches regressions
- Documents expected behavior
- Enables confident refactoring

**Cons:**
- Testing NotificationCenter-based code requires mocking

**Effort:** Medium
**Risk:** Low

## Recommended Action

Implement Option A - add comprehensive test coverage for SyncStatusObserver.

## Technical Details

**New Files:**
- `LuegoTests/Core/DataSources/SyncStatusObserverTests.swift`

**Components to Mock:**
- `NSPersistentCloudKitContainer.eventChangedNotification`

## Acceptance Criteria

- [ ] Test file created with all testable behaviors covered
- [ ] State machine transitions tested
- [ ] Error classification tested
- [ ] Debounce behavior tested
- [ ] Tests pass

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by git-history-analyzer agent |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
- Swift Testing Framework documentation
