# macOS release workflow

## Inputs

- Version string in `YYYY.MM.DD` format.
- Optional explicit derived data path (recommended): `build/DerivedData-release-${VERSION}`.
- GitHub owner/repo for this checkout. Resolve it from the current remote before generating appcast URLs.

## Prerequisites

1. Install Developer ID certificate in Keychain: `Developer ID Application: Arun Sasidharan (QTZUF46V7A)`.
2. Install provisioning profile at `~/Library/Developer/Xcode/UserData/Provisioning Profiles/db76b5c4-138c-4fd7-afb4-3c4254d60bc3.provisionprofile`.
3. Store notarization credentials:
   ```bash
   xcrun notarytool store-credentials "AC_PASSWORD"
   ```
4. Confirm Sparkle signing key is available locally:
   ```bash
   <generate_keys_path> --account ed25519 -p
   ```

## Steps

1. Update version before release build:
   ```bash
   sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${VERSION};/g" Luego.xcodeproj/project.pbxproj
   sed -i '' 's/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = 1;/g' Luego.xcodeproj/project.pbxproj
   grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Luego.xcodeproj/project.pbxproj | head -6
   git add Luego.xcodeproj/project.pbxproj
   git commit -m "chore: bump version to ${VERSION}"
   ```
2. Build signed Release app with explicit derived data:
   ```bash
   DERIVED_DATA_PATH="build/DerivedData-release-${VERSION}"

   xcodebuildmcp macos build \
     --configuration Release \
     --derived-data-path "${DERIVED_DATA_PATH}" \
     --extra-args CODE_SIGN_STYLE=Manual \
     --extra-args "CODE_SIGN_IDENTITY=Developer ID Application: Arun Sasidharan (QTZUF46V7A)" \
     --extra-args DEVELOPMENT_TEAM=QTZUF46V7A \
     --extra-args CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
     --extra-args OTHER_CODE_SIGN_FLAGS=--timestamp
   ```
3. Verify app signature and entitlements:
   ```bash
   APP_PATH="${DERIVED_DATA_PATH}/Build/Products/Release/Luego.app"

   codesign --verify --deep --strict "${APP_PATH}"
   if codesign -d --entitlements - "${APP_PATH}" 2>&1 | grep -qi "get-task-allow"; then
     echo "Unexpected debug entitlement found in Release app"
     exit 1
   fi
   codesign -d --entitlements - "${APP_PATH}" 2>&1 | grep -q "icloud-container-identifiers"
   ```
4. Verify Sparkle helper signatures and remediate ad-hoc signatures if needed:
   ```bash
   SPARKLE_FW="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
   HELPER_BIN="${SPARKLE_FW}/Versions/B/Autoupdate"

   if codesign -dvv "${HELPER_BIN}" 2>&1 | grep -q "Signature=adhoc"; then
     XCENT_PATH="${DERIVED_DATA_PATH}/Build/Intermediates.noindex/Luego.build/Release/Luego.build/Luego.app.xcent"
     if [ ! -f "${XCENT_PATH}" ]; then
       echo "Missing entitlements file: ${XCENT_PATH}"
       exit 1
     fi

     codesign --force --deep --options runtime --timestamp \
       --sign "Developer ID Application: Arun Sasidharan (QTZUF46V7A)" \
       "${SPARKLE_FW}"

     # Preserve entitlements when re-signing the outer app.
     # Re-signing without --entitlements strips iCloud entitlements and can crash SwiftData+CloudKit at launch.
     codesign --force --options runtime --timestamp --entitlements "${XCENT_PATH}" --generate-entitlement-der \
       --sign "Developer ID Application: Arun Sasidharan (QTZUF46V7A)" \
       "${APP_PATH}"

     codesign --verify --deep --strict "${APP_PATH}"
     codesign -d --entitlements - "${APP_PATH}" 2>&1 | grep -q "icloud-container-identifiers"
   fi
   ```
5. Package for notarization:
   ```bash
   ditto -c -k --keepParent "${APP_PATH}" "build/Luego-macOS-notarize-${VERSION}.zip"
   ```
6. Submit notarization and wait:
   ```bash
   xcrun notarytool submit "build/Luego-macOS-notarize-${VERSION}.zip" \
     --keychain-profile "AC_PASSWORD" \
     --wait
   ```
7. Staple notarization ticket:
   ```bash
   xcrun stapler staple "${APP_PATH}"
   ```
8. Create distribution archive:
   ```bash
   ditto -c -k --keepParent "${APP_PATH}" "build/Luego-macOS-${VERSION}.zip"
   ```
9. Verify Gatekeeper:
   ```bash
   spctl --assess --type execute --verbose=4 "${APP_PATH}"
   ```
10. Generate appcast deterministically:
   ```bash
   TOOL_CANDIDATES=$(find "${DERIVED_DATA_PATH}" -type f -path "*/Sparkle/bin/generate_appcast")
   CANDIDATE_COUNT=$(printf '%s\n' "${TOOL_CANDIDATES}" | sed '/^$/d' | wc -l | tr -d ' ')

   if [ "${CANDIDATE_COUNT}" != "1" ]; then
     echo "Expected exactly 1 generate_appcast tool, found ${CANDIDATE_COUNT}"
     exit 1
   fi

   GENERATE_APPCAST_TOOL="$(cd "$(dirname "${TOOL_CANDIDATES}")" && pwd)/$(basename "${TOOL_CANDIDATES}")"
   echo "generate_appcast: ${GENERATE_APPCAST_TOOL}"

   EXPECTED_PUB_KEY=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "${APP_PATH}/Contents/Info.plist")
   ACTUAL_PUB_KEY=$("${GENERATE_APPCAST_TOOL%/*}/generate_keys" --account ed25519 -p)

   if [ "${EXPECTED_PUB_KEY}" != "${ACTUAL_PUB_KEY}"; then
     echo "Sparkle key mismatch: app=${EXPECTED_PUB_KEY} keychain=${ACTUAL_PUB_KEY}"
     echo "Import matching private key into keychain or update SUPublicEDKey and rebuild before publish"
     exit 1
   fi

   REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner)
   APPCAST_DIR="build/appcast-${VERSION}"
   mkdir -p "${APPCAST_DIR}"
   cp -f "build/Luego-macOS-${VERSION}.zip" "${APPCAST_DIR}/"

   (
     cd "${APPCAST_DIR}"
     "${GENERATE_APPCAST_TOOL}" \
       --download-url-prefix "https://github.com/${REPO_SLUG}/releases/download/v${VERSION}/" \
       .
   )

   test -f "${APPCAST_DIR}/appcast.xml"
   grep -q "sparkle:edSignature" "${APPCAST_DIR}/appcast.xml"
   ```
11. Tag and publish GitHub release:
   ```bash
   git push origin main
   git tag -a "v${VERSION}" -m "Release v${VERSION}"
   git push origin "v${VERSION}"

   NOTES_FILE=$(mktemp)
   cat > "${NOTES_FILE}" <<EOF_NOTES
## macOS Release

### Installation
1. Download Luego-macOS-${VERSION}.zip
2. Unzip and drag Luego.app to Applications
3. Open from Applications folder

### Features
- Sparkle updates enabled for macOS
- CloudKit sync between all platforms
- Notarized for seamless Gatekeeper approval
EOF_NOTES

   gh release create "v${VERSION}" \
     "build/Luego-macOS-${VERSION}.zip" \
     "build/appcast-${VERSION}/appcast.xml#appcast.xml" \
     --title "Luego v${VERSION}" \
     --notes-file "${NOTES_FILE}"

   rm -f "${NOTES_FILE}"
   ```

## Critical constraints

- Keep `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` to prevent debug entitlement leakage.
- Keep `OTHER_CODE_SIGN_FLAGS=--timestamp` for notarization acceptance.
- Do not pass `PROVISIONING_PROFILE_SPECIFIER` on command line because it applies globally.
- Resolve the GitHub release owner from the current repo instead of hard-coding it.
- Do not publish a release without `appcast.xml` when `SUFeedURL` points to GitHub release assets.
- Keep Sparkle private key material out of git; use keychain or temporary local files only.
- Report the Xcode `LSApplicationCategory` warning as a release hardening item even when the build succeeds.

## Failure handling

- If notarization fails, fetch logs:
  ```bash
  xcrun notarytool log <submission-id> --keychain-profile "AC_PASSWORD"
  ```
- If notarization reports Sparkle helper errors (`Autoupdate`, `Updater`, `Downloader.xpc`, `Installer.xpc`), re-sign `Sparkle.framework` and then re-sign the `.app` before re-submitting.
- If Sparkle key import fails with conflicting key, remove old Sparkle keychain item and re-import:
  ```bash
  security delete-generic-password -l "Private key for signing Sparkle updates"
  ```
- If key mismatch persists between `SUPublicEDKey` and keychain public key, update `Configuration/Luego-*.xcconfig`, rebuild, notarize, and regenerate appcast.
