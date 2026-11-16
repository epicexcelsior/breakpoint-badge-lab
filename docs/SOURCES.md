# Official sources

Retrieved November 16, 2026 UTC.

| Source | Local copy | Purpose |
| --- | --- | --- |
| [Solana OS repository](https://github.com/solana-foundation/solana-os) | `docs/upstream/solana-os/` | Complete public documentation tree, examples, README, changelog, license, and ESP-IDF pin |
| [Lua API](https://solana.com/breakpoint/badge/apps/docs) | `docs/upstream/solana-os/docs/LUA_API.md` | App lifecycle, package, API, permissions, and console |
| [Connectivity guide](https://solana.com/breakpoint/badge/apps/docs/connectivity) | `docs/upstream/solana-os/docs/CONNECTIVITY.md` | Radio choices and limits |
| [C API](https://solana.com/breakpoint/badge/apps/docs/c) | `docs/upstream/live/C_API.md` | C/Wasm/native options |
| [C SDK ZIP](https://solana.com/breakpoint/badge/sdk/solana-os-c-sdk.zip) | `sdk/solana-os-c-sdk.zip` | Headers, compiler scripts, examples, benchmarks, and tests |
| [Hardware walkthrough](https://solana.com/breakpoint/badge) | `.cache/docs/HARDWARE.txt` on the original workstation | Hardware, pinout, dimensions, and USB wiring |
| [Official emulator](https://solana.com/breakpoint/badge/emulator) | `vendor/emulator/` | Actual firmware, compiled for an emulated board |
| [Quest authoring](https://solana.com/breakpoint/badge/apps/docs/quests) | `docs/upstream/solana-os/docs/QUESTS.md` | Quests and test/publish permissions |
| [Gossip manual](https://solana.com/breakpoint/badge/guide/gossip) | Local documentation cache | Optional platform game mechanics |

The upstream Git commit and every redistributed snapshot hash are in `docs/sources.json`.
The emulator has a separate lock file at `tools/emulator-lock.json`.

## Version discrepancy

The public Git snapshot reports Solana OS 2.2.0 at `7c22c44d8db16dd8c6f90d5f61ead8eba055b973`.
The live emulator reports 2.4.0. The live documentation covers C apps from 2.3.0 and Gossip from 2.4.0.
Keep these as distinct evidence sets. Neither app depends on C, Gossip, background services, or private server APIs.

The parent badge website/server repository and its server API contracts are private.
They are not included in the public firmware repository. No private documentation was accessed.

Plain HTTP requests to the website returned 429 challenges in this environment.
Website-only documents and the emulator were retrieved through a normal browser session.
The public Git repository remains the easiest reference source for agents.
