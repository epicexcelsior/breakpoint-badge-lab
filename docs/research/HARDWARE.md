# Hardware and practical limits

Target: the **Breakpoint 2026 ESP32-C5 badge**, verified against the [official hardware walkthrough](https://solana.com/breakpoint/badge).
An earlier badge requires a separate assessment.

| Resource | Verified capability | App consequence |
| --- | --- | --- |
| Compute | Single-core 240 MHz RISC-V ESP32-C5 | Suitable for small interactive apps |
| Memory | 16 MB flash, 8 MB PSRAM | Lua heap up to 6 MB on Solana OS 2.0.0+ |
| Display | 320×240 ILI9341 TFT | App content area is 320×218 beneath the status bar |
| Controls | D-pad, SELECT, CANCEL, rear BOOT and reset | Use short button-driven flows |
| LEDs | Eight WS2812B RGB LEDs | OS brightness cap applies. Avoid flashing by default |
| Storage | microSD, FAT filesystem | A working card is required for installed apps |
| Wireless | Dual-band Wi-Fi 6, BLE 5, ESP-NOW | Internet calls, BLE gadgets, and nearby badge apps |
| Other radio | IEEE 802.15.4 | Hardware exists. No documented sandbox app API |
| Power | 1000 mAh LiPo | Runtime and charging behavior require physical measurement |
| USB-C | CH340C USB-to-UART bridge | Flashing and serial console, 115200 baud |

## Audio decision

The USB-C receptacle does not make this badge a general USB host.
The documented data path is CH340C to UART0. No supported USB Audio host API, microphone, speaker, headphone output, or audio codec is documented.

Direct USB-C earbuds are therefore outside the stock-board app path.
A custom cable, soldering modification, external codec, or custom firmware requires separate electrical verification.
The MCU's reserved USB pins do not establish an accessible USB host port.

A practical sound extension uses a phone or laptop for microphone input, audio processing, and earbud output.
The badge can send small BLE control messages. This is BLE data control, not Bluetooth headset streaming.
Browser Bluetooth support and real peripheral behavior still require device tests.

## Networking budgets

The [official Lua API](https://solana.com/breakpoint/badge/apps/docs) caps mesh messages at 200 JSON bytes and four per second.
The [connectivity guide](https://solana.com/breakpoint/badge/apps/docs/connectivity) describes lossy delivery and a shared radio.
Sideband repeats absolute state every three seconds instead of sending one-shot increments.

BLE permits one connection and values up to 244 bytes. It has no built-in pairing or encryption in this API.
Wi-Fi HTTP calls go through the badge server and an app host allowlist.
One direct WebSocket is supported. Other badge-server calls wait while it is open.

## Developer options

- Lua is the smallest path for UI, social state, and network calls.
- C apps compile to Wasm and store-signed native code on supported firmware. Use C for heavy computation.
- Custom ESP-IDF firmware exposes more hardware but replaces the stock image and changes the distribution path.
- The firmware emulator executes actual app-host code. Its radio, battery, SD, and scheduler remain simulated.

The earliest API floor for these apps is Solana OS 0.5.0 with `require` support.
The current 2.4.0 emulator is the tested runtime. Use current stock firmware for the first physical release.
