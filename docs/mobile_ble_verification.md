# Mobile and BLE Verification

Updated: 15 November 2026.

## Environment

- Application: Smart Heritage Flutter mobile app.
- Working branch: `feature/mobile-setup`.
- Android receiver: model `23129RAA4G`, Android 15.
- Backend: FastAPI with SQL Server.
- Validation includes automated tests and manual checks on an Android device.

## Beacon Configuration

Both Android and iOS use the configured heritage UUID:

`FDA50693-A4E2-4FB1-AFCF-C6EB07647825`

Major and Minor are not restricted by the scanning region.

The Android device checks used Major `1`, Minor `1`,
linked to the Doan Mon artifact (`HTTL-DOAN-MON`).

## Android Results

| Scenario | Result | Observation |
| --- | --- | --- |
| Scan on an Android device | Passed | The app detected the heritage beacon and loaded backend content. |
| Update content through the admin web | Passed | The updated Vietnamese description appeared in the mobile preview. |
| Open artifact details | Passed | The preview opened the matching artifact detail page. |
| Favorites | Passed | The saved artifact appeared in Favorites and could be reopened. |
| Visit history | Passed | Doan Mon appeared in the visitor's history and could be reopened. |
| Repeated beacon readings | Passed | The new-notification count remained unchanged while repeated readings were suppressed. |
| Technical details | Passed | Opening showed beacon data; closing hid the data; new readings did not close the section. |
| Signal expiry | Passed | The selection and preview cleared after approximately 10 seconds without a qualifying reading. Scanning remained active. |
| Beacon reentry | Passed | The beacon was accepted again and its content was loaded. |
| Bluetooth disabled | Passed | Scanning stopped, content cleared and recovery guidance appeared. |
| Bluetooth restored | Passed | Pressing Start scanning restarted detection and content loading. |
| Explicit Stop | Passed | Scanning stopped and the preview cleared. The last raw readings remained available. |
| Real audio and video | Passed | Playback was checked on Android and confirmed by the operator. |
| Content status message | Passed | Loaded content displayed a ready message instead of the previous lookup message. |

## Content and Visit Rules

- The beacon preview does not create a visit.
- Visit submission belongs to the artifact detail flow after
  the current content is displayed on the active route.
- The backend reuses a recent visit for the same user and
  artifact within its 300-second duplicate window.
- Outdated content responses cannot replace the current selection.
- Beacon switching requires three consecutive confirmations.
- The current qualifying beacon reading refreshes selection expiry.

## Automated Verification

The local Flutter suite completed with:

`210 tests passed`

GitHub Actions also passed Flutter analysis, Flutter tests
and the repository pre-commit checks for the final code PR.

## Remaining Acceptance Case

The manual web-to-mobile check updated an existing artifact.
Creating a new artifact and completing the entire beacon flow
for that new record has not yet been verified in this session.

## Evidence

Screenshots and recordings were reviewed during testing.
Repository evidence files will be added in a separate documentation update.

## Platform Scope

Physical device results in this report apply to Android.
iOS has not been tested on a physical device.
