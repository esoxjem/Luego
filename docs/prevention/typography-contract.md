# Typography Contract

Reading-list typography must flow through the shared semantic layer so navigation, row headers, metadata, and empty states stay aligned with app-wide text roles.

## Prevention Note

- Wire product text to `AppTextRole` (titles, subtitles, metadata, status, onboarding hints) and let `Font.app(_:)` resolve the actual font families/sizes.
- Use `AppNavigationStyle`/`AppNavigationAppearance` for nav-bar titles, large title states, and platform appearance hooks instead of raw font modifiers inside views.
- Keep every direct `Font`, `UIFont`, or `NSFont` initializer inside the central typography layer (`AppTypography.swift` and its helpers); nothing outside that layer should build fonts for reading-list text.
- If you need a new visual treatment for the reading list, add a role to the semantic layer first rather than injecting `.font(...)`, `.lora(...)`, `.nunito(...)`, or direct UIKit/AppKit font constructors locally.

## Exception Boundary

- Raw font construction (e.g., `Font`, `UIFont`, `NSFont`) is permitted only within the shared typography implementation that translates `AppTextRole` into concrete styles.
- Any feature view that touches product text must reference the semantic roles or the navigation helpers above; touching fonts directly in view code is a drift bug unless it is inside the centralized typography layer.
- Local SF Symbol sizing is outside this contract when no product text is being styled.
