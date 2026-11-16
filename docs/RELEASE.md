# Release procedure

## Build and verify

```sh
./badge verify
./badge test
./badge package
```

Inspect `artifacts/release/` and the emulator screenshots.
Read the final Git diff. Check packages contain only their app manifest, main script, and bundled modules.

## GitHub download

Publish the verified ZIPs and `SHA256SUMS` in a tagged GitHub release when authorized.
The release description must separate automated firmware-emulator evidence from pending physical checks.
Keep a previous release available for rollback.

## Official store

1. Open the [official submit page](https://solana.com/breakpoint/badge/apps/submit).
2. Sign in with the owner's badge account and link X if required.
3. Upload one verified app ZIP.
4. Check the app ID, free price, category, permissions, and description.
5. Run it in the site's emulator.
6. When hardware is available, select **Run on badge** and complete the physical acceptance checks.
7. Publish the app.
8. Check the live listing from a separate signed-out session.
9. Install from the badge's App Store and verify the installed version.
10. Replace the invite target with the verified store listing for the next app version.

Publication can wait for automatic or organizer review.
A GitHub release does not establish that the official App Store approved the app.

## Rollback

Keep the prior ZIP and release tag. Increase the version when reverting code for a store update.
The first apps store only local preferences and counters. Do not change their storage schema without a migration test.
