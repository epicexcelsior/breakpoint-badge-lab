# Breakpoint Badge Lab

Useful, small apps for the Solana Breakpoint 2026 hardware badge.

**Sideband** helps people find each other through a shared ask and offer. It uses the badge mesh without a backend.
**Pocket Pause** offers a quiet breathing guide and a focus timer. It works offline.

This repository includes source, official documentation, the C SDK, and the official firmware emulator.
No wallet, token, app account, or payment is required by either app.

## Start

Prerequisites: Python 3.10+, Node.js 22+, and a C compiler (`cc`). No npm packages are required.

```sh
./badge doctor
./badge test
./badge package
./badge demo
```

Open the local address printed by `demo`. It runs two virtual badges through the actual firmware.
The demo uses a local identity stand-in. It does not contact the conference server.

For continuous iteration:

```sh
./badge dev
```

Each saved app change runs checks and rebuilds packages. Demo badges reload after a successful check.

## Load a badge later

Use the [official submit page](https://solana.com/breakpoint/badge/apps/submit) to upload an app ZIP and select **Run on badge**.
This needs desktop Chrome or Edge, a USB data cable, a microSD card, and supported Solana OS firmware.

For scripted loading:

```sh
python3 -m pip install -r requirements-usb.txt
./badge usb sideband --port /dev/ttyUSB0
./badge usb pocket-pause --port /dev/ttyUSB0
```

The loader checks the firmware, closes the running app, copies changed files with SHA-256 verification, and launches the app.
It preserves app storage. It never flashes firmware.

## Evidence and release

- [Hardware, platform, and audio findings](docs/research/HARDWARE.md)
- [Ideas and release scope](docs/research/IDEAS.md)
- [Wireless development and distribution](docs/DISTRIBUTION.md)
- [Testing and physical acceptance](docs/TESTING.md)
- [Official references and snapshot provenance](docs/SOURCES.md)
- [Tonight's release procedure](docs/RELEASE.md)

`./badge test` checks the badge's patched Lua 5.5 parser, app behavior, packaging rules, and actual firmware execution.
Physical radio range, power use, and USB loading remain separate checks until a badge is connected.

## License

Project code is MIT. Third-party code and firmware retain their original notices. See [THIRD_PARTY.md](THIRD_PARTY.md).
