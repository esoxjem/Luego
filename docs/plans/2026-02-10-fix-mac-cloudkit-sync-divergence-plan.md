---
title: "fix: Mac CloudKit Sync Divergence — Mac Syncs Separately from iPhone/iPad"
type: fix
date: 2026-02-10
---

# Fix Mac CloudKit Sync Divergence — Mac Syncs Separately from iPhone/iPad

## Overview

A user reports that their Mac app syncs articles independently from their iPhone and iPad. iPhone and iPad share one set of articles; the Mac has a different set. Reinstalling the Mac app causes articles to reappear (pulled from CloudKit), but ongoing bidirectional sync with iOS devices does not work.

**Critical constraint:** The developer sees correct sync across all devices in **both Debug AND Release builds**. This means the same App Store binary works correctly on the developer's Mac but fails for this user. Build-configuration issues (framework linking, provisioning profile, schema deployment) are therefore **unlikely to be the primary cause** — the same binary runs on both Macs.

The issue is most likely **user-environment-specific**.

## Problem Statement

### Symptoms

| Device | Behavior | Explanation |
|--------|----------|-------------|
| iPhone <-> iPad | Sync works correctly | CloudKit pipeline is functional for this user on iOS |
| Mac (standalone) | Articles exist, can add/read | Local SwiftData store works fine |
| Mac <-> iPhone/iPad | No sync | Mac's CloudKit sync pipeline is broken for this user |
| Mac after reinstall | Articles reappear | Fresh `ModelContainer` triggers initial CloudKit import (proves CloudKit IS accessible) |
| Mac ongoing after reinstall | Still no sync with iOS | Ongoing sync triggers (push notifications) are not being received or processed |
| Developer's Mac (Release) | Everything works | Same binary, different user environment = user-specific issue |

### Key Deductions

1. **CloudKit IS accessible from the user's Mac** — reinstalling pulls articles from CloudKit. This proves the container ID, entitlements, and schema are correct in the binary.
2. **Initial sync works, ongoing sync doesn't** — the Mac can do a full import on fresh install, but doesn't receive subsequent changes. This points to the **push notification pipeline** being broken for this user.
3. **Same binary works for developer** — this rules out framework linking, provisioning profile, and schema deployment as primary causes. The issue is in the user's environment.

## Root Cause Analysis

### Root Cause 1: Different Apple ID on Mac vs iPhone/iPad (HIGH — Check First)

The single most common cause of "Mac syncs separately" is the user being signed into a **different Apple ID** on their Mac versus their iPhone/iPad. CloudKit private databases are per-Apple-ID — two different accounts would have completely separate data stores.

**Key signal:** If the user confirms they're using the same Apple ID everywhere, this is ruled out. If they're not sure, this is the most likely cause.

### Root Cause 2: User's Mac Not Receiving CloudKit Push Notifications (HIGH)

CloudKit uses silent push notifications (via APNs) to trigger sync between devices. When Device A writes a record, CloudKit sends a push notification to Devices B and C, which triggers `NSPersistentCloudKitContainer` to perform an import.

If the user's Mac is not receiving or processing these push notifications, the Mac would only sync on app launch (initial full import) but never receive ongoing changes. This exactly matches the reported behavior.

**Possible sub-causes:**
- **macOS notification permissions**: System Settings > Notifications > Luego may have notifications disabled, blocking silent pushes
- **Focus mode / Do Not Disturb**: Could be suppressing push delivery
- **macOS Firewall or network configuration**: Corporate/VPN network could block APNs traffic (ports 443, 2197, 5223)
- **iCloud account issues on Mac**: The user's iCloud account may be in a degraded state on Mac specifically
- **APNs registration not happening**: The app does not call `registerForRemoteNotifications()` on macOS — SwiftData may handle this internally, but it may not be working for this user's configuration

**Why it still works for the developer:** The developer's Mac may have different notification settings, network configuration, or iCloud account state.

### Root Cause 3: iCloud Drive or App-Specific iCloud Disabled on Mac (MEDIUM)

On macOS, the user may have:
- **iCloud Drive disabled** on their Mac (pre-macOS Sonoma, this also disabled CloudKit for third-party apps)
- **Luego's iCloud access specifically disabled** in System Settings > Apple Account > iCloud > Apps Using iCloud

**Note:** Starting with macOS Sonoma / iOS 17, [disabling iCloud Drive no longer affects third-party CloudKit apps](https://www.macrumors.com/2023/06/13/icloud-drive-cloudkit-syncing-separate-ios-17/). But the user's macOS version matters — if they're on an older macOS, this could be the cause.

### Root Cause 4: Corrupted Local CloudKit Metadata / Zone (MEDIUM)

`NSPersistentCloudKitContainer` maintains a hidden CloudKit zone and local sync metadata. If this metadata becomes corrupted or out of sync, the container may stop processing changes correctly. Apple's own guidance ([TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)) acknowledges this:

> "The only sure way to cleanly restart cloud sync on an app using NSPersistentCloudKitContainer is to uninstall and reinstall the app."

The fact that reinstalling the Mac app causes articles to reappear (but ongoing sync still doesn't work) suggests the zone isn't fully corrupted — but the sync metadata tracking change tokens may be stale or stuck.

### Root Cause 5: iCloud Storage Quota Exceeded (LOW)

If the user's iCloud storage is full, CloudKit write operations fail with `CKError.quotaExceeded`. This would prevent the Mac from exporting changes, and in some cases can also interfere with import operations. The sync observer should catch this (it classifies `quotaExceeded` errors), but it's worth checking.

### Root Cause 6: macOS Version Compatibility (LOW)

If the user is running a significantly different macOS version from the developer, there may be platform-specific bugs in `NSPersistentCloudKitContainer`. SwiftData's CloudKit integration has had bugs in various OS versions.

## Previously Considered But Deprioritized

The following causes were initially identified as high-priority but are **deprioritized** because the Release build works for the developer (proving the binary is correct):

| Originally Proposed | Why Deprioritized |
|---------------------|-------------------|
| CloudKit.framework not explicitly linked | If framework was missing, developer's Release build would also fail |
| Stale macOS provisioning profile | Same signed binary works for developer |
| CloudKit schema not deployed to Production | Same binary syncs on developer's Production environment |
| `aps-environment` set to `development` | Apple overrides this during signing; same binary works for developer |

**However**, these should still be verified as quick sanity checks (Phase 1 below) since they are easy to confirm and would affect ALL users if broken.

## Proposed Solution

### Phase 1: Quick Sanity Checks (5 minutes)

Confirm the binary is correct (expected to pass, given Release works for developer):

```bash
# 1a. Verify CloudKit.framework is linked
otool -L /path/to/archive/Products/Applications/Luego.app/Contents/MacOS/Luego | grep CloudKit

# 1b. Verify entitlements are correct
codesign -d --entitlements - /path/to/archive/Products/Applications/Luego.app
```

Check for:
- `com.apple.developer.icloud-container-identifiers` contains `iCloud.com.esoxjem.Luego`
- `com.apple.developer.icloud-services` contains `CloudKit`
- `aps-environment` is `production`

Also verify CloudKit Production schema in [CloudKit Console](https://icloud.developer.apple.com/) — confirm all `CD_Article` fields are deployed (`id`, `url`, `title`, `content`, `savedDate`, `thumbnailURL`, `publishedDate`, `readPosition`, `isFavorite`, `isArchived`, `author`, `wordCount`).

If these pass (expected), proceed to Phase 2. If any fail, the build configuration fixes apply.

### Phase 2: User Environment Investigation (Ask the User)

Ask the affected user to check the following, in order. **Each item has a "stop here" decision point — if the cause is found, no further investigation is needed.**

#### 2a. Verify Same Apple ID on All Devices (Rules out Root Cause 1)

> On your Mac: **System Settings > Apple Account** — what email/name is shown at the top?
> On your iPhone: **Settings > [Your Name]** — what email/name is shown?
> Are these the same Apple ID?

If different → **STOP. This is the cause.** User needs to sign into the same Apple ID on all devices.

#### 2b. Check iCloud Settings on Mac (Rules out Root Cause 3)

> On your Mac: **System Settings > Apple Account > iCloud**
> - Is iCloud Drive enabled?
> - Scroll down to "Apps Using iCloud" — is Luego listed and enabled?

If Luego is not enabled for iCloud → **STOP. This is the cause.** Toggle it on.

#### 2c. Test Bidirectional Sync Live

> With both your iPhone and Mac open and Luego running on both:
> 1. Add an article on your **iPhone**. Does it appear on your **Mac** within 2 minutes?
> 2. Add an article on your **Mac**. Does it appear on your **iPhone** within 2 minutes?

This distinguishes:
- **Neither direction works** → account or zone issue (Root Cause 1 or 4)
- **iPhone→Mac fails, Mac→iPhone works** → Mac import/push notification issue (Root Cause 2)
- **Mac→iPhone fails, iPhone→Mac works** → Mac export issue (storage, network)
- **Both fail** → likely different Apple IDs or iCloud disabled

#### 2d. Check macOS Version (Rules out Root Cause 6)

> What macOS version are you running? (**System Settings > General > About**)

Note: the app targets macOS 15.0+. If the user is on an older version, that's a separate issue.

#### 2e. Check iCloud Storage (Rules out Root Cause 5)

> On your Mac: **System Settings > Apple Account > iCloud** — how much storage is used vs available?

If storage is full → user needs to free space or upgrade plan.

#### 2f. Check Notification Settings on Mac (Rules out Root Cause 2)

> On your Mac: **System Settings > Notifications > Luego**
> - Are notifications allowed?
> - Is "Allow notifications when the display is sleeping" enabled?

If notifications are off → **this could be the cause**. Toggle on. (Note: CloudKit uses *silent* push notifications which should bypass notification settings, but macOS behavior is not always consistent.)

#### 2g. Check Network / Firewall (Rules out Root Cause 2 sub-cause)

> Are you on a corporate network, VPN, or behind a firewall?

APNs requires connectivity to Apple's servers on ports 443, 2197, or 5223.

#### 2h. Enable CloudKit Debug Logging

If the above checks are all clean, ask the user to enable detailed CloudKit logging:

> In Terminal, run:
> ```
> defaults write com.esoxjem.Luego -com.apple.CoreData.CloudKitDebug 3
> ```
> Then relaunch Luego, add an article on iPhone, wait 2 minutes, then share Console.app logs filtered by "Luego".

This is the single most useful diagnostic tool for CloudKit sync — it dumps detailed sync state, zone subscriptions, and push notification processing.

**STOP: Do not proceed to Phase 3 until the user has responded to Phase 2 and the root cause is identified (or all environmental checks pass).**

### Phase 3: Code Fix (Defense in Depth)

One code change that could help regardless of the user's environment issue:

#### Add `registerForRemoteNotifications()` on macOS

**File:** `Luego/App/LuegoApp.swift`

The app currently relies on SwiftData to handle push notification registration internally. Adding an explicit call ensures the Mac registers for remote notifications even if SwiftData doesn't do it automatically for all configurations.

```swift
#if os(macOS)
.task(id: "pushRegistration") {
    NSApplication.shared.registerForRemoteNotifications()
}
#endif
```

This is a single idempotent call. If SwiftData already handles registration, it's harmless. If it doesn't for some configurations, this fixes it.

### Phase 4: Build Hygiene (Separate Branch)

These changes won't fix this user's issue (since the binary is already correct), but they eliminate maintenance hazards. **Ship on a separate branch/commit from Phase 3.**

#### Remove hardcoded provisioning profile

**File:** `Luego.xcodeproj/project.pbxproj` (line 564)

Remove `"PROVISIONING_PROFILE_SPECIFIER[sdk=macosx*]" = "luego-mac-prod-profile"`. With `CODE_SIGN_STYLE = Automatic`, Xcode will auto-manage signing, ensuring entitlements always match.

Test with a local archive build before pushing.

#### Nice to have: Explicitly link CloudKit.framework

In Xcode: Target > General > Frameworks, Libraries, and Embedded Content > Add `CloudKit.framework`.

Even though auto-linking works currently, explicit linking is the [documented best practice for macOS](https://fatbobman.com/en/snippet/fix-synchronization-issues-for-macos-apps-using-core-dataswiftdata/). This is optional since auto-linking currently works and any breakage would be caught immediately.

### Phase 5: If Nothing Else Works — Collect Diagnostics

If the user's environment checks are all correct and the code fix doesn't help:

#### 5a. Ask user to capture Console.app logs

Have the user:
1. Open **Console.app** on Mac
2. Filter by process: `Luego`
3. Launch Luego
4. Save 2 minutes of logs and share them

Look for:
- `SyncStatusObserver` messages (Setup/Import/Export events)
- `CKError` codes
- `Launch diagnostics` output
- Any `NSPersistentCloudKitContainer` error messages

#### 5b. Sysdiagnose for Apple-level debugging

Per [Apple TN3164](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer), capture a sysdiagnose:
- **macOS**: Press `Ctrl + Option + Shift + Period`
- **iOS**: Press both volume buttons + power simultaneously

This captures detailed CloudKit sync logs that can reveal zone corruption, change token issues, or APNs delivery failures.

#### 5c. Nuclear option: Reset CloudKit zone

If the user's CloudKit zone is corrupted, the only fix is:
1. User deletes the Mac app
2. In [CloudKit Console](https://icloud.developer.apple.com/), reset the user's private database zone (if accessible)
3. User reinstalls the Mac app
4. Fresh initial sync should pull all data from the iOS/iPad zone

## Acceptance Criteria

### Must Have
- [ ] User environment checklist sent to the affected user (Phase 2)
- [ ] Root cause identified from user's responses
- [x] macOS app calls `registerForRemoteNotifications()` on launch
- [ ] Articles added on iPhone appear on Mac within 60 seconds (for affected user)
- [ ] Articles added on Mac appear on iPhone within 60 seconds (for affected user)
- [ ] iOS sync still works correctly after changes (regression test)

### Should Have
- [x] Hardcoded provisioning profile removed (preventive, separate branch)
- [ ] CloudKit Production schema verified with all fields
- [ ] TestFlight build verified by the affected user before App Store release

### Nice to Have
- [ ] CloudKit.framework explicitly linked (preventive)
- [ ] Console.app logs collected from user's Mac for future reference
- [ ] Sysdiagnose collected if standard diagnostics are inconclusive

## Dependencies & Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| User is on different Apple ID (Root Cause 1) | Instant fix, no code changes | Ask user to verify first |
| User has iCloud disabled for Luego on Mac | Instant fix, no code changes | Ask user to check System Settings |
| `registerForRemoteNotifications()` is not needed (SwiftData handles it) | No impact — call is idempotent | Keep the call; harmless if redundant |
| Removing hardcoded provisioning profile breaks CI/CD | Build fails | Test archive locally before pushing |
| Duplicate articles after sync is restored | User confusion | Advise user to reinstall on platform with fewer unique articles |
| User's CloudKit zone is corrupted | Requires zone reset | Escalate to Console.app logs + sysdiagnose |

## Verification Plan

### User Environment (Phase 2)
1. **Send checklist to user** — Apple ID, iCloud settings, bidirectional sync test, notifications, macOS version, storage
2. **Identify root cause** from user's responses
3. **Guide user through fix** if environmental

### Build Verification (Phase 4)
4. **Archive a Release build** and inspect with `codesign` and `otool`
5. **Verify iOS still builds and syncs** after `project.pbxproj` changes

### Sync Testing
6. **Foreground**: Add article on iPhone → appears on Mac (and vice versa)
7. **Background**: Mac closed → iPhone change → Mac open → verify sync
8. **Sleep/wake**: Mac sleeping → iPhone change → Mac wake → verify catch-up

### User Acceptance
9. **Send TestFlight build to affected user** with `registerForRemoteNotifications()` fix
10. **Collect Console.app logs** if issue persists

### Rollback Plan
- **Build failure from profile removal**: Restore `PROVISIONING_PROFILE_SPECIFIER` and regenerate profile instead
- **User still divergent after all fixes**: Collect sysdiagnose, consider CloudKit zone reset

## Files to Modify

| File | Change | Phase |
|------|--------|-------|
| `Luego/App/LuegoApp.swift` | Add `registerForRemoteNotifications()` for macOS | 3 |
| `Luego.xcodeproj/project.pbxproj` | Remove `PROVISIONING_PROFILE_SPECIFIER[sdk=macosx*]` (preventive) | 4 |
| `Luego.xcodeproj/project.pbxproj` | Add CloudKit.framework (optional, preventive) | 4 |
| CloudKit Console (manual) | Verify Production schema | 1 |

## References

### Internal
- Prior entitlements fix plan: `docs/plans/2026-02-07-fix-macos-icloud-sync-missing-entitlements-plan.md`
- SwiftData unique constraint learning: `docs/solutions/database-issues/swiftdata-unique-constraint-cloudkit-sync-crash.md`
- CloudKit race condition solution: `docs/solutions/integration-issues/cloudkit-sync-ui-race-condition.md`
- Background mode solution: `docs/solutions/build-errors/cloudkit-remote-notification-background-mode.md`
- App entry point: `Luego/App/LuegoApp.swift`
- Sync observer: `Luego/Core/DataSources/SyncStatusObserver.swift`

### External
- [Apple TN3164: Debugging NSPersistentCloudKitContainer Sync](https://developer.apple.com/documentation/technotes/tn3164-debugging-the-synchronization-of-nspersistentcloudkitcontainer)
- [Apple TN3163: Understanding NSPersistentCloudKitContainer Sync](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer)
- [FatBobMan: Fix macOS CloudKit.framework Issue](https://fatbobman.com/en/snippet/fix-synchronization-issues-for-macos-apps-using-core-dataswiftdata/)
- [FatBobMan: Deploy CloudKit Schema to Production](https://fatbobman.com/en/snippet/why-core-data-or-swiftdata-cloud-sync-stops-working-after-app-store-login/)
- [MacRumors: iOS 17 iCloud Drive / CloudKit Separation](https://www.macrumors.com/2023/06/13/icloud-drive-cloudkit-syncing-separate-ios-17/)
- [Hacking with Swift: TestFlight CloudKit Sync Fix](https://www.hackingwithswift.com/forums/swiftui/swiftui-app-failing-to-sync-cloudkit-data-but-only-in-testflight-version/10714)
- [Apple: Syncing Model Data Across Devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
