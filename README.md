<!--
 * @Author: cubevlmu khfahqp@gmail.com
 * @LastEditors: cubevlmu khfahqp@gmail.com
 * Copyright (c) 2026 by FlybirdGames, All Rights Reserved. 
-->

# Quick Box

Quick Box is a Flutter-based Android app launcher focused on fast search and one-tap app launch.

## Notice

Old version of Quick Box is in branch legacy which using native android ui system.
Now the main branch is the new version based on flutter ui engine.

## Features

- Real-time app search
- One-tap app launch
- Auto-close launcher after launching an app
- Shows launchable apps installed on the device
- App icons with visible-range batch loading for smoother scrolling

## Platform Support

- Android only
- Not supported: Windows, iOS, macOS, Linux, Web

## Run

```bash
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --debug
flutter build apk --release
```

## Android Notes

`android/app/src/main/AndroidManifest.xml` includes:

- `android.permission.QUERY_ALL_PACKAGES`
- Launcher visibility `<queries>` config

This app uses package visibility APIs to discover launchable apps. If you publish to Google Play, make sure your policy declaration matches your actual use case.

## Android 12+ Splash Behavior

Android 12 and above always show a system splash screen at startup.
This project minimizes it visually (plain background + transparent splash icon), but it cannot be fully disabled by app code.