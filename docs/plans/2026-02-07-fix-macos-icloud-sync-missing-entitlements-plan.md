---
title: "fix: macOS iCloud Sync Broken Due to Missing Entitlements"
type: fix
date: 2026-02-07
---

# Fix macOS iCloud Sync Broken Due to Missing Entitlements

## Overview

Articles added on iPhone/iPad do not appear on the macOS app. Sync works correctly between iPhone and iPad. The root cause is that `Luego-macOS.entitlements` is missing 3 critical entitlements that were specified in the original macOS support plan but never added during implementation.

## Problem Statement

The macOS entitlements file (`Luego/Luego-macOS.entitlements`) only contains:
- `com.apple.developer.icloud-container-identifiers`
- `com.apple.developer.icloud-services`

It is **missing** these entitlements that the iOS version has:

| Entitlement | iOS | macOS | Impact |
|-------------|-----|-------|--------|
| `aps-environment` | Yes | **No** | CloudKit uses push notifications to trigger sync. Without this, macOS never receives sync events. |
| `com.apple.security.app-sandbox` | N/A | **No** | Build settings enable sandbox (`ENABLE_APP_SANDBOX = YES`) but the entitlements file doesn't declare it, creating a mismatch. |
| `com.apple.security.network.client` | N/A | **No** | Required for network access in sandboxed macOS apps. CloudKit needs this to talk to iCloud servers. |
| `com.apple.security.application-groups` | Yes | **No** | Needed for Share Extension data sharing (not directly related to sync, but should be present for parity). |

## Root Cause

The original plan (`docs/plans/2026-01-30-feat-macos-native-support-plan.md`) specified the correct entitlements including `app-sandbox` and `network.client`, but the implementation only added the two iCloud-specific keys. A follow-up todo (`todos/003-resolved-p2-missing-sandbox-entitlements.md`) identified the missing sandbox entitlements but was marked resolved without the fix being applied.

The `aps-environment` key was never identified as needed for macOS — it was only present in the iOS entitlements. This is the most critical missing piece for sync.

## Proposed Solution

Update `Luego/Luego-macOS.entitlements` to include all required entitlements.

### `Luego/Luego-macOS.entitlements`

The file should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.esoxjem.Luego</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.esoxjem.Luego</string>
    </array>
</dict>
</plist>
```

**New keys being added:**
1. `com.apple.security.app-sandbox` — declares sandbox mode explicitly
2. `com.apple.security.network.client` — allows network access in sandbox
3. `aps-environment` — enables CloudKit push notifications for sync
4. `com.apple.security.application-groups` — enables App Group for Share Extension parity

## Acceptance Criteria

- [x] `Luego-macOS.entitlements` contains all 6 entitlement keys listed above
- [ ] macOS app builds successfully
- [ ] macOS app launches without sandbox errors in Console.app
- [ ] Articles added on iPhone appear on macOS after a short delay
- [ ] Articles added on macOS appear on iPhone after a short delay
- [ ] SyncStatusObserver shows `.syncing` and `.success` states on macOS
- [x] Unit tests pass on iOS Simulator (281/281 passed)

## Context

- **Files to modify:** 1 (`Luego/Luego-macOS.entitlements`)
- **Effort:** Trivial (~5 minutes)
- **Risk:** None — adding missing entitlements is purely additive

## References

- iOS entitlements (reference): `Luego/Luego.entitlements`
- Original macOS plan: `docs/plans/2026-01-30-feat-macos-native-support-plan.md` (lines 88-108)
- Unresolved todo: `todos/003-resolved-p2-missing-sandbox-entitlements.md`
- CloudKit sync observer: `Luego/Core/DataSources/SyncStatusObserver.swift`
- CloudKit background mode doc: `docs/solutions/build-errors/cloudkit-remote-notification-background-mode.md`
