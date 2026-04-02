# PadTrack Setup on Another Mac

This guide explains how to clone the repository on a different Mac, configure signing, launch the macOS helper, and install the iPad app.

## What You Need

- A Mac with full Xcode installed
- An iPad connected by USB for the first install
- Your own Apple Developer team selected in Xcode if you want to install the iPad app on a device

## 1. Clone the Repository

```bash
git clone <YOUR_REPOSITORY_URL>
cd ipad_mouse
```

## 2. Select Your Signing Team

If you are building on a different Mac or with a different Apple ID, update the Xcode team first:

```bash
bash ./scripts/set_team.sh YOUR_TEAM_ID
```

Example:

```bash
bash ./scripts/set_team.sh 8XGDZZB243
```

This updates both the iPad and macOS targets in `project.yml`.

## 3. Bootstrap the Project

```bash
bash ./scripts/bootstrap.sh
```

What this does:

- checks that Xcode is available
- generates `iPadMouse.xcodeproj`
- runs shared package tests
- opens the Xcode project unless `PADTRACK_NO_OPEN=1` is set

## 4. Launch the Mac Helper

```bash
bash ./scripts/run_mac_host.sh
```

This script:

- builds `MacPointerHost`
- copies it to `~/Applications/MacPointerHost.app`
- relaunches it

## 5. Grant macOS Permissions

On the Mac, allow:

- `Local Network`
- `Accessibility`

The app path that should be authorized is:

```text
~/Applications/MacPointerHost.app
```

## 6. Install PadTrack on iPad

Find your device ID if needed:

```bash
xcrun devicectl list devices
```

Then install the iPad app:

```bash
bash ./scripts/install_padtrack.sh DEVICE_ID
```

To install and try to launch immediately:

```bash
bash ./scripts/install_padtrack.sh DEVICE_ID --launch
```

## 7. Trust the App on iPad

After a fresh reinstall, you may need to trust the developer app again:

1. Open `Settings`
2. Open `General`
3. Open `VPN & Device Management`
4. Open `Developer App`
5. Trust your Apple account

## 8. Confirm You Are on the Latest UI

Open `PadTrack` and check the settings screen.

The app shows a visible screen version label such as:

```text
Screen Version v1.0.0 (2026-04-01e)
```

Use that label to verify that the iPad is not still running an older build.

## Daily Commands

Re-open the Xcode project:

```bash
bash ./scripts/open_xcode.sh
```

Rebuild and relaunch the Mac helper:

```bash
bash ./scripts/run_mac_host.sh
```

Reinstall the iPad app:

```bash
bash ./scripts/install_padtrack.sh DEVICE_ID
```

## Troubleshooting

If the Mac helper connects but does not move the cursor:

- confirm `Accessibility` is enabled for `~/Applications/MacPointerHost.app`
- confirm `Local Network` is enabled
- relaunch the helper with `bash ./scripts/run_mac_host.sh`

If the iPad app opens but still shows an older version label:

- uninstall `PadTrack`
- run `bash ./scripts/install_padtrack.sh DEVICE_ID`
- trust the developer app again if prompted

If the iPad app cannot launch after reinstall:

- trust the developer app again in `VPN & Device Management`

## Related Files

- [README.md](/Users/atsushi/Desktop/ipad_mouse/README.md)
- [PROJECT_STATUS.md](/Users/atsushi/Desktop/ipad_mouse/PROJECT_STATUS.md)
