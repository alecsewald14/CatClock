# Cat Clock

A cat-shaped alarm clock. A friendly cartoon cat walks on the screen with the time on its
belly in blue digital numbers, with AM or PM, the weather now and for the next 6 hours
beside it, and an alarm with six sounds and five volume steps.

One Flutter program, two apps: **Windows 11** and **iPhone** (iOS 26 or newer).

## Status (version 1.0.0)

| | State |
|---|---|
| Automated tests and code analysis | Pass (509 tests, no analyzer issues) |
| Windows app and installer | Built; tried by the product owner (see `docs/results.md` for what was and was not confirmed) |
| iPhone app | Builds in the cloud into an installable file. **Never yet run on a phone.** Only the small Phase 1 test app was proven on a phone |
| Acceptance (gate G3) | **Open.** See `docs/results.md` |

## Install

- Windows: [docs/install-windows.md](docs/install-windows.md)
- iPhone (free Apple ID, through AltStore, renewed weekly):
  [docs/install-iphone.md](docs/install-iphone.md) and
  [docs/weekly-renewal.md](docs/weekly-renewal.md)

## How this was built

The project follows an AI-native software development life cycle. Each step has a written
document and a human approval before the next one starts.

| Step | Document |
|---|---|
| Idea and goals | [docs/intent.md](docs/intent.md) |
| What it does, and what could go wrong | [docs/spec.md](docs/spec.md) |
| Order of work, gates, and tests | [docs/plan.md](docs/plan.md) |
| What was tested, by whom, and what is unknown | [docs/results.md](docs/results.md) |
| The iPhone alarm test (gate G1) | [docs/spike-alarmkit.md](docs/spike-alarmkit.md) |

## For developers

You need Flutter 3.47.9 (Dart 3.13), Git, and for Windows the Visual Studio C++ build tools.

```
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

Windows release and installer (Inno Setup 6; the version in `installer\CatClock.iss` must
match `pubspec.yaml`, and a test checks that):

```
flutter build windows --release
"%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" installer\CatClock.iss
```

iPhone: the Swift code can only be built on a Mac, so GitHub Actions does it
(`.github/workflows/ios-ipa.yml`, on a `macos-26` runner). It saves an **unsigned**
`CatClock.ipa`; AltStore signs it with the owner's own Apple ID. No keys or passwords are
stored in this repository. The workflow starts when `lib`, `ios`, `assets`, or the
package files change on `main` or `phase-7/iphone`. The "Run workflow" button works only
once this workflow file is on the default branch.

### Folders

| Folder | What is in it |
|---|---|
| `lib/alarm` | Alarm settings, the ring-time rules, the state machine, the Windows alarm service, sounds |
| `lib/platform/ios` | The iPhone alarm service and its channel to Apple's AlarmKit |
| `lib/platform/windows` | Window, tray, single-instance, start-up entry, problem log |
| `lib/weather` | Open-Meteo client, weather rules and icons, saved copy, refresh timing |
| `lib/display`, `lib/cat`, `lib/app` | Digits, the walking cat, the screens and the alarm sheet |
| `ios/Runner/AlarmBridge.swift` | The only Swift code: AlarmKit and the signature date |
| `assets/sounds` | 6 sounds x 5 volume steps (30 files). Windows bundles only the loudest of each |
| `test` | One test file per area, plus golden pictures in `test/goldens` |
| `tool` | Scripts that make the sounds and icons, and a live weather check |
| `installer` | The Windows installer script |
| `spike` | The Phase 1 AlarmKit test app, kept for reference |

### Things worth knowing

- **Saved data on Windows:** `%APPDATA%\app.catclock\cat_clock\` (`alarm.json`,
  `settings.json`, `weather_cache.json`, `problems.log`). The company and product names in
  `windows\runner\Runner.rc` decide this folder, so do not change them.
- **Weather:** [Open-Meteo](https://open-meteo.com/), free for non-commercial use, and it
  needs the credit link kept in the footer. Only coordinates rounded to about 1 km are sent.
- **Windows alarm:** it rings from a one-second clock check inside the running app, so the
  app must be running and the laptop awake. Closing the window hides it in the tray.
- **iPhone alarm:** Apple's alarm service rings it, so it works with the app closed. It
  needs iOS 26 or newer, and the free signature lasts 7 days.
- **Volume on iPhone:** the app cannot turn an alarm down, so each volume step is a
  separate, pre-scaled sound file. The workflow copies all 30 into the app so the alarm
  service can find them.
- **Regenerating files:** `dart run tool/make_sounds.dart` rewrites the sounds. Setting
  `CATCLOCK_WRITE_ICONS=1` and running `test/icon_test.dart` or `test/ios_icon_test.dart`
  rewrites the Windows or iPhone icons.
- **Checking a test really tests:** break the code on purpose and confirm a test fails.
  That is how the newest tests were checked.
