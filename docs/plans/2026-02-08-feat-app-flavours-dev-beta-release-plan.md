---
title: "feat: App Flavours (Dev + Release)"
type: feat
date: 2026-02-08
---

# feat: App Flavours (Dev + Release)

## Overview

Separate Dev and Release builds so they can coexist on the same device with distinct visual identities. Dev builds get a different bundle ID, display name, and icon. Beta testing is already handled by TestFlight's internal/external tester groups using the Release bundle ID — no separate Beta flavour needed.

| Flavour | Bundle ID | Display Name | Icon | Build Config |
|---------|-----------|-------------|------|--------------|
| Dev | `com.esoxjem.Luego.dev` | Luego Dev | DEV banner | Debug |
| Release | `com.esoxjem.Luego` | Luego | Normal | Release |

## Problem Statement

Installing a Debug build on a device overwrites the App Store / TestFlight build because they share the same bundle ID (`com.esoxjem.Luego`). There is no visual way to distinguish which build is running.

## Proposed Solution

### Architecture: 4 Xcconfig Files

```
Configuration/
├── Luego-Debug.xcconfig            # Dev flavour: bundle ID, display name, icon
├── Luego-Release.xcconfig          # Production: bundle ID, display name, icon
├── ShareExtension-Debug.xcconfig   # Extension Dev: bundle ID, display name
└── ShareExtension-Release.xcconfig # Extension Production: bundle ID, display name
```

Each xcconfig contains **only the settings that differ between flavours**. Everything else stays in `project.pbxproj`. No `Shared.xcconfig` — `DEVELOPMENT_TEAM` stays in pbxproj where it already lives.

### Key Design Decisions

**`PRODUCT_NAME` stays as `$(TARGET_NAME)`** — only `INFOPLIST_KEY_CFBundleDisplayName` changes. This is critical because `TEST_HOST` in LuegoTests references `Luego.app` by name.

**No `BUNDLE_ID_SUFFIX` variable** — just hardcode the full bundle ID in each xcconfig. Two files, two values, no indirection.

**No test target xcconfigs** — the test bundle ID does not need to vary per configuration. Tests always run under Debug.

**No new build configurations** — the existing Debug and Release configs are sufficient. Beta = Release uploaded to TestFlight.

**No shared Xcode schemes** — the auto-generated scheme works. Run = Debug config, Archive = Release config.

## Technical Approach

### Phase 0: Apple Developer Portal (Manual prerequisite)

Register new App IDs and associate them with the **existing** CloudKit container and App Group. Do NOT rely on Xcode auto-provisioning for these associations — Xcode may create new containers instead of reusing the existing one.

| App ID | Associate With |
|--------|---------------|
| `com.esoxjem.Luego.dev` | CloudKit container `iCloud.com.esoxjem.Luego`, App Group `group.com.esoxjem.Luego`, Push Notifications |
| `com.esoxjem.Luego.dev.LuegoShareExtension` | App Group `group.com.esoxjem.Luego` |

### Phase 1: Xcconfig Files

#### 1.1 Create 4 xcconfig files

`Configuration/Luego-Debug.xcconfig`:
```
PRODUCT_BUNDLE_IDENTIFIER = com.esoxjem.Luego.dev
INFOPLIST_KEY_CFBundleDisplayName = Luego Dev
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Dev
```

`Configuration/Luego-Release.xcconfig`:
```
PRODUCT_BUNDLE_IDENTIFIER = com.esoxjem.Luego
INFOPLIST_KEY_CFBundleDisplayName = Luego
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
```

`Configuration/ShareExtension-Debug.xcconfig`:
```
PRODUCT_BUNDLE_IDENTIFIER = com.esoxjem.Luego.dev.LuegoShareExtension
INFOPLIST_KEY_CFBundleDisplayName = Luego Dev
```

`Configuration/ShareExtension-Release.xcconfig`:
```
PRODUCT_BUNDLE_IDENTIFIER = com.esoxjem.Luego.LuegoShareExtension
INFOPLIST_KEY_CFBundleDisplayName = Luego
```

#### 1.2 Wire xcconfig files in project.pbxproj

This is the most complex step. For each xcconfig file:

1. Add a `PBXFileReference` entry (`lastKnownFileType = text.xcconfig`)
2. Add a `PBXGroup` for the `Configuration/` folder under the main project group
3. Set `baseConfigurationReference` on the corresponding `XCBuildConfiguration`:
   - Luego target Debug → `Luego-Debug.xcconfig`
   - Luego target Release → `Luego-Release.xcconfig`
   - LuegoShareExtension target Debug → `ShareExtension-Debug.xcconfig`
   - LuegoShareExtension target Release → `ShareExtension-Release.xcconfig`

That's **4 xcconfigs wired to 4 build configurations**. The project-level Debug/Release configs and LuegoTests configs get no xcconfig (they don't need per-flavour settings).

#### 1.3 Remove hardcoded values from pbxproj

Remove settings that now come from xcconfig. **Critical: pbxproj target-level settings silently override xcconfig values** — any leftover `PRODUCT_BUNDLE_IDENTIFIER` in pbxproj will cause the xcconfig value to be ignored.

Remove from **Luego target** (Debug + Release):
- `PRODUCT_BUNDLE_IDENTIFIER`
- `ASSETCATALOG_COMPILER_APPICON_NAME`

Remove from **LuegoShareExtension target** (Debug + Release):
- `PRODUCT_BUNDLE_IDENTIFIER`
- `INFOPLIST_KEY_CFBundleDisplayName`

#### 1.4 Verify xcconfig values take effect

Run `xcodebuild -showBuildSettings` and confirm resolved values:

```bash
xcodebuild -showBuildSettings -project Luego.xcodeproj -scheme Luego -configuration Debug | grep PRODUCT_BUNDLE_IDENTIFIER
# Expected: PRODUCT_BUNDLE_IDENTIFIER = com.esoxjem.Luego.dev

xcodebuild -showBuildSettings -project Luego.xcodeproj -scheme Luego -configuration Release | grep PRODUCT_BUNDLE_IDENTIFIER
# Expected: PRODUCT_BUNDLE_IDENTIFIER = com.esoxjem.Luego
```

### Phase 2: App Icon

#### 2.1 Create AppIcon-Dev asset set

**New directory:** `Luego/Assets.xcassets/AppIcon-Dev.appiconset/`

- `AppIcon-Dev.png` — 1024×1024, the existing `AppIcon.png` with a diagonal "DEV" banner overlay (orange/red, top-left corner)
- `Contents.json` — same structure as `AppIcon.appiconset/Contents.json`, referencing `AppIcon-Dev.png` for the light appearance

Generate using ImageMagick or a Swift script with CoreGraphics.

### Phase 3: Verification

- [ ] Build Debug config (Dev flavour) on iOS simulator
- [ ] Build Release config on iOS simulator
- [ ] Build Release config on macOS
- [ ] Build Debug config on macOS
- [ ] Run tests under Debug config
- [ ] Install Dev build on simulator — confirm "Luego Dev" name and DEV icon
- [ ] Install Release build on same simulator — confirm both coexist
- [ ] Verify `xcodebuild -showBuildSettings` shows correct bundle IDs for all target × config combinations
- [ ] Share extension displays correct name per flavour
- [ ] Deploy scripts (`/deploy-testflight`, `/deploy-mac`) work unchanged

## Acceptance Criteria

- [ ] Dev build uses `com.esoxjem.Luego.dev`, Release uses `com.esoxjem.Luego`
- [ ] Dev displays "Luego Dev" with DEV banner icon, Release displays "Luego"
- [ ] Both flavours installable simultaneously on the same device
- [ ] Share extension bundle ID and display name follow parent flavour
- [ ] Both flavours use the same CloudKit container (`iCloud.com.esoxjem.Luego`)
- [ ] Both flavours use the same app group (`group.com.esoxjem.Luego`)
- [ ] `PRODUCT_NAME` remains `$(TARGET_NAME)` — tests pass
- [ ] Existing deploy scripts work unchanged
- [ ] No hardcoded `PRODUCT_BUNDLE_IDENTIFIER` left in pbxproj for Luego or ShareExtension targets

## Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CloudKit zone uses bundle ID instead of container ID | Low | High | The `ModelConfiguration` container ID determines the zone. Verify empirically after first build. |
| Xcconfig value silently overridden by leftover pbxproj setting | Medium | High | Phase 1.4 verification step catches this. |
| Xcode auto-provisioning creates new CloudKit container for `.dev` | Medium | High | Phase 0: manually associate App ID with existing container in Apple Developer Portal. |
| Adding `INFOPLIST_KEY_CFBundleDisplayName = Luego` to Release changes App Store name | Low | Low | This is what the name defaults to already. Verify after first TestFlight build. |
| Provisioning profile leaks to SPM deps | Medium | High | `PROVISIONING_PROFILE_SPECIFIER` stays SDK-conditioned in pbxproj, not in xcconfig or command line. |

## Out of Scope

- Separate Beta flavour (TestFlight internal/external testers already serve this purpose)
- Separate CloudKit containers per flavour
- Feature flags or runtime behaviour differences between flavours
- New Xcode schemes (auto-generated scheme works)
- CI/CD pipeline changes

## References

- Brainstorm: `docs/brainstorms/2026-02-08-app-flavours-brainstorm.md`
- Build configs in pbxproj: lines 717-753
- Bundle IDs in pbxproj: lines 515, 565 (Luego), 601, 636 (ShareExtension)
- App icon: `Luego/Assets.xcassets/AppIcon.appiconset/`
- Deploy scripts: `.claude/commands/deploy-mac.md`, `.claude/commands/deploy-testflight.md`
- Provisioning profile lesson: SDK-conditioned settings avoid SPM breakage (see `memory/MEMORY.md`)

### Key Files Modified

| File | Change |
|------|--------|
| `Luego.xcodeproj/project.pbxproj` | Add xcconfig file refs, set `baseConfigurationReference` (×4), remove hardcoded bundle IDs and icon names |
| `Configuration/Luego-Debug.xcconfig` (new) | Dev bundle ID, display name, icon |
| `Configuration/Luego-Release.xcconfig` (new) | Production bundle ID, display name, icon |
| `Configuration/ShareExtension-Debug.xcconfig` (new) | Dev extension bundle ID, display name |
| `Configuration/ShareExtension-Release.xcconfig` (new) | Production extension bundle ID, display name |
| `Luego/Assets.xcassets/AppIcon-Dev.appiconset/` (new) | Dev icon with DEV banner |
