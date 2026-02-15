# App Flavours: Dev / Beta / Release

**Date:** 2026-02-08
**Status:** Ready for planning

## What We're Building

Separate app flavours so Dev, Beta, and Release builds can coexist on the same device with distinct visual identities.

| Flavour | Bundle ID | Display Name | Icon | Build Config |
|---------|-----------|-------------|------|--------------|
| Dev | `com.esoxjem.Luego.dev` | Luego Dev | Banner "DEV" | Debug |
| Beta | `com.esoxjem.Luego.beta` | Luego Beta | Banner "BETA" | Beta (new) |
| Release | `com.esoxjem.Luego` | Luego | Normal | Release |

## Why This Approach

**Xcconfig files + build configurations** was chosen over alternatives:

- **vs. Build settings only:** Xcconfig files are readable, diffable, and version-controlled. Three flavours map cleanly to three build configurations. Build-settings-only approach is fragile for the Beta case since it doesn't fit neatly into Debug or Release.
- **vs. Separate targets:** One target per flavour causes massive duplication (every source file added to all targets). Overkill when xcconfig + build configs achieve the same result with zero source duplication.

## Key Decisions

1. **Shared CloudKit container** — All flavours use `iCloud.com.esoxjem.Luego`. Dev and Beta can test with real articles.
2. **Banner overlay icons** — Diagonal "DEV" / "BETA" banners on the existing icon for at-a-glance differentiation.
3. **Three build configurations** — Debug, Beta (new, duplicated from Release), Release. Each maps to an xcconfig file.
4. **Share extension follows parent** — `com.esoxjem.Luego.dev.LuegoShareExtension` for Dev, `.beta.` for Beta.
5. **App group stays shared** — `group.com.esoxjem.Luego` is the same across flavours so the share extension can communicate with any flavour.

## Scope

### In Scope
- Create `Debug.xcconfig`, `Beta.xcconfig`, `Release.xcconfig`
- Add `Beta` build configuration to project.pbxproj
- Per-flavour: bundle ID, display name, app icon asset
- Share extension bundle ID follows parent flavour suffix
- Create `AppIcon-Dev` and `AppIcon-Beta` asset catalog entries with banner overlays
- Update deploy scripts if needed

### Out of Scope
- Separate CloudKit containers per flavour
- Separate entitlements per flavour (same sandbox, same APS environment)
- Feature flags or runtime behaviour differences between flavours
- CI/CD pipeline changes

## Open Questions

1. Should the Beta config use Debug or Release optimizations? (Likely Release optimizations to match TestFlight experience)
2. Do we need a separate Xcode scheme for Beta, or can the existing scheme switch configurations?
