---
status: resolved
priority: p2
issue_id: "003"
tags: [code-review, security, macos, entitlements, sandbox]
dependencies: []
---

# Missing App Sandbox Entitlements in macOS Entitlements File

## Problem Statement

The macOS entitlements file (`Luego-macOS.entitlements`) is missing explicit App Sandbox and network client entitlements. While `ENABLE_APP_SANDBOX = YES` is set in build settings, best practice requires explicit entitlement declarations for clarity and to ensure network access works in sandboxed mode.

**Why it matters:** Without proper entitlements, the app may fail App Store review or have restricted capabilities on macOS.

## Findings

### Evidence

**File:** `Luego/Luego-macOS.entitlements`
```xml
<dict>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.esoxjem.Luego</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <!-- Missing: com.apple.security.app-sandbox -->
    <!-- Missing: com.apple.security.network.client -->
</dict>
```

**From Planning Doc:** `docs/plans/2026-01-30-feat-macos-native-support-plan.md` specifies:
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

### Impact

Without explicit entitlements:
- Build settings enable sandbox but entitlements file doesn't declare it
- Network access in sandbox mode requires `network.client` entitlement
- Potential App Store review rejection
- Confusion about app's security posture

## Proposed Solutions

### Option A: Add Missing Entitlements (Recommended)

Add the sandbox and network entitlements to `Luego-macOS.entitlements`.

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

**Pros:**
- Explicit declaration of security posture
- Matches the planning documentation
- Ensures network access works

**Cons:**
- None (this is the correct approach)

**Effort:** Trivial (5 minutes)
**Risk:** None

## Recommended Action

Add the missing entitlements to `Luego-macOS.entitlements`.

## Technical Details

**Affected Files:**
- `Luego/Luego-macOS.entitlements`

## Acceptance Criteria

- [ ] `com.apple.security.app-sandbox` is set to `true`
- [ ] `com.apple.security.network.client` is set to `true`
- [ ] macOS app builds successfully
- [ ] Network requests work on macOS

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by security-sentinel agent |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
- [Apple: App Sandbox Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_app-sandbox)
