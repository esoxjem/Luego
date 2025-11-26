# Luego
A minimal, offline read-it-later iOS app. I've built this app as an alternative to [Pocket](https://getpocket.com/) using [Claude Code](CLAUDE.md). [Try it on TestFlight](https://testflight.apple.com/join/XCNeNBsA).
<p>
  <img src="docs/screenshots/App Store Screenshot 1.jpg" width="180" />
  <img src="docs/screenshots/App Store Screenshot 2.jpg" width="180" />
  <img src="docs/screenshots/App Store Screenshot 3.jpg" width="180" />
  <img src="docs/screenshots/App Store Screenshot 4.jpg" width="180" />
</p>
## Architecture

Luego follows an opinionated Clean Architecture implementation organized by feature. See [ARCHITECTURE.md](ARCHITECTURE.md).


## Features

- **Quick Article Saving**: Save articles via URL or iOS Share Extension
- **Automatic Metadata Extraction**: Fetch titles, descriptions, and images automatically via OpenGraph tags
- **Offline Reading**: Access saved articles with last read position
- **Clean Reader View**: Distraction-free reading experience with Markdown rendering
- **SwiftData Integration**: Modern data persistence with SwiftData


## Requirements

- iOS 26.0+
- Xcode 26.0+
- Swift 5.0+

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/esoxjem/luego.git
cd luego
```

### 2. Open in Xcode

```bash
open Luego.xcodeproj
```

### 3. Configure Signing

Before building, you need to configure code signing:

1. Select the **Luego** project in the navigator
2. Select the **Luego** target
3. Go to **Signing & Capabilities** tab
4. Select your **Team** from the dropdown
5. Repeat for the **LuegoShareExtension** target if needed

The bundle identifier can be changed to your own if desired.
