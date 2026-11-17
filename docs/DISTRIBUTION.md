# Distribution and wireless iteration

## Recommended release path

Use the [official App Store](https://solana.com/breakpoint/badge/apps) for attendee installs.
Users install with Wi-Fi from the App Store app on their badge.
Use GitHub release ZIPs for downloads, review, backups, and developer sideloads.

The [submit form](https://solana.com/breakpoint/badge/apps/submit) accepts an app folder or ZIP with `app.json` and `main.lua`.
Publication requires a badge-site account with X linked. Building and trying an app do not require publication.
The store compiles Lua source and runs an automatic code check. A flagged submission waits for an organizer.
Approval timing is outside this repository's control.

Keep the first apps free, unlisted during initial store testing when that option is available, and free of reward permissions.
Do not add `lamps.award` for launch: organizer award caps and reviews create an extra dependency.
Store updates download changed files and preserve app storage.

## What is automatic

| Task | Current implementation or supported path |
| --- | --- |
| Local checks | `./badge test` |
| Repeat checks on save | `./badge dev` |
| App ZIPs and checksums | `./badge package` |
| Actual firmware tests | `./badge emulator` |
| Two-badge local demo | `./badge demo` |
| USB app loading | `./badge usb <app> --port <port>` |
| Physical logs, keys, screenshots | `./badge console --port <port> ...` |
| CI artifacts | GitHub Actions checks and ZIP artifact upload |
| Public download | GitHub release assets |
| Attendee wireless install | Official App Store over Wi-Fi, initiated by the attendee |

## Wireless development

Stock public Solana OS exposes its developer console over UART/USB.
No supported general wireless remote-console or arbitrary-code hot-loader was found in the public 2.2.0 source or documented API.
The platform's Wi-Fi firmware updater is distinct from an app development console.

The dependable unattended setup uses an owned badge connected by USB to an owned laptop or small computer.
Run the loader and console there over an authenticated remote shell.
This supplies reliable logs and screenshots while the badge itself remains untethered from the developer's workstation.
Use one process per serial port. The loader and console must not run concurrently.

A BLE phone/laptop controller is a separate app-level feature.
It can control predefined behavior inside an installed app. It does not grant the app permission to install other apps.
The current apps do not expose remote code execution or an unauthenticated management service.

## Sharing between people

Shipmates's invite QR opens the public release page.
After official store publication, replace that target with the verified store listing and rebuild.
Do not point users to an app ID that is not published.

Nearby mesh messages reach the same app on other badges. They do not install the app.
Gossip is the platform's separate game/program mechanism, not authorization for silently installing our apps.
Quests and beacons have their own documented platform roles and limits.

Every installation remains an owner's choice. An organizer-authorized fleet rollout requires a separate, explicit device-management arrangement.

## Recovery

The USB loader verifies complete files through `lua recv` and SHA-256.
Multi-file developer sideloads are not a transactional app-store update.
If a transfer fails, keep the app closed, rerun the loader, and verify the package before running it.
App-store updates provide the platform's staged-folder swap and recovery behavior.

The loader never erases the card or replaces the operating system.
For firmware recovery, use the [official stock firmware flasher](https://solana.com/breakpoint/badge/stock).
