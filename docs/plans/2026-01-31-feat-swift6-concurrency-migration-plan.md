---
title: Migrate to Swift 6 Structured Concurrency
type: feat
date: 2026-01-31
status: partial-complete
---

# Migrate to Swift 6 Structured Concurrency

## Outcome Summary

**Phase 1: Complete** - Strict concurrency checking enabled for all targets
**Phase 2: Blocked** - Swift 6 language mode incompatible with SwiftData `@Model` macro + MainActor default isolation

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
