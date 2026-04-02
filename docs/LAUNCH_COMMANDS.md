# PadTrack Launch Commands

This file collects the commands used to launch, rebuild, and reinstall the current PadTrack setup.

## Repository Root

```bash
cd /Users/atsushi/Desktop/ipad_mouse
```

## Open the Project

```bash
bash ./scripts/open_xcode.sh
```

## Bootstrap the Repository

Use this on a fresh clone or after project setup changes.

```bash
bash ./scripts/bootstrap.sh
```

## Launch the Mac Helper

Recommended:

```bash
bash ./scripts/run_mac_host.sh
```

Direct app launch:

```bash
open /Users/atsushi/Applications/MacPointerHost.app
```

## Restart the Mac Helper

```bash
osascript -e 'tell application "MacPointerHost" to quit'
open /Users/atsushi/Applications/MacPointerHost.app
```

## Build the Mac Helper Only

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project /Users/atsushi/Desktop/ipad_mouse/iPadMouse.xcodeproj \
  -scheme MacPointerHost \
  -configuration Debug \
  -derivedDataPath /Users/atsushi/Desktop/ipad_mouse/.xcodebuild/DerivedData \
  build
```

## Install PadTrack on iPad

Recommended:

```bash
bash ./scripts/install_padtrack.sh 00008120-001844A13EA00032
```

Install and try to launch:

```bash
bash ./scripts/install_padtrack.sh 00008120-001844A13EA00032 --launch
```

## Launch PadTrack on iPad

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device process launch \
  --device 00008120-001844A13EA00032 \
  com.atsushi.PadTrack
```

## Uninstall PadTrack from iPad

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device uninstall app \
  --device 00008120-001844A13EA00032 \
  com.atsushi.PadTrack
```

## Install PadTrack Directly from the Built App

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device install app \
  --device 00008120-001844A13EA00032 \
  /Users/atsushi/Desktop/ipad_mouse/.xcodebuild/DerivedData/Build/Products/Debug-iphoneos/PadTrack.app
```

## Build and Install PadTrack with xcodebuild

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project /Users/atsushi/Desktop/ipad_mouse/iPadMouse.xcodeproj \
  -scheme PadTrack \
  -configuration Debug \
  -destination 'id=00008120-001844A13EA00032' \
  -derivedDataPath /Users/atsushi/Desktop/ipad_mouse/.xcodebuild/DerivedData \
  build install
```

## Run Shared Tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

## Notes

- Current iPad device ID: `00008120-001844A13EA00032`
- Current Mac helper install path: `/Users/atsushi/Applications/MacPointerHost.app`
- After reinstalling `PadTrack`, you may need to trust the developer app again on the iPad.
