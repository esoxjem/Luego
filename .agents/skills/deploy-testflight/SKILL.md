---
name: deploy-testflight
description: iOS TestFlight deployment workflow for Luego using Xcode automatic signing and Xcode-authenticated upload. Use when archiving and uploading iOS builds to TestFlight, troubleshooting automatic signing/authentication/provisioning issues, or resolving duplicate build-number rejections by updating the date-based version before incrementing the build number.
---

# deploy-testflight

Archive and upload Luego iOS builds to TestFlight with deterministic preflight checks and Xcode-managed automatic signing.

## Workflow

1. Run preflight checks.
   - Build release target:
     ```bash
     xcodebuild -project Luego.xcodeproj -scheme Luego -destination 'generic/platform=iOS' -configuration Release build
     ```
   - Inspect versions and signing:
     ```bash
     grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION|CODE_SIGN_STYLE|DEVELOPMENT_TEAM" Luego.xcodeproj/project.pbxproj | head -12
     ```
   - Confirm Xcode is logged into the correct Apple Developer account and the `Luego` scheme resolves with automatic signing.
2. Update version metadata before archiving.
   ```bash
   TODAY=$(date +%Y.%m.%d)
   CURRENT_VERSION=$(grep -m1 "MARKETING_VERSION =" Luego.xcodeproj/project.pbxproj | sed -E 's/.*MARKETING_VERSION = ([0-9.]+);/\1/')
   CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION =" Luego.xcodeproj/project.pbxproj | sed -E 's/.*CURRENT_PROJECT_VERSION = ([0-9]+);/\1/')

   if [ "${CURRENT_VERSION}" != "${TODAY}" ]; then
     sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${TODAY};/g" Luego.xcodeproj/project.pbxproj
     CURRENT_BUILD=0
   fi

   NEXT_BUILD=$((CURRENT_BUILD + 1))
   sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${NEXT_BUILD};/g" Luego.xcodeproj/project.pbxproj

   grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Luego.xcodeproj/project.pbxproj | head -12
   ```
   - Update the version date first, then increment the build number.
   - When the date changes, the first build for that date must become `1`.
   - Keep all targets and configurations in sync.
3. Archive app with automatic signing:
   ```bash
   xcodebuild archive \
     -project Luego.xcodeproj \
     -scheme Luego \
     -destination 'generic/platform=iOS' \
     -archivePath build/Luego.xcarchive \
     -configuration Release \
     -allowProvisioningUpdates
   ```
4. Create `build/ExportOptions.plist`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>destination</key>
       <string>upload</string>
       <key>method</key>
       <string>app-store-connect</string>
       <key>signingStyle</key>
       <string>automatic</string>
       <key>uploadSymbols</key>
       <true/>
       <key>manageAppVersionAndBuildNumber</key>
       <false/>
   </dict>
   </plist>
   ```
5. Export and upload with the Xcode-authenticated session:
   ```bash
   xcodebuild -exportArchive \
     -archivePath build/Luego.xcarchive \
     -exportOptionsPlist build/ExportOptions.plist \
     -exportPath build/Export \
     -allowProvisioningUpdates
   ```
   - Do not use `asc` for signing, provisioning, or upload in this workflow.
6. Report result.
   - Confirm archive path, export path, and upload status.
   - Return final `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
   - Return any actionable error output if upload fails.
7. Optionally clean artifacts:
   ```bash
   rm -rf build/Luego.xcarchive build/Export build/ExportOptions.plist
   ```

## Troubleshooting checklist

- Authentication failures: verify the correct Apple ID is signed into Xcode, that Xcode can access the team, and that any stale account session has been refreshed before retrying.
- Provisioning failures: verify signing capabilities and account permissions in Xcode.
- Duplicate build number: re-run the versioning step so the date is current before incrementing the build number, then retry upload.
