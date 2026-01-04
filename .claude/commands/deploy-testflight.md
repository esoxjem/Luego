# Deploy to TestFlight

Archive the iOS app and upload it to TestFlight for beta testing.

## Prerequisites

Before running this command, ensure:
- You have a valid Apple Developer account configured in Xcode
- App Store Connect API credentials are set up (preferred) or you're signed into Xcode
- The app has been configured for App Store distribution in Xcode

## Instructions

### Step 1: Pre-flight Checks

1. Run the build to ensure there are no compilation errors:
   ```bash
   xcodebuild -project Luego.xcodeproj -scheme Luego -destination 'generic/platform=iOS' -configuration Release build
   ```

2. Check the current version numbers:
   ```bash
   grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Luego.xcodeproj/project.pbxproj | head -4
   ```

3. Ask the user if they want to bump the version before deploying (recommend yes if not already bumped)

### Step 2: Create Archive

Archive the app for distribution:

```bash
xcodebuild archive \
  -project Luego.xcodeproj \
  -scheme Luego \
  -destination 'generic/platform=iOS' \
  -archivePath build/Luego.xcarchive \
  -configuration Release \
  -allowProvisioningUpdates
```

### Step 3: Create Export Options Plist

Create an export options file at `build/ExportOptions.plist`:

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

### Step 4: Export and Upload to TestFlight

Export the archive and upload directly to App Store Connect:

```bash
xcodebuild -exportArchive \
  -archivePath build/Luego.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/Export \
  -allowProvisioningUpdates
```

This command will:
- Export the IPA
- Validate the build
- Upload to App Store Connect
- Make it available for TestFlight (after Apple's processing)

### Step 5: Cleanup (Optional)

After successful upload, optionally clean up build artifacts:

```bash
rm -rf build/Luego.xcarchive build/Export build/ExportOptions.plist
```

## Troubleshooting

### Authentication Issues

If automatic authentication fails, you may need to use App Store Connect API keys:

1. Create an API key in App Store Connect → Users and Access → Keys
2. Download the .p8 file
3. Set environment variables or use the `-authenticationKeyPath`, `-authenticationKeyID`, and `-authenticationKeyIssuerID` flags

### Provisioning Issues

If you see provisioning errors:
1. Open Xcode and go to Signing & Capabilities
2. Ensure automatic signing is enabled
3. Verify your Apple Developer account has the necessary permissions

### Build Number Conflicts

If App Store Connect rejects the build due to duplicate build number:
1. Run `/bump-version` first to increment the build number
2. Then retry the deployment

## Post-Deployment

After successful upload:
1. Log into App Store Connect
2. Wait for Apple to process the build (usually 10-30 minutes)
3. Add the build to TestFlight testing groups
4. Optionally add What's New notes for testers

## Project Details

- **Bundle ID**: com.esoxjem.Luego
- **Scheme**: Luego
- **Project**: Luego.xcodeproj
