---
title: "@Observable Macro Conflicts with nonisolated(unsafe) on Task Properties"
category: build-errors
tags:
  - swift-concurrency
  - observable
  - nonisolated
  - mainactor
  - task
  - deinit
  - observation-ignored
  - swiftui
  - cloudkit
symptoms:
  - "Xcode warning: 'nonisolated(unsafe)' has no effect on property, consider using 'nonisolated'"
  - "Build error: 'nonisolated' cannot be applied to mutable stored properties"
  - "@Observable class with @MainActor has Task properties that need cleanup in deinit"
module: Core/DataSources
severity: low
platforms:
  - ios
  - macos
resolved: true
date_resolved: 2026-01-31
root_cause: |
  The @Observable macro generates observation tracking code that conflicts with nonisolated(unsafe).
  When following the Xcode suggestion to use plain nonisolated instead, Swift's language restriction
  prevents applying nonisolated to mutable stored properties. The solution is to use @ObservationIgnored
  to exclude Task properties from observation tracking entirely.
related_files:
  - Luego/Core/DataSources/SyncStatusObserver.swift
prerequisites:
  - Swift 5.10+ with @Observable macro
  - @MainActor isolated class
  - Task properties accessed in deinit
---

## Problem

When using `@Observable` with `@MainActor` on a class that stores `Task` properties for async work, Xcode shows this warning:

```
'nonisolated(unsafe)' has no effect on property 'observerTask', consider using 'nonisolated'
```

However, following the suggestion causes a build error:

```
'nonisolated' cannot be applied to mutable stored properties
```

**Impact**: The warning is misleading and creates confusion about the correct Swift Concurrency pattern.

## Root Cause

Three factors interact to create this problem:

1. **`@Observable` macro** generates observation tracking code that wraps stored properties
2. **`nonisolated(unsafe)`** conflicts with the macro-generated tracking code
3. **`nonisolated`** cannot be applied to mutable stored properties (Swift language restriction)

The Task properties need to be accessible from `deinit` (which is nonisolated) to cancel ongoing work, but the `@Observable` macro's code generation interferes with isolation annotations.

### Why the Xcode Warning is Misleading

The warning suggests `nonisolated` as an alternative, but:
- `nonisolated` is only valid for **immutable** stored properties or computed properties
- `Task<Void, Never>?` is mutable (can be assigned after initialization)
- The `unsafe` in `nonisolated(unsafe)` doesn't mean "unsafe threading" here—it means "I'm opting out of compiler verification"

## Solution

Use `@ObservationIgnored` to exclude Task properties from observation tracking, then remove the isolation annotation entirely:

### Before (Warning)

```swift
@Observable
@MainActor
final class SyncStatusObserver: SyncStatusObservable {
    private(set) var state: SyncState = .idle
    private(set) var lastSyncTime: Date?

    nonisolated(unsafe) private var observerTask: Task<Void, Never>?
    nonisolated(unsafe) private var debounceTask: Task<Void, Never>?

    deinit {
        observerTask?.cancel()
        debounceTask?.cancel()
    }
}
```

### After (No Warning)

```swift
@Observable
@MainActor
final class SyncStatusObserver: SyncStatusObservable {
    private(set) var state: SyncState = .idle
    private(set) var lastSyncTime: Date?

    @ObservationIgnored
    private var observerTask: Task<Void, Never>?
    @ObservationIgnored
    private var debounceTask: Task<Void, Never>?

    deinit {
        observerTask?.cancel()
        debounceTask?.cancel()
    }
}
```

### Why This Works

1. **`@ObservationIgnored`** tells the `@Observable` macro to skip generating tracking code for these properties, eliminating the macro conflict

2. **`deinit` access is safe** because Swift 5.10+ allows deinitializers to access actor-isolated stored properties for cleanup. At deinitialization time, no other references exist, eliminating data race risk.

3. **Task cancellation is thread-safe** - `Task.cancel()` is designed to be called from any context

4. **No need for isolation annotation** - These properties don't need to be observed (they're internal implementation details), and `deinit` cleanup is a special case that Swift handles safely

## Verification

```bash
# Full build with no warnings
xcodebuild build -project Luego.xcodeproj -scheme Luego \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | \
  grep -E "warning:.*nonisolated|warning:.*SyncStatus"

# Should produce no output (no warnings)
```

Run tests to ensure behavior is unchanged:

```bash
xcodebuild test -project Luego.xcodeproj -scheme Luego \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:LuegoTests/SyncStatusObserverTests
```

## Prevention

### Pattern for Task Properties in @Observable Classes

When you need Task properties for async work management in an `@Observable` `@MainActor` class:

```swift
@Observable
@MainActor
final class MyObservableClass {
    // Observable state (tracked by @Observable)
    var visibleState: SomeState = .initial

    // Internal Task management (NOT tracked)
    @ObservationIgnored
    private var workTask: Task<Void, Never>?

    deinit {
        workTask?.cancel()
    }
}
```

### Checklist

- [ ] Task properties managing async work should use `@ObservationIgnored`
- [ ] Do NOT use `nonisolated` or `nonisolated(unsafe)` on mutable stored properties in `@Observable` classes
- [ ] Verify `deinit` cancels all Tasks to prevent leaks
- [ ] Only properties that drive UI updates need observation tracking

### When nonisolated(unsafe) IS Appropriate

Use `nonisolated(unsafe)` when:
- The class is NOT `@Observable`
- You need cross-isolation access beyond just `deinit`
- The property type is `Sendable` and access is actually thread-safe

## Related Documentation

- [Swift Evolution SE-0395: Observation](https://github.com/apple/swift-evolution/blob/main/proposals/0395-observability.md)
- [Swift Evolution SE-0411: Isolated Default Values](https://github.com/apple/swift-evolution/blob/main/proposals/0411-isolated-default-values.md)
- [iCloud Sync Status UI Plan](../../plans/2026-01-30-feat-icloud-sync-status-ui-plan.md)

## Files Changed

| File | Change |
|------|--------|
| `Luego/Core/DataSources/SyncStatusObserver.swift` | Replaced `nonisolated(unsafe)` with `@ObservationIgnored` |
