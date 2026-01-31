---
status: resolved
priority: p2
issue_id: "014"
tags: [code-review, concurrency, swift6, architecture]
dependencies: []
---

# Inconsistent @MainActor Annotations on Protocols

## Problem Statement

Some protocols have `@MainActor` annotation while others with `@MainActor` implementations do not. This creates semantic inconsistency where the protocol promises thread-safe access from any context, but implementations require MainActor isolation.

**Why it matters:** Code consuming these protocols could attempt to call methods from non-MainActor contexts. Currently this is prevented by the `@MainActor` DIContainer, but it's fragile if the architecture changes.

## Findings

### Protocols WITH @MainActor

```swift
// SharedStorage.swift:8-9
@MainActor
protocol SharedStorageDataSourceProtocol: Sendable { ... }

// SyncStatusObserver.swift:18-19
@MainActor
protocol SyncStatusObservable: AnyObject { ... }
```

### Protocols WITHOUT @MainActor (but implementations are @MainActor)

```swift
// ArticleService.swift:4
protocol ArticleServiceProtocol: Sendable { ... }
// Implementation: @MainActor final class ArticleService

// DiscoveryService.swift:14
protocol DiscoveryServiceProtocol: Sendable { ... }
// Implementation: @MainActor final class DiscoveryService

// ReaderService.swift:4
protocol ReaderServiceProtocol: Sendable { ... }
// Implementation: @MainActor final class ReaderService

// MetadataDataSource.swift:3
protocol MetadataDataSourceProtocol: Sendable { ... }
// Implementations: ContentDataSource, MetadataDataSource - both @MainActor
```

## Proposed Solutions

### Option A: Add @MainActor to All Service Protocols

Add `@MainActor` to protocols where all implementations are `@MainActor`.

**Pros:**
- Protocol semantics match implementation reality
- Explicit about MainActor requirement at API boundary
- Compile-time enforcement of correct actor context

**Cons:**
- Makes protocols less flexible for hypothetical future implementations
- More verbose

**Effort:** Medium (touch multiple protocol files)
**Risk:** Low

### Option B: Keep Current Pattern (Leave as Implicit)

Rely on `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` to handle isolation.

**Pros:**
- Less code to change
- Works with current build settings

**Cons:**
- Fragile if build settings change
- Protocol semantics are misleading

**Effort:** None
**Risk:** Medium (future breakage)

## Recommended Action

Choose one approach consistently. Option A is preferred for explicitness.

## Technical Details

**Affected Files:**
- `Luego/Features/ReadingList/Services/ArticleService.swift`
- `Luego/Features/Discovery/Services/DiscoveryService.swift`
- `Luego/Features/Reader/Services/ReaderService.swift`
- `Luego/Core/DataSources/MetadataDataSource.swift`

**Components:** All service protocols

## Acceptance Criteria

- [x] All service protocols either have or don't have `@MainActor` consistently
- [ ] Document the chosen isolation strategy in ARCHITECTURE.md
- [x] All tests pass

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-31 | Created during PR #42 review | Found by pattern-recognition-specialist and architecture-strategist agents |
| 2026-01-31 | Resolved: Added @MainActor to ArticleServiceProtocol, DiscoveryServiceProtocol, ReaderServiceProtocol, and MetadataDataSourceProtocol | Option A implemented for explicit MainActor isolation at protocol level |

## Resources

- PR #42: https://github.com/esoxjem/Luego/pull/42
