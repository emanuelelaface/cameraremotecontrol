# Camera Remote Control

Apple Watch Bluetooth remote for Canon cameras using the BR-E1 protocol.
The [original project notes](https://awa.scumm.it/posts/category/subcategory/2021/12/01/CRC/)
describe the protocol and setup on a Canon EOS R.

## Building

Open `CRC.xcodeproj`, select the shared **CRC WatchKit App** scheme, select your
Apple Watch, and run. Keep the existing bundle identifiers when updating an
installed or published copy; select your signing team if necessary.

- For the watchOS 27 SDK and simulator, use **Xcode 27** with the watchOS platform
  installed. See Apple's [Xcode requirements](https://developer.apple.com/xcode/system-requirements/)
  and [watchOS 27 release notes](https://developer.apple.com/documentation/watchos-release-notes/watchos-27-release-notes).
- Minimum deployment target: **watchOS 9**, the oldest target supported by Xcode 27.
  The iOS target is only the watch-only app's distribution container and targets iOS 15.
- Swift 6 language mode. The project also builds with Xcode 26.6, for local
  checks when Xcode 27 is unavailable.
- The source folder retains its historical `CRC WatchKit Extension` name;
  the executable is already a single-target SwiftUI Watch app.

Unsigned simulator build:

```sh
xcodebuild -project CRC.xcodeproj -scheme 'CRC WatchKit App' \
  -configuration Debug -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Use the destination rather than an SDK override so Xcode builds the Watch app
and its iOS distribution container for their respective platforms.

Protocol regression tests, without a camera or simulator:

```sh
swift test
```

## Camera setup

1. On the camera, set the Bluetooth function to **Remote**, then select **Pairing**.
2. Open CRC and allow Bluetooth access on the Watch.
3. Enable a camera drive mode that accepts remote shooting, such as **10s/Remote**
   or **2s/Remote** on the EOS R.
4. Choose Immediate, 2s Delay, or Video in CRC. Video additionally requires the
   camera's movie mode and remote control setting. Zoom depends on camera/lens support.

CRC reports permission, Bluetooth, discovery, and connection errors separately.
After a timeout, check the camera settings and tap **Retry**. An unexpected
disconnect starts another bounded scan while the app is active. Backgrounding
stops scanning and cancels incomplete connections. Established connections remain
available so a queued button release can drain; returning reconnects if needed.
System permission dialogs do not interrupt pairing.

## Changes in 1.2

- Updated deployment targets, Swift 6 isolation, generated app metadata, and shared
  build scheme; replaced `NavigationView` with `NavigationStack`.
- The icon catalog generates every Watch size from the original 1024 px artwork,
  including the previously empty Ultra slots. Old thumbnails are retained in
  `Artwork/LegacyAppIcons` outside the compiled catalog.
- A stable `StateObject` owns the Bluetooth manager. Controls observe connection
  changes, retain the selected mode through reconnects, respect screen insets, and
  scroll on smaller screens or with larger text.
- Service-filtered discovery avoids indexing empty advertisements and recognizes
  the Canon service regardless of its advertised position.
- Commands are enabled only after both writable characteristics are discovered
  and the pairing packet is queued. Failed connections, invalidated services, and
  timeouts clear stale characteristics and pending commands.
- Button pulses no longer block the main thread. The original 60 ms hold starts
  after the press is queued. Bluetooth backpressure preserves pending packets,
  overlapping taps are ignored, and backgrounding releases a pressed button or
  discards an unsent press. Disconnects cancel pending timers.
- Removed the unused application delegate and obsolete extension plist.
  The ClockKit template always returned empty timelines and had no usable
  complication; its registration and placeholder controller were removed.
  This version does not add a WidgetKit complication.

The Canon wire protocol is unchanged: pairing sends only `03`, a press combines
mode/button bits, and release sends `0C`. In particular, the empty pairing name is
intentional because the original EOS R experiments found problems with named remotes.
Writes use the original unacknowledged protocol: “Connected” confirms local
discovery and pairing submission, not receipt of a shutter command by the camera.

## Validation and remaining hardware checks

The automated tests cover all 12 mode/button combinations, neutral release,
rapid taps, Bluetooth backpressure, cancellation before a press, release during
a hold, and clearing pending commands after disconnect.

Local validation: all 9 protocol tests passed; unsigned Debug (simulator) and
Release (device) builds succeeded with Xcode 26.6 / SDK 26.5. The app installed and
launched on the watchOS 26.5 Apple Watch SE 3 (40 mm) simulator, showing the expected
Bluetooth-unavailable state. Real camera controls require hardware verification.

The development machine has Xcode 26.6 and the watchOS 26.5 SDK. A successful build
there cannot establish watchOS 27 runtime compatibility. Before releasing:

1. Build and run with Xcode 27 on watchOS 27.
2. On a physical Watch and camera, check first pairing, reconnect after camera
   power-off/range loss, Bluetooth off/on, and denied/restored Bluetooth permission.
3. Test immediate and delayed shutter, autofocus, supported zoom, and video
   start/stop. Check rapid taps and backgrounding immediately after a tap.
4. Check the controls on small and large Watch displays and with larger text.

The simulator cannot validate a real Canon Bluetooth session. No signed archive
or App Store upload is produced by the unsigned build command above.
