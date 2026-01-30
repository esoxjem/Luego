---
status: resolved
priority: p2
issue_id: "004"
tags: [code-review, architecture, dependency-injection, testing]
dependencies: []
---

# SyncStatusObserver Bypasses DIContainer Pattern

## Problem Statement

`SyncStatusObserver` is created directly as `@State` in `LuegoApp` and passed via `.environment()`, bypassing the established `DIContainer` pattern used by all other services. This creates inconsistency and reduces testability.

**Why it matters:** Violates the established DI pattern, makes testing harder, and creates architectural inconsistency.

## Findings

### Evidence

**File:** `Luego/App/LuegoApp.swift` (lines 13, 41)
```swift
@State private var syncStatusObserver = SyncStatusObserver()
// ...
.environment(syncStatusObserver)
```

**Contrast with established pattern:**
All other services (ArticleService, ReaderService, DiscoveryService) are managed through DIContainer with lazy initialization and factory methods.

### Impact

- Cannot easily mock `SyncStatusObserver` in tests
- Violates Single Responsibility Principle for `LuegoApp`
- Makes future refactoring harder if sync status needs to be shared with other services
- Inconsistent with documented architecture in ARCHITECTURE.md

## Proposed Solutions

### Option A: Add to DIContainer (Recommended)

Move `SyncStatusObserver` to DIContainer with lazy initialization.

```swift
// In DIContainer.swift
private lazy var syncStatusObserver: SyncStatusObserver = {
    SyncStatusObserver()
}()

var syncObserver: SyncStatusObserver { syncStatusObserver }
```

**Pros:**
- Consistent with existing pattern
- Enables mocking for tests
- Proper lifecycle management

**Cons:**
- Minor refactoring required

**Effort:** Small
**Risk:** Low

### Option B: Create Protocol and Mock Support

Keep current structure but add protocol for testability.

**Pros:**
- Minimal code changes
- Enables mocking

**Cons:**
- Still violates DI pattern
- Inconsistent with codebase

**Effort:** Small
**Risk:** Low

## Recommended Action

Implement Option A - integrate SyncStatusObserver into DIContainer following the established pattern.

## Technical Details

**Affected Files:**
- `Luego/Core/DI/DIContainer.swift`
- `Luego/App/LuegoApp.swift`

**Components:** DIContainer, LuegoApp

## Acceptance Criteria

- [ ] SyncStatusObserver is created and managed by DIContainer
- [ ] LuegoApp retrieves observer from DIContainer
- [ ] Observer can be mocked in tests
- [ ] Existing functionality unchanged

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by architecture-strategist agent |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
- ARCHITECTURE.md: Dependency Flow documentation
