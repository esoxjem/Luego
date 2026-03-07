---
name: deploy-testflight
description: iOS TestFlight deployment workflow for Luego. Use when archiving and uploading iOS builds to App Store Connect, troubleshooting signing/authentication/provisioning issues, or resolving duplicate build-number rejections.
---

# deploy-testflight

Archive and upload Luego iOS builds to TestFlight with deterministic preflight checks.

## Workflow

1. Run preflight checks.
   - Build release target:
     ```bash
     xcodebuild -project Luego.xcodeproj -scheme Luego -destination 'generic/platform=iOS' -configuration Release build
     ```
   - Inspect versions:
     ```bash
     grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Luego.xcodeproj/project.pbxproj | head -4
     ```
   - Bump version if needed by running `bump-version`.
2. Archive app:
   ```bash
   xcodebuild archive \
     -project Luego.xcodeproj \
     -scheme Luego \
     -destination 'generic/platform=iOS' \
     -archivePath build/Luego.xcarchive \
     -configuration Release \
     -allowProvisioningUpdates
   ```
3. Create `build/ExportOptions.plist`:
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
4. Export and upload:
   ```bash
   xcodebuild -exportArchive \
     -archivePath build/Luego.xcarchive \
     -exportOptionsPlist build/ExportOptions.plist \
     -exportPath build/Export \
     -allowProvisioningUpdates
   ```
5. Report result.
   - Confirm archive path, export path, and upload status.
   - Return any actionable error output if upload fails.
6. Optionally clean artifacts:
   ```bash
   rm -rf build/Luego.xcarchive build/Export build/ExportOptions.plist
   ```

## Troubleshooting checklist

- Authentication failures: use App Store Connect API key flags if automatic auth fails.
- Provisioning failures: verify signing capabilities and account permissions in Xcode.
- Duplicate build number: run `bump-version` and retry upload.
