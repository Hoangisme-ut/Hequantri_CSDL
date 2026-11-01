# Mobile and BLE verification

Updated 1 November 2026. Project: Smart Heritage, Task 4.

## Verified baseline

Branch `feature/mobile-setup`, commit `e943fb6c39d37b6cecf1539046411b26a09d0860`.

- Shared Bearer-token content resolution for physical BLE and Simulation.
- Duplicate suppression and three-callback A/B switch confirmation.
- Visit submission after current content is displayed on the active route.
- POST `/api/v1/visits/`: measured RSSI for physical scanning, omitted for Simulation; user identity comes from the token.
- GET `/api/v1/visits/me`: actual personal history, refresh, retry and pagination.
- User-run Flutter result: **79 tests passed** before the recovery changes below.

Receiver: Android 15, model 23129RAA4G. UUID `FDA50693-A4E2-4FB1-AFCF-C6EB07647825`; A = Major 1 / Minor 1; B = Major 1 / Minor 2.

The 1 November physical clip showed A → Đoan Môn, B → Điện Kính Thiên, two resolves, repeated-packet suppression and successful save messages. History showed two new 22:55 entries plus two Simulation entries at 22:23, total four. These times refer to the same local demonstration account. A total of four is not evidence of duplicate recording: there were two separate demonstrations more than five minutes apart.

## Recovery changes prepared in this update

- Explicit authorization, Bluetooth and Location Services checks before Android scanning.
- Bluetooth/authorization listeners stop a running scan and invalidate current content when access is lost.
- On return from device settings, check services without reopening a permission prompt.
- Independent ten-second timers expire raw readings and the selected beacon even if callbacks stop completely. A short interruption retains the selection; an expired selection can be recognized again.
- Stop, error and disposal cancel timers/listeners; generation checks reject callbacks from a previous scan.
- iOS foreground Location/Bluetooth purpose strings, When In Use request and the configured UUID region.
- Thirteen new automated cases in `beacon_resilience_test.dart`. **Not executed in the preparation environment because Flutter/Dart are unavailable.** No new passing-test total is claimed.

The iOS code has not been built on macOS or tested on an iPhone. No background mode, background permission, offline cache or queued synchronization is included.

## Regression commands

From `mobile_app`, after applying the update:

```powershell
dart format lib/features/beacon/beacon_tools_page.dart lib/features/beacon/beacon_scanner.dart test/beacon_resilience_test.dart
flutter analyze
flutter test test/beacon_resilience_test.dart
flutter test
```

Record actual output. The earlier 79-test result must not be reused as a passing result for this changed snapshot.

## Physical test record

All rows below are **pending**. Replace a pending result only after observing it on the receiver. Keep screen clips and terminal output as evidence. Record OS/device and the tested commit.

| Case | Actions | Expected behavior | Actual result |
| --- | --- | --- | --- |
| A/B regression | Start scan with A, repeat A, switch transmitter to B, open History. | One resolve for each accepted selection; repeats suppressed; A/B saved or reused by server. | Pending |
| Bluetooth initially off | Turn receiver Bluetooth off; press Start. | Explain Bluetooth is not ready; Start remains available; no content/visit request. Enable Bluetooth and start again successfully. | Pending |
| Bluetooth disabled during scan | Receive A, then disable receiver Bluetooth. Return to app. | Stop/reset selection, explain service loss, enable Start. Enabling Bluetooth alone must not silently record visits; Start explicitly to resume. | Pending |
| Permission denied | Stop scan. In Android Settings → Apps → this app → Permissions, deny Nearby devices and/or Location. Reopen and deny the prompt if shown. | Clear permission guidance, no crash, no content/visit request. Grant permissions and press Start to recover. Android may restart the process after permission changes; sign in again if required. | Pending |
| Location Services off | Disable device Location, press Start. Also test changing Location in Settings during a scan, then return. | Explain Location is off; no active scan until enabled and Start is pressed again. | Pending |
| Short signal loss | While receiving A, stop the transmitter briefly for less than ten seconds, then restore A. Keep receiver Bluetooth on. | Retain selection; no repeated entry notification or resolve for the same accepted beacon. Use scanner callback times when interpreting the ten-second grace. | Pending |
| Prolonged signal loss | Receive A, turn transmitter off for at least fifteen seconds while receiver remains scanning. Restore A. | After ten seconds without eligible observations of A, clear its content/selection. Raw readings also expire after their last callback. Recognize A again on return. A new resolve is allowed; server may reuse a visit within 300 seconds. | Pending |
| Stop and leave | Receive A, press Stop, wait fifteen seconds, navigate out. | Stop remains stopped, no late content update or extra visit; retained raw data is labeled as last reading. | Pending |
| iOS build and device | On macOS, build/install on a physical iPhone, grant When In Use and Bluetooth, advertise the configured A/B UUID. | Verify region filtering, permissions, A/B content/visits and denial/off recovery. A successful Android test cannot mark this row complete. | Pending — no iOS device available |

The plugin may retain observations briefly, so signal-loss timing is measured from the last callback containing the selected beacon, not necessarily the instant the transmitter is switched off. Other unselected beacons must not keep the selected artifact alive indefinitely.

## Branch workflow

Save implementation and documentation in separate meaningful commits on `feature/mobile-setup`. The recovery update is prepared for verification; it is not a new passing-test result. Run regression and record physical outcomes before merging to main. Commit subsequent fixes and observed results separately; do not mark pending device cases as passed.
