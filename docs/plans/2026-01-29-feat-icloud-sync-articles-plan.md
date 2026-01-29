---
title: "feat: Add iCloud Sync for Articles"
type: feat
date: 2026-01-29
---

# feat: Add iCloud Sync for Articles

## Overview

Enable iCloud sync for Luego so users can seamlessly access their reading list across iPhone and iPad. Articles, read positions, favorites, and archive status will sync automatically using SwiftData's built-in CloudKit integration.

**Scope:**
- Sync articles (URLs, metadata, content) across devices
- Sync user state (read position, favorites, archived)
- Conflict resolution: last write wins (CloudKit server timestamps)

## Problem Statement / Motivation

Currently, Luego stores articles locally on each device with no cross-device synchronization. Users who read on both iPhone and iPad must manually manage their reading list on each device, leading to:

1. **Duplicate effort**: Saving the same article on multiple devices
2. **Lost progress**: Read position doesn't transfer between devices
3. **Inconsistent state**: An article might be archived on iPhone but still visible on iPad
4. **Poor user experience**: Modern read-it-later apps are expected to sync seamlessly

iCloud sync is the natural choice for an iOS-only app because:
- Users already have iCloud accounts
- No server infrastructure to maintain
- Privacy-focused (data stays in user's iCloud)
- SwiftData has first-party CloudKit support

## Proposed Solution

Leverage **SwiftData + CloudKit automatic sync** via `ModelConfiguration(cloudKitDatabase:)`. This is a single configuration change — SwiftData handles all sync logic automatically (conflict resolution, retry, offline queue).

**High-level architecture:**

```
┌─────────────────────────────────────────────────────────────────────┐
│                           User's Devices                            │
├─────────────────────────────────┬───────────────────────────────────┤
│           iPhone                │              iPad                 │
│  ┌─────────────────────────┐    │    ┌─────────────────────────┐    │
│  │      SwiftData          │    │    │      SwiftData          │    │
│  │   ModelContainer        │    │    │   ModelContainer        │    │
│  │  (CloudKit-enabled)     │    │    │  (CloudKit-enabled)     │    │
│  └───────────┬─────────────┘    │    └───────────┬─────────────┘    │
│              │                  │                │                  │
└──────────────┼──────────────────┴────────────────┼──────────────────┘
               │                                   │
               │         CloudKit Sync             │
               └─────────────┬─────────────────────┘
                             │
                    ┌────────▼────────┐
                    │    CloudKit     │
                    │ Private Database│
                    │ iCloud.com.     │
                    │ esoxjem.Luego   │
                    └─────────────────┘
```

## Technical Approach

### Why This is Simple

SwiftData + CloudKit provides:
- **Automatic sync** — no manual trigger needed
- **Offline queue** — changes sync when connectivity returns
- **Conflict resolution** — last write wins via server timestamps
- **Retry logic** — transient failures handled automatically

We do NOT need:
- ~~SyncService layer~~ — framework handles sync
- ~~SyncState/SyncError enums~~ — framework handles errors
- ~~Sync toggle UI~~ — sync is always on when configured
- ~~"Sync Now" button~~ — sync is automatic
- ~~modifiedDate property~~ — CloudKit uses server timestamps
- ~~Read position throttling~~ — SwiftData batches writes automatically

### Implementation

**Files to modify:**

| File | Change |
|------|--------|
| `Luego.entitlements` | Add iCloud/CloudKit entitlements |
| `Luego/App/LuegoApp.swift` | Add `cloudKitDatabase` parameter to ModelConfiguration |
| Xcode project | Add iCloud capability |

**Configuration change:**

```swift
// LuegoApp.swift - ONE parameter change
let modelConfiguration = ModelConfiguration(
    schema: schema,
    cloudKitDatabase: .private("iCloud.com.esoxjem.Luego")
)
```

**Entitlements to add:**

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.esoxjem.Luego</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

### Tasks

- [x] Create CloudKit container in Apple Developer portal (`iCloud.com.esoxjem.Luego`)
- [x] Add iCloud capability in Xcode (Signing & Capabilities)
- [x] Update `Luego.entitlements` with CloudKit entitlements
- [x] Modify `ModelConfiguration` in `LuegoApp.swift` to use CloudKit
- [ ] Test sync between two simulators
- [ ] Test sync on real devices (iPhone + iPad)

**Estimated effort:** 0.5-1 day

### Success Criteria

- [x] App builds with CloudKit capability
- [ ] Articles sync between iPhone and iPad within 30 seconds
- [ ] New articles appear on other device automatically
- [ ] Read position syncs between devices
- [ ] Favorites and archive status sync correctly
- [ ] Deletes propagate correctly
- [ ] App works offline (changes queue and sync later)

## Deferred Items (Address If Needed)

These items are explicitly NOT in scope. Address only if real problems emerge in production:

| Item | Why Deferred |
|------|--------------|
| Sync status UI | Users expect sync to work invisibly |
| Error handling UI | Surface via system alerts if issues arise |
| Read position throttling | SwiftData batches writes automatically |
| Deletion while reading edge case | Fix when reported |
| Duplicate URL handling | CloudKit merges by record ID; test first |
| Large content handling | Test with real articles; address if fails |
| Offline indicator | iOS already shows network status |
| Pull to refresh for sync | Sync is automatic |

## Alternative Approaches Considered

### 1. Custom CloudKit Implementation (Rejected)

**Approach:** Use CloudKit APIs directly without SwiftData integration.

**Rejected because:** SwiftData already provides this functionality. Reinventing the wheel adds maintenance burden.

### 2. SyncService Abstraction Layer (Rejected)

**Approach:** Create protocol/service layer to monitor and manage sync state.

**Rejected because:**
- SwiftData + CloudKit sync is automatic — no management needed
- SwiftData does NOT expose `NSPersistentCloudKitContainer` directly, so monitoring is limited anyway
- Adds complexity without user value

### 3. Sync Toggle UI (Rejected)

**Approach:** Allow users to enable/disable sync.

**Rejected because:**
- `ModelConfiguration` is set at app launch — cannot toggle at runtime
- Why would users disable sync on a read-it-later app?
- Adds complexity for edge case

### 4. modifiedDate for Conflict Resolution (Rejected)

**Approach:** Add client-side timestamp for conflict resolution.

**Rejected because:**
- CloudKit already uses server timestamps for "last write wins"
- Server timestamps are more reliable (no clock skew between devices)
- Adds migration for zero functional benefit

## Acceptance Criteria

### Functional Requirements

- [ ] Articles sync between iPhone and iPad within 30 seconds
- [ ] Read position syncs between devices
- [ ] Favorites and archive status sync correctly
- [ ] Article deletion syncs to all devices
- [ ] Sync works when app returns from background
- [ ] App remains functional when offline (local changes queue)

### Non-Functional Requirements

- [ ] Sync does not noticeably impact app performance
- [ ] No data loss during sync

### Quality Gates

- [ ] Manual testing on real devices (iPhone + iPad)
- [ ] Test offline → online sync behavior

## Dependencies & Prerequisites

### Technical Dependencies

- [ ] Apple Developer account with iCloud capability
- [ ] CloudKit container created in Apple Developer portal
- [ ] Xcode project configured with iCloud entitlements

### External Dependencies

- iCloud availability (Apple infrastructure)
- User must be signed into iCloud on devices

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Large article content exceeds CloudKit limits | Low | Medium | Test with large content; address if fails |
| Sync conflicts cause unexpected behavior | Low | Medium | CloudKit uses server timestamps; trust the framework |
| iCloud quota exceeded | Medium | Low | CloudKit surfaces error; user can manage storage |
| Share Extension sync issues | Low | Medium | Current UserDefaults approach continues to work |

## Share Extension Compatibility

The current Share Extension approach continues to work:
1. Share Extension saves to App Groups (UserDefaults)
2. Main app imports on launch via `SharingService`
3. Main app's SwiftData with CloudKit syncs to iCloud

Share Extensions cannot access the main app's CloudKit database directly — this is the correct pattern.

## Testing Approach

**Manual testing on real devices is the primary verification method.** CloudKit sync cannot be meaningfully unit tested.

Test scenarios:
1. Add article on iPhone → appears on iPad
2. Favorite article on iPad → starred on iPhone
3. Archive article on iPhone → archived on iPad
4. Delete article on iPad → removed from iPhone
5. Read article on iPhone, check position on iPad
6. Go offline, make changes, go online → changes sync

## Future Considerations (Not In Scope)

- Shared reading lists between users
- Sync history/changelog
- Mac app sync
- Widget sync optimization

## References

### Internal References

- Current ModelContainer setup: `Luego/App/LuegoApp.swift`
- Share Extension storage: `Luego/Features/Sharing/DataSources/SharedStorage.swift`

### External References

- [SwiftData + CloudKit Documentation](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [CloudKit Best Practices](https://developer.apple.com/documentation/cloudkit)

## Checklist Summary

### Pre-Implementation

- [x] Create CloudKit container in Apple Developer portal

### Implementation

- [x] Add iCloud capability to Xcode project
- [x] Update entitlements
- [x] Change `ModelConfiguration` to use `cloudKitDatabase`
- [ ] Test on simulators
- [ ] Test on real devices

### Verification

- [ ] Articles sync within 30 seconds
- [ ] Read position syncs
- [ ] Favorites/archive sync
- [ ] Deletes propagate
- [ ] Offline changes queue and sync
