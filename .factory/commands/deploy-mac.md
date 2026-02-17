# Deploy macOS App

Build, notarize, and publish the Luego macOS app to GitHub Releases.

## Arguments

- `$ARGUMENTS` - Version string (e.g., "2026.01.31"). If not provided, prompt for it.

## Prerequisites

Before running this command, ensure:
1. **Developer ID Certificate** is installed in Keychain ("Developer ID Application: Arun Sasidharan (QTZUF46V7A)")
2. **Provisioning Profile** is installed at `~/Library/Developer/Xcode/UserData/Provisioning Profiles/db76b5c4-138c-4fd7-afb4-3c4254d60bc3.provisionprofile`
3. **Notarization credentials** are stored: `xcrun notarytool store-credentials "AC_PASSWORD"`

## Workflow

### 1. Get Version
If no version argument provided, ask the user for the version string (format: YYYY.MM.DD).

### 2. Bump Version
Update the version in the Xcode project before building:

```bash
# Update MARKETING_VERSION to the release version and reset build number
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${VERSION};/g" Luego.xcodeproj/project.pbxproj
sed -i '' 's/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = 1;/g' Luego.xcodeproj/project.pbxproj

# Verify the changes
echo "Updated versions:"
grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Luego.xcodeproj/project.pbxproj | head -6

# Commit the version bump
git add Luego.xcodeproj/project.pbxproj
git commit -m "bump version to ${VERSION}"
```

### 3. Clean and Build
```bash
rm -rf build/DerivedData

xcodebuild build \
  -project Luego.xcodeproj \
  -scheme Luego \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=Developer ID Application: Arun Sasidharan (QTZUF46V7A)" \
  DEVELOPMENT_TEAM=QTZUF46V7A \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  "OTHER_CODE_SIGN_FLAGS=--timestamp"
```

**Critical build flags:**
- `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` - Prevents debug entitlement (`com.apple.security.get-task-allow`) that blocks notarization
- `OTHER_CODE_SIGN_FLAGS=--timestamp` - Adds secure timestamp required for notarization

**Note:** `PROVISIONING_PROFILE_SPECIFIER` is set in the project file as `PROVISIONING_PROFILE_SPECIFIER[sdk=macosx*] = luego-mac-prod-profile` (target-scoped). Do NOT pass it on the command line — command-line overrides apply globally to all targets including SPM dependencies, which will fail.

### 4. Verify Build
```bash
# Verify code signature
codesign --verify --deep --strict "build/DerivedData/Build/Products/Release/Luego.app"

# Verify no debug entitlement
codesign -d --entitlements - "build/DerivedData/Build/Products/Release/Luego.app" 2>&1 | grep -i "get-task-allow"
# Should return nothing
```

### 5. Package for Notarization
```bash
ditto -c -k --keepParent "build/DerivedData/Build/Products/Release/Luego.app" "build/Luego-macOS-notarize.zip"
```

### 6. Submit for Notarization
```bash
xcrun notarytool submit "build/Luego-macOS-notarize.zip" \
  --keychain-profile "AC_PASSWORD" \
  --wait
```

If notarization fails, check the log:
```bash
xcrun notarytool log <submission-id> --keychain-profile "AC_PASSWORD"
```

### 7. Staple Notarization Ticket
```bash
xcrun stapler staple "build/DerivedData/Build/Products/Release/Luego.app"
```

### 8. Create Distribution ZIP
```bash
ditto -c -k --keepParent "build/DerivedData/Build/Products/Release/Luego.app" "build/Luego-macOS-${VERSION}.zip"
```

### 9. Verify Gatekeeper
```bash
spctl --assess --type execute "build/DerivedData/Build/Products/Release/Luego.app"
```

### 10. Create Git Tag and GitHub Release
```bash
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin "v${VERSION}"

gh release create "v${VERSION}" \
  "build/Luego-macOS-${VERSION}.zip" \
  --title "Luego v${VERSION}" \
  --notes "## macOS Release

### Installation
1. Download \`Luego-macOS-${VERSION}.zip\`
2. Unzip and drag Luego.app to Applications
3. Open from Applications folder

### Features
- Full feature parity with iOS/iPadOS
- CloudKit sync between all platforms
- Notarized for seamless Gatekeeper approval"
```

### 11. Report Success
Output the GitHub release URL: `https://github.com/esoxjem/Luego/releases/tag/v${VERSION}`

## Troubleshooting

### Notarization fails with "no secure timestamp"
Ensure `OTHER_CODE_SIGN_FLAGS=--timestamp` is included in the build command.

### Notarization fails with "get-task-allow entitlement"
Ensure `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` is included in the build command.

### "No profile matching" error
Install the provisioning profile:
```bash
cp "Luegomac Profile.provisionprofile" ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/db76b5c4-138c-4fd7-afb4-3c4254d60bc3.provisionprofile
```

### "No Keychain password item found for profile: AC_PASSWORD"
Store notarization credentials:
```bash
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "QTZUF46V7A" \
  --password "APP_SPECIFIC_PASSWORD"
```
