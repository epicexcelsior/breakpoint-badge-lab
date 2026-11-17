# Testing contract

Run `./badge test` before publishing any package.

## Automated evidence

1. Compile the upstream patched Lua 5.5 runtime with its 32-bit number configuration.
2. Parse every shipped Lua file.
3. Check manifest fields, package limits, permission declarations, and file paths.
4. Run deterministic app tests with a badge API stand-in.
5. Run both apps on the official 2.4.0 firmware emulator.
6. Exercise keys, inspect errors, record memory, and save rendered screenshots.
7. Exchange Shipmates messages between two firmware instances through the emulator's radio transport.
8. Build deterministic ZIPs and verify their checksums.

The stand-in tests cover malformed messages, expiry, bounded peers, consent, pause/resume, and timer boundaries.
The emulator tests prove compatibility with the actual host and renderer.
Neither layer proves physical range, battery life, or the electrical capabilities of a USB port.

Generated evidence goes into `artifacts/`, which is excluded from source control.
CI uploads it separately. A release notes its exact checks and remaining physical limits.

## Physical acceptance: pending until a badge is available

1. Check the firmware version and microSD card with the console.
2. Load each app with the USB loader.
3. Check display readability, D-pad operation, SELECT, CANCEL, and BOOT.
4. Check Shipmates starts with sharing off after every launch.
5. Use two real badges. Match complementary topics and exchange a mutual hello.
6. Turn Wi-Fi off. Repeat the nearby exchange on the same mesh channel.
7. Walk apart. Check stale peers disappear and return after reconnection.
8. Put one badge to sleep or close its app. Check the other handles expiry.
9. Read `lua mem` and `heap` after each run.
10. Test app relaunch, stored preferences, and power-cycle recovery.
11. Measure runtime and temperature on battery.
12. Install and update through the official store before promoting a listing as store-tested.

The hardware console can inject `key select`, `key back`, and other keys.
`shot` supplies an actual LCD screenshot. Physical switch contacts still need a human press or a physical fixture.

Do not call the complete hardware release verified until this list has recorded evidence.
