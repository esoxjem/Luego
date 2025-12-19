# Bump Version

Bump the app version and/or build number in the Xcode project for both the main app and share extension.

## Instructions

1. Check the current version numbers in the project:
   - MARKETING_VERSION (e.g., 1.1) - the user-facing version
   - CURRENT_PROJECT_VERSION (e.g., 9) - the build number

2. Ask the user what they want to bump:
   - **Build only**: Increment CURRENT_PROJECT_VERSION by 1
   - **Patch version**: Increment patch (1.1 -> 1.2), reset build to 1
   - **Minor version**: Increment minor (1.1 -> 2.0), reset build to 1
   - **Major version**: Increment major (1.1 -> 2.0), reset build to 1

3. Update the version in `Luego.xcodeproj/project.pbxproj`:
   - Find all occurrences of MARKETING_VERSION and CURRENT_PROJECT_VERSION
   - Update them consistently across all build configurations for BOTH targets

4. Verify the changes look correct

5. Commit with message: `bump version` or `bump version to X.Y`

## Project File Location

The version numbers are in: `Luego.xcodeproj/project.pbxproj`

Look for lines like:
```
CURRENT_PROJECT_VERSION = 9;
MARKETING_VERSION = 1.1;
```

## Targets to Update

There are **two targets** that need version updates:

1. **Luego (main app)**
   - Bundle ID: `com.esoxjem.Luego`
   - Has Debug and Release configurations

2. **LuegoShareExtension (share extension)**
   - Bundle ID: `com.esoxjem.Luego.LuegoShareExtension`
   - Has Debug and Release configurations

## Important

- Always update ALL occurrences in the project file (4 total: 2 for main app + 2 for extension)
- Keep the main app and extension versions in sync
- The build number should always be incremented, even for version bumps
- After bumping, the Settings screen will automatically show the new version when the app is rebuilt
