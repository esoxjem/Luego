# Bump Version

Bump the app version and/or build number in the Xcode project for both the main app and share extension.

## Versioning Strategy

This project uses **CalVer** (Calendar Versioning) with the format `YYYY.MM.DD`:
- **MARKETING_VERSION**: Date-based version (e.g., 2025.01.29)
- **CURRENT_PROJECT_VERSION**: Build number, incremented for same-day releases

## Instructions

1. Check the current version numbers in the project:
   - MARKETING_VERSION (e.g., 2025.01.29) - the user-facing version
   - CURRENT_PROJECT_VERSION (e.g., 1) - the build number

2. Ask the user what they want to bump:
   - **Build only**: Increment CURRENT_PROJECT_VERSION by 1 (for same-day releases)
   - **New version**: Set MARKETING_VERSION to today's date (YYYY.MM.DD), reset build to 1

3. Update the version in `Luego.xcodeproj/project.pbxproj`:
   - Find all occurrences of MARKETING_VERSION and CURRENT_PROJECT_VERSION
   - Update them consistently across all build configurations for ALL targets

4. Verify the changes look correct

5. Commit with message: `bump version` or `bump version to YYYY.MM.DD`

## Project File Location

The version numbers are in: `Luego.xcodeproj/project.pbxproj`

Look for lines like:
```
CURRENT_PROJECT_VERSION = 1;
MARKETING_VERSION = 2025.01.29;
```

## Targets to Update

There are **three targets** that need version updates:

1. **Luego (main app)**
   - Bundle ID: `com.esoxjem.Luego`
   - Has Debug and Release configurations

2. **LuegoShareExtension (share extension)**
   - Bundle ID: `com.esoxjem.Luego.LuegoShareExtension`
   - Has Debug and Release configurations

3. **LuegoTests (test target)**
   - Bundle ID: `com.esoxjem.Luego.LuegoTests`
   - Has Debug and Release configurations

## Important

- Always update ALL occurrences in the project file (6 total: 2 for main app + 2 for extension + 2 for tests)
- Keep all targets' versions in sync
- For same-day releases, only increment the build number
- After bumping, the Settings screen will automatically show the new version when the app is rebuilt
