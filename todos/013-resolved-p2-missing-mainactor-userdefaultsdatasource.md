---
status: resolved
priority: p2
issue_id: "013"
tags: [code-review, concurrency, swift6, architecture]
dependencies: []
---

# Missing @MainActor on UserDefaultsDataSource

## Problem Statement

`UserDefaultsDataSource` calls methods on `SharedStorageDataSourceProtocol` which is `@MainActor` isolated, but `UserDefaultsDataSource` itself lacks explicit `@MainActor` annotation.

**Why it matters:** Creates implicit coupling to MainActor context. If the build setting `SWIFT_DEFAULT_ACTOR_ISOLATION` were changed or the class moved to a module with different settings, this would break.

## Findings

### Evidence

**File:** `Luego/Features/Sharing/DataSources/UserDefaultsDataSource.swift:8-22`
```swift
final class UserDefaultsDataSource: UserDefaultsDataSourceProtocol {
    private let sharedStorage: SharedStorageDataSourceProtocol  // @MainActor protocol

    func getSharedURLs() -> [URL] {
        sharedStorage.getSharedURLs().map { $0.url }  // Calls @MainActor method
    }

    func clearSharedURLs() {
        sharedStorage.clearSharedURLs()  // Calls @MainActor method
    }
}
```

### Pattern Inconsistency

Other DataSources in the codebase have explicit `@MainActor`:
- `ContentDataSource` - explicit `@MainActor`
- `SharedStorage` - explicit `@MainActor`
- `ParsedContentCacheDataSource` - explicit `@MainActor`
- `LuegoParserDataSource` - explicit `@MainActor`
- `UserDefaultsDataSource` - **MISSING**

## Proposed Solutions

### Option A: Add @MainActor (Recommended)

Add explicit `@MainActor` to `UserDefaultsDataSource`.

```swift
@MainActor
final class UserDefaultsDataSource: UserDefaultsDataSourceProtocol {
    // ...
}
```

**Pros:**
- Explicit isolation makes code self-documenting
- Consistent with codebase patterns
- Resilient to build setting changes

**Cons:**
- Slightly more verbose

**Effort:** Small (1 line change)
**Risk:** None

## Recommended Action

Apply Option A to maintain consistency with established patterns.

## Technical Details

**Affected Files:**
- `Luego/Features/Sharing/DataSources/UserDefaultsDataSource.swift`

**Components:** UserDefaultsDataSource, SharingService

## Acceptance Criteria

- [x] `UserDefaultsDataSource` has `@MainActor` annotation
- [x] Code compiles with `SWIFT_STRICT_CONCURRENCY = complete`
- [ ] All tests pass

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-31 | Created during PR #42 review | Found by architecture-strategist and code-reviewer agents |
| 2026-01-31 | Added @MainActor annotation to UserDefaultsDataSource class | Build verified successfully |

## Resources

- PR #42: https://github.com/esoxjem/Luego/pull/42
- [Swift Concurrency Migration Guide](https://www.swift.org/migration/documentation/migrationguide/)
