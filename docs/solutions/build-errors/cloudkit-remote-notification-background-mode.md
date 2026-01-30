---
title: CloudKit Push Notifications Require remote-notification Background Mode in Info.plist
category: build-errors
tags:
  - cloudkit
  - ios
  - ipados
  - info-plist
  - background-modes
  - push-notifications
  - swiftdata
  - remote-notification
  - xcode
  - generate-infoplist-file
symptoms:
  - Runtime error "BUG IN CLIENT OF CLOUDKIT: CloudKit push notifications require the 'remote-notification' background mode in your info plist"
  - CloudKit sync not working when app is backgrounded on iOS/iPadOS
  - App builds successfully but fails at runtime when CloudKit sync attempts to register for push notifications
  - SwiftData with CloudKit database configuration triggers the error
module: Core/CloudKit
severity: medium
platforms:
  - ios
  - ipados
resolved: true
date_resolved: 2026-01-30
root_cause: |
  When using GENERATE_INFOPLIST_FILE = YES in Xcode build settings, the auto-generated Info.plist
  does not include UIBackgroundModes. CloudKit requires the 'remote-notification' background mode
  to receive silent push notifications for sync updates.
related_files:
  - Luego/Info-iOS.plist
  - Luego/Luego.entitlements
  - Luego.xcodeproj/project.pbxproj
prerequisites:
  - aps-environment entitlement (development or production)
  - CloudKit container identifier configured
  - iCloud services enabled in entitlements
---

## Problem

When running Luego on iOS/iPadOS, CloudKit logs this error:

```
BUG IN CLIENT OF CLOUDKIT: CloudKit push notifications require the 'remote-notification' background mode in your info plist.
```

**Impact**: CloudKit sync works when the app is in the foreground, but fails to receive sync updates when backgrounded. Cross-device sync relies on silent push notifications to wake the app and pull changes.

## Root Cause

CloudKit relies on **silent push notifications** to notify devices when remote data changes. Without the proper background mode configuration, iOS cannot register for these notifications.

Luego uses Xcode's **auto-generated Info.plist** feature (`GENERATE_INFOPLIST_FILE = YES`), which creates the Info.plist dynamically from `INFOPLIST_KEY_*` build settings. This approach has a critical limitation:

**The `UIBackgroundModes` key requires an array value, but Xcode's `INFOPLIST_KEY_UIBackgroundModes` build setting does not properly handle array values.**

This means there is no straightforward way to declare:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

...using only build settings when the project relies on auto-generated Info.plist.

## Solution

Use a **hybrid approach** that merges a custom plist with the auto-generated one, but only for iOS builds (since macOS handles background notifications differently).

### Step 1: Create iOS-Specific Info.plist

Create a minimal plist file at `Luego/Info-iOS.plist` containing only the keys that cannot be expressed as build settings:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>UIBackgroundModes</key>
	<array>
		<string>remote-notification</string>
	</array>
</dict>
</plist>
```

This plist is intentionally minimal - it contains only the `UIBackgroundModes` array. All other Info.plist values continue to come from the auto-generated plist via `INFOPLIST_KEY_*` settings.

### Step 2: Configure Conditional INFOPLIST_FILE

Update `project.pbxproj` to use SDK-conditional `INFOPLIST_FILE` values. Add these settings to **both Debug and Release** configurations:

```
GENERATE_INFOPLIST_FILE = YES;
"INFOPLIST_FILE[sdk=iphoneos*]" = "Luego/Info-iOS.plist";
"INFOPLIST_FILE[sdk=iphonesimulator*]" = "Luego/Info-iOS.plist";
```

The **SDK conditional syntax** `[sdk=iphoneos*]` and `[sdk=iphonesimulator*]`:
- When building for iOS device (`iphoneos*`) → uses `Info-iOS.plist`
- When building for iOS Simulator (`iphonesimulator*`) → uses `Info-iOS.plist`
- When building for macOS (`macosx*`) → no custom plist, only auto-generated

### How It Works

When `GENERATE_INFOPLIST_FILE = YES` is combined with a custom `INFOPLIST_FILE`:

1. Xcode generates a base Info.plist from all `INFOPLIST_KEY_*` build settings
2. Xcode then **merges** the custom plist file on top of the generated one
3. The resulting Info.plist contains both the auto-generated keys AND the custom keys

### Platform Matrix

| Platform | INFOPLIST_FILE | Result |
|----------|---------------|--------|
| iOS Device | `Luego/Info-iOS.plist` | Merged plist with `UIBackgroundModes` |
| iOS Simulator | `Luego/Info-iOS.plist` | Merged plist with `UIBackgroundModes` |
| macOS | (none - auto-generated only) | Standard auto-generated plist |

macOS does not require `UIBackgroundModes` because it handles push notifications differently - the key is iOS-specific.

## Verification

After implementing this solution:

```bash
# Build for iOS Simulator
xcodebuild -project Luego.xcodeproj -scheme Luego \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Check the built Info.plist
/usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" \
  DerivedData/Build/Products/Debug-iphonesimulator/Luego.app/Info.plist

# Expected output:
# Array {
#     remote-notification
# }
```

Run the app and filter Console.app for the process - you should no longer see the "BUG IN CLIENT" error.

## Prevention

### Checklist for Future CloudKit Projects

- [ ] Create explicit `Info-iOS.plist` when enabling CloudKit
- [ ] Add `UIBackgroundModes` with `remote-notification` immediately
- [ ] Verify `aps-environment` entitlement is present
- [ ] Confirm `com.apple.developer.icloud-services` includes `CloudKit`
- [ ] Test background sync, not just foreground sync

### CI Build Verification Script

Add to build phases to catch misconfigurations:

```bash
#!/bin/bash
set -e

PLIST_PATH="${SRCROOT}/Luego/Info-iOS.plist"

if [[ "${PLATFORM_NAME}" == "iphoneos" ]] || [[ "${PLATFORM_NAME}" == "iphonesimulator" ]]; then
    BACKGROUND_MODES=$(/usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" "${PLIST_PATH}" 2>/dev/null || echo "")

    if [[ -z "${BACKGROUND_MODES}" ]]; then
        echo "error: UIBackgroundModes is missing. CloudKit sync will fail silently."
        exit 1
    fi

    if ! echo "${BACKGROUND_MODES}" | grep -q "remote-notification"; then
        echo "error: UIBackgroundModes must include 'remote-notification' for CloudKit."
        exit 1
    fi

    echo "✓ Info.plist CloudKit configuration verified"
fi
```

### Runtime Test

```swift
import Testing

@Test("UIBackgroundModes includes remote-notification on iOS")
func testBackgroundModesConfigured() async throws {
    #if os(iOS)
    let bundle = Bundle.main
    let backgroundModes = bundle.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]

    #expect(backgroundModes != nil, "UIBackgroundModes must be present")
    #expect(backgroundModes?.contains("remote-notification") == true,
            "Must include 'remote-notification' for CloudKit push sync")
    #endif
}
```

## Related Documentation

- [iCloud Sync Status UI Plan](../../plans/2026-01-30-feat-icloud-sync-status-ui-plan.md) - CloudKit sync observation
- [macOS Native Support Plan](../../plans/2026-01-30-feat-macos-native-support-plan.md) - Platform-specific entitlements
- [CLAUDE.md](../../../CLAUDE.md) - SwiftData with CloudKit configuration
- [Apple: UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes)

## Files Changed

| File | Change |
|------|--------|
| `Luego/Info-iOS.plist` | Created with UIBackgroundModes array |
| `Luego.xcodeproj/project.pbxproj` | Added conditional INFOPLIST_FILE settings |
