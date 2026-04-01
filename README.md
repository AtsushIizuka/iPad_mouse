# PadTrack

PadTrack turns an iPad into a wireless trackpad for a Mac. The repository contains:

- `SharedCore`: shared input events, transport abstraction, and the MultipeerConnectivity transport.
- `PadTrack`: the iPad app that captures touch gestures and sends pointer events.
- `MacPointerHost`: the macOS menu bar app that receives events and drives the system pointer.

## Project layout

- `Package.swift` builds and tests `SharedCore`.
- `project.yml` defines the XcodeGen project for the iPad and macOS apps.
- `Apps/PadTrack` contains the iPad SwiftUI app.
- `Apps/MacPointerHost` contains the macOS menu bar host app.

## Setup

1. Install full Xcode and point `xcode-select` at it.
2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if it is not already available.
3. Run `xcodegen generate` in the repository root.
4. Open the generated `iPadMouse.xcodeproj`.
5. Build `MacPointerHost` for your Mac and `PadTrack` for an iPad.

## Permissions

- `PadTrack` needs local network access for Bonjour and MultipeerConnectivity discovery.
- `MacPointerHost` needs local network access and Accessibility access.
- `MacPointerHost` is configured as an agent app (`LSUIElement`) so it lives in the menu bar.

## Validation

Run the shared tests with:

```bash
swift test
```

## Ongoing Status

For the current Japanese project memo, launch commands, file responsibilities, and known issues, see:

- `PROJECT_STATUS.md`
