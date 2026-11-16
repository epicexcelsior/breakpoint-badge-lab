# Badge project

- Ship Lua apps for stock Solana OS. Keep each app in `apps/<folder>/`.
- Treat `vendor/` and `docs/upstream/` as read-only snapshots. Record source hashes in `docs/sources.json`.
- The live firmware emulator is 2.4.0. The public Lua source snapshot is 2.2.0. Test both explicitly.
- Use only documented APIs. Never assume the USB-C serial bridge supports USB audio or host mode.
- Run `./badge test` and `./badge package` before a release. Run `./badge verify` to check archived sources.
- Run `./badge emulator` for actual firmware behavior. Mock tests alone cannot prove API compatibility.
- Keep radio messages bounded, rate-limited, and untrusted. Never execute received source or accept remote console commands.
- Sharing starts only after a button press. Reopening Sideband starts with sharing off.
- Keep physical-hardware checks pending until a real badge supplies evidence. Never label emulated radios as physical tests.
- Keep app packages free of test code, credentials, telemetry, and private keys.
