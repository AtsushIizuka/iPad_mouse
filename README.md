# PadTrack

PadTrack turns an iPad into a wireless trackpad for a Mac.

The repo contains:

- `SharedCore`: shared input events, transport abstraction, and MultipeerConnectivity transport
- `PadTrack`: the iPad SwiftUI app
- `MacPointerHost`: the macOS menu bar receiver app

## Quick Start

1. Clone the repository.
2. Run `bash ./scripts/bootstrap.sh`
3. Run `bash ./scripts/run_mac_host.sh`
4. Open `PadTrack` from Xcode or install it with `bash ./scripts/install_padtrack.sh <DEVICE_ID>`

If you need to use your own Apple signing team on another Mac:

```bash
bash ./scripts/set_team.sh YOUR_TEAM_ID
bash ./scripts/bootstrap.sh
```

## Repository Layout

- `Apps/PadTrack`: iPad app sources
- `Apps/MacPointerHost`: macOS app sources
- `Sources/SharedCore`: shared package code
- `Tests/SharedCoreTests`: shared package tests
- `docs/SETUP_ON_ANOTHER_MAC.md`: English setup and permission guide
- `docs/LAUNCH_COMMANDS.md`: copy-paste launch, reinstall, and restart commands
- `scripts/`: helper scripts for bootstrap, signing, build, and launch
- `PROJECT_STATUS.md`: ongoing Japanese project memo

## Commands

Run shared tests:

```bash
xcrun swift test
```

Open the Xcode project:

```bash
bash ./scripts/open_xcode.sh
```

## Notes

- `MacPointerHost` needs Accessibility and Local Network permission.
- `PadTrack` needs Local Network permission.
- `MacPointerHost` is an agent app (`LSUIElement`), so it runs from the menu bar.

For the full setup flow on a fresh Mac, see [docs/SETUP_ON_ANOTHER_MAC.md](/Users/atsushi/Desktop/ipad_mouse/docs/SETUP_ON_ANOTHER_MAC.md).
