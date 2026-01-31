---
title: Migrate to Swift 6 Structured Concurrency
type: feat
date: 2026-01-31
status: partial-complete
---

# Migrate to Swift 6 Structured Concurrency

## Outcome Summary

**Phase 1: ✅ Complete** - Strict concurrency checking enabled for all targets
**Phase 2: ⚠️ Blocked** - Swift 6 language mode incompatible with SwiftData `@Model` macro + MainActor default isolation

### What Was Achieved
- `SWIFT_STRICT_CONCURRENCY = complete` for Luego, LuegoTests, LuegoShareExtension
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` for LuegoShareExtension
- Fixed all concurrency issues in ContentDataSource, SharedStorage, ShareViewController
- All 50+ tests pass

### Why Swift 6 Mode Was Not Enabled
SwiftData's `@Model` macro generates protocol conformances (Hashable, Equatable, PersistentModel) that cross actor isolation boundaries. With `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, these conformances trigger:
```
error: conformance of 'Article' to protocol 'Hashable' crosses into main actor-isolated code and can cause data races
```

This is a known Apple framework limitation. Options attempted:
1. `@preconcurrency import SwiftData` - No effect
2. `nonisolated` on Article class - Partial fix, but other protocol conformances still fail
3. Removing `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` - Causes cascading errors throughout codebase

**Recommended path forward**: Wait for Apple to update SwiftData for Swift 6 compatibility in a future Xcode release.

---

## Overview

Migrate Luego from Swift 5.0 to Swift 6 language mode. The codebase is well-positioned with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` enabled and most services/ViewModels already marked `@MainActor`.

## Pre-Migration Checklist

Before starting, verify:
- [x] All 37 tests pass (run `/xcode-test`)
- [x] Clean build on iOS, macOS
- [x] Create branch `swift6-concurrency-migration` from main

## Phase 1: Enable Complete Concurrency Checking

### Build Settings

Set `SWIFT_STRICT_CONCURRENCY = complete` for all three targets:
- Luego (main app)
- LuegoTests
- LuegoShareExtension

### Known Issues to Fix

#### 1. ContentDataSource: Sendable/MainActor Mismatch

**File:** `Luego/Core/DataSources/ContentDataSource.swift:3`

**Problem:** Claims `Sendable` but holds references to `@MainActor`-isolated types:
```swift
final class ContentDataSource: MetadataDataSourceProtocol, Sendable {
    private let parserDataSource: LuegoParserDataSourceProtocol    // impl is @MainActor
    private let metadataDataSource: MetadataDataSourceProtocol     // impl is @MainActor
    // ...
}
```

**Solution:** Add `@MainActor` isolation:
```swift
@MainActor
final class ContentDataSource: MetadataDataSourceProtocol {
    // Remove explicit Sendable - MainActor types are implicitly Sendable
```

**Why this works:** All dependent DataSources (`ParsedContentCacheDataSource`, `LuegoParserDataSource`, `MetadataDataSource`) are already `@MainActor`, so synchronous method calls like `parsedContentCache.get(for:)` remain valid.

#### 2. SharedStorage: Sendable Conformance

**File:** `Luego/Features/Sharing/DataSources/SharedStorage.swift:14`

**Problem:** Protocol requires `Sendable` but class doesn't conform:
```swift
protocol SharedStorageDataSourceProtocol: Sendable { ... }
final class SharedStorage: SharedStorageDataSourceProtocol {  // ← missing Sendable
```

**Solution (Preferred):** Add `@MainActor` for consistency with other DataSources:
```swift
@MainActor
final class SharedStorage: SharedStorageDataSourceProtocol {
    // MainActor types are implicitly Sendable
```

**Alternative:** If MainActor causes issues with the Share Extension, use `@unchecked Sendable` with safety documentation:
```swift
/// Safety invariant: All methods access only thread-safe UserDefaults
/// and immutable `let` properties. No mutable state is shared.
/// TODO: Consider migrating to @MainActor for consistency
final class SharedStorage: SharedStorageDataSourceProtocol, @unchecked Sendable {
```

#### 3. Share Extension: Completion Handler Patterns

**File:** `LuegoShareExtension/ShareViewController.swift:70-85`

**Problem:** Uses completion-based APIs that cross isolation boundaries:
```swift
provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
    // This closure crosses isolation boundaries
```

**Solution:** Mark closure as `@Sendable` and properly capture weak self in Task:
```swift
provider.loadItem(forTypeIdentifier: "public.url", options: nil) { @Sendable [weak self] (item, error) in
    Task { @MainActor [weak self] in
        guard let self else { return }

        if let error = error {
            self.completeWithError(message: "Failed to load URL: \(error.localizedDescription)")
            return
        }

        if let url = item as? URL {
            self.saveURL(url)
        } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
            self.saveURL(url)
        } else {
            self.completeWithError(message: "Invalid URL format")
        }
    }
}
```

Apply the same pattern to `handleTextProvider`.

#### 4. Share Extension: Missing Default Actor Isolation

**Build Setting:** Add `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` to LuegoShareExtension target.

**Problem:** The main app has this setting, but the Share Extension does not. This causes all types in the extension to be `nonisolated` by default, creating unexpected isolation boundary warnings.

**Fix:** In Xcode project settings for LuegoShareExtension target:
- Debug configuration: Add `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- Release configuration: Add `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

### Build and Fix

1. Set `SWIFT_STRICT_CONCURRENCY = complete` in project settings
2. Set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` for LuegoShareExtension
3. Build all targets
4. Fix warnings as they appear (expect ~5-10 warnings based on analysis above)
5. Run tests

## Phase 2: Swift 6 Language Mode (BLOCKED)

### Status: ⚠️ Blocked by SwiftData Incompatibility

### Build Settings

Set `SWIFT_VERSION = 6.0` for all three targets.

### Blocker: SwiftData @Model Macro

When Swift 6 mode is enabled with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, the `@Model` macro on `Article` generates errors:

```
error: conformance of 'Article' to protocol 'Hashable' crosses into main actor-isolated code and can cause data races
```

This is because `@Model` synthesizes conformances that aren't actor-isolated, but with MainActor as the default isolation, these cross isolation boundaries.

### Attempted Solutions

1. **`@preconcurrency import SwiftData`** - No effect on macro-generated code
2. **`@Model nonisolated final class Article`** - Partial fix, still errors on PersistentModel conformance
3. **Remove `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`** - Causes 20+ errors across services/ViewModels that rely on implicit MainActor isolation

### Recommended Path Forward

1. Keep Swift 5.0 with `SWIFT_STRICT_CONCURRENCY = complete` (current state)
2. Wait for Apple to update SwiftData for Swift 6 in a future Xcode/iOS SDK release
3. Re-attempt Swift 6 migration after SwiftData is updated

### Verification (When Unblocked)

- [ ] All 50+ tests pass
- [ ] iOS app launches and can save/read articles
- [ ] macOS app launches and can save/read articles
- [ ] Share Extension can save URLs
- [ ] CloudKit sync works (save article on one device, appears on another)

### Post-Migration Verification (When Unblocked)

After Swift 6 mode is enabled:
- [ ] Run full test suite
- [ ] Check for runtime isolation violations (crashes mentioning "actor isolation")
- [ ] Verify no `Task` leaks in Instruments (Memory graph)
- [ ] Test Share Extension specifically (different target, different isolation defaults)

## Files Requiring Changes

| File | Issue | Solution |
|------|-------|----------|
| `ContentDataSource.swift` | Sendable mismatch | Add `@MainActor` |
| `SharedStorage.swift` | Missing Sendable | Add `@MainActor` (preferred) |
| `ShareViewController.swift` | Completion handlers | Add `@Sendable`, wrap in `Task { @MainActor }` |
| `project.pbxproj` | Extension isolation | Add `SWIFT_DEFAULT_ACTOR_ISOLATION` to extension |

## Out of Scope

- **Upcoming Swift features** (`INFER_SENDABLE_FROM_CAPTURES`, etc.) - not required for Swift 6
- **Refactoring** - focus only on concurrency compliance
- **Share Extension modernization** - completion handlers are fine, just need isolation

## Rollback

If issues arise that can't be resolved quickly:
1. Revert `SWIFT_VERSION` to 5.0
2. Revert `SWIFT_STRICT_CONCURRENCY` to default
3. File issues for specific problems

## References

- [Swift 6 Migration Guide](https://www.swift.org/migration/documentation/migrationguide/)
- `docs/solutions/build-errors/observable-nonisolated-unsafe-conflict.md` - Previous concurrency fix
