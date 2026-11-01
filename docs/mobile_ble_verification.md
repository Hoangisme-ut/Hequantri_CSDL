# Mobile and BLE verification

Updated 2 November 2026.
Tested code: feature/mobile-setup, commit 71a1ebe.
Receiver: Android 15, model 23129RAA4G.

## Results
- Full Flutter suite: 92 tests passed.
- Separate BLE recovery suite: 13 tests passed.
- Physical BLE and Simulation resolve A/B content, suppress duplicates, record visits and retrieve history.
- Recordings verify Bluetooth-off guidance, stopping and restart.
- do.mp4 verifies signal expiry, content clearing, beacon reentry, recent-visit reuse, Bluetooth loss, Location Services loss/recovery and explicit Stop.
- Permission denial and the short-gap scenario are operator-confirmed, with automated coverage; not separately established from the clips.
- Signal expiry is measured from the last callback containing the selected beacon.

## Scope
Android Task 4 is complete for the agreed scope.
iOS permissions and UUID region are configured; iOS build/device testing remains unverified.
Persistent cache, offline sync, playback, background operation and token persistence/refresh are not implemented.