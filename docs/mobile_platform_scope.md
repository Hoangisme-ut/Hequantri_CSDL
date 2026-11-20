# Mobile Platform Scope

Updated: 15 November 2026.

## Android

Android is the platform used for physical device validation.

The verified flows include beacon detection, content loading,
artifact details, favorites, history, signal expiry,
Bluetooth recovery and real audio/video playback.

See [Mobile and BLE Verification](mobile_ble_verification.md)
for the recorded results and remaining acceptance case.

## iOS

iOS has not been tested on a physical device.

The source includes foreground authorization handling and
a UUID-specific beacon region. Automated checks cover parts
of this configuration using mocked platform calls.

These checks do not establish that the application builds,
scans beacons or plays media correctly on an actual iOS device.

## Limitations

- Physical validation is limited to the tested Android device.
- Beacon scanning is intended for foreground use.
- Persistent offline content caching and offline synchronization
  are outside the current implementation.
- Returning to the application does not automatically restart
  released media playback.
- Additional iOS build and physical device testing is required
  before claiming iOS support has been verified.
