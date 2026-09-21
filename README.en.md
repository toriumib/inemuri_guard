# Drowsiness Guard (居眠りガード)

An Android app that **watches your eyelids and head posture through the camera and wakes you when signs of drowsiness persist** — on a desk or on the passenger seat.
Nothing leaves your device. When it rings, open your eyes, say a word, or press a button.

[日本語 README](README.md) · [Google Play](https://play.google.com/store/apps/details?id=com.stop.sleeping) · [Web version](https://inemuri.toriumis.com/app/) ([repo](https://github.com/toriumib/inemuri-web)) · [Terms](https://inemuri.toriumis.com/en/terms/) · [Privacy](https://inemuri.toriumis.com/app/privacy/) (Japanese)

Licensed under **Apache-2.0** ([LICENSE](LICENSE)). Made by Studio Toriumi.

## Why open source

The goal is a drowsiness guard that is *usable the day you install it and keeps being usable* — which means it has to work with your glasses, your dim car, your phone's camera and speaker quirks, your watch. One person can't test all of that. **Reports from real devices are the most valuable contribution**, and you don't need to write code to help ([CONTRIBUTING.md](CONTRIBUTING.md)).

## What it does

| | |
|---|---|
| Eyelids | Time with eyes closed (3–60 s, default 5) and the share of the last minute they were closed (PERCLOS). Blinks don't trigger it |
| Head posture | Slumping, tipping back or sideways by 22°+ from your usual posture wakes you. With sunglasses (eyes unreadable) it watches the head only (EYES HIDDEN) |
| Background | A foreground service takes over the camera when you switch apps or turn the screen off |
| Hands-free stop | Eyes open for 3 s / say "I'm awake" or "stop" / volume, steering-wheel or earphone button / Stop on the notification |
| Car | Set "Where you use it" to Car: rest-stop guidance, look-away nudge, Maps in front. Opens when your car's Bluetooth connects |
| Quiet | Vibration → quiet sound → loud sound. With earphones in, the sound goes there |
| Also | Nap timer, Pomodoro, hydration reminder, detection log, wake on Slack/Teams/email/calls |

Not a medical device and not a substitute for the driver's duty of care. See the [Terms](https://inemuri.toriumis.com/en/terms/).

## How it works (read in this order)

```
lib/services/drowsiness_detector.dart   the judgment: closure time, PERCLOS, head posture, "eyes unreadable", eyes-open-to-stop
lib/services/native_eye.dart            wiring to the background service
android/.../EyeService.kt               Camera2 + ML Kit inside a Service (background). No judgment here
android/.../EyePlugin.kt                MethodChannel / EventChannel hub (eye values, torch, keys, car, voice)
lib/services/alarm_service.dart         how it rings (sound, vibration, torch, stop by voice/keys)
lib/screens/home_shell.dart             app shell: the big wake button, stopping from outside
lib/screens/detect_screen.dart          the detection screen (start/stop, place, seconds)
```

There is exactly **one** judgment, in Dart (`DrowsinessDetector`). Both camera paths — Flutter's camera in the foreground and native Camera2 in the background — feed the same `ingestEyes` / `ingestPose`. Writing the same decision in two places guarantees they drift apart.

- Closure: eyes closed for the configured seconds. A "closed" reading is **not counted until the eyes have been seen open at least once** since the face appeared (sunglasses).
- PERCLOS: ≥15% of the last 60 s closed, and only after a full 60 s has actually accumulated.
- Posture: deviation from a slowly learned baseline, never absolute angles; the baseline stops following while the head is down.
- While ringing, 3 s of open eyes (or restored posture) stops it automatically; no snooze button is shown while the face is visible.

## Build

Flutter 3.35+. After `flutter pub get`:

```bash
flutter test                              # judgment tests, no camera needed
flutter build apk --release               # for testing (test ad IDs, dev mode disabled)
powershell -File tools/build-release.ps1  # Play AAB (reads the private values below)
```

**Always install the release build on a real device and make sure it starts.** R8 shrinking has broken release-only before (`android/app/proguard-rules.pro` explains). Emulators have no real camera or microphone.

### Values kept out of git

| File | Contents | If missing |
|---|---|---|
| `android/key.properties` | signing ([example](android/key.properties.example)) | debug signing; can't upload to Play |
| `android/admob.properties` | AdMob app ID and banner unit ID ([example](android/admob.properties.example)) | Google's public test IDs |
| `tools/release.env` | `DEV_PASSPHRASE=` for the hidden developer mode | developer mode disabled |

If you fork and publish under your own name, change `applicationId` (`android/app/build.gradle.kts`) and the values above. Face detection uses Google ML Kit (Google Play services). An F-Droid build without the ad SDK and ML Kit would be a separate flavour (not started).

## Medical information ⚠️

This app **does not diagnose**. The "consider seeing a doctor" card only suggests talking to a doctor; no code names a condition. **Do not change this policy.**

- `SleepLogService.needsClinicalAttention` uses a conservative threshold (≥5 days or ≥10 events in 14 days) and only decides whether to show the card.
- `models/sleep_symptoms.dart` is an unscored checklist. Epworth Sleepiness Scale and STOP-BANG are copyrighted instruments that require a licence for commercial use and are deliberately not used.
- The improvement tab says plainly that sleep hygiene alone does not fix chronic insomnia and that CBT-I is first-line.

## Privacy

Camera frames and audio are processed on the device and never sent or recorded. "Stop by voice" uses the device's speech recognition (Google), so audio while the alarm rings may be processed by that service (can be turned off). Logs live in `shared_preferences` and expire after ~90 days.

## Contributing

- Device reports (model, OS, situation, what happened) are the most valuable → [Issues](https://github.com/toriumib/inemuri_guard/issues)
- Translations (`lib/l10n/`, [docs/internationalization.md](docs/internationalization.md))
- Code: `flutter analyze` clean, `flutter test` green, release build started on a real device — the three conditions for a PR

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) and [docs/CHANGELOG.md](docs/CHANGELOG.md).
