# Plan: Cat alarm clock (from spec.md, 2026-11-11)

- **Source:** [spec.md](spec.md), accepted 2026-11-11, which traces to [intent.md](intent.md)
- **Author:** Claude (Build stage)
- **Status:** ACCEPTED on 2026-11-11 by the product owner. Build starts at Phase 0.
- **Next artifact:** working code with tests, then a review

---

## 0. Ground rules for the build

- **I ask before:** every software install; creating a GitHub repository or pushing code
  to it (that publishes the code); anything that uses your Apple ID.
- **I never:** create accounts for you, type your passwords, or sign the iPhone app
  myself. You do those parts; I write the step-by-step instructions.
- **Work is done in phases, in order.** Each phase ends with its proof (section 4). Three
  phases end with a human gate where you decide whether to go on (G1, G2, G3).
- **Each phase is committed and tagged** (`phase-1`, `phase-2`, ...), so any phase can
  be undone (section 5).
- **Seeing what I build:** I cannot watch your screen. I check visuals through saved
  test images that I open and look at, and I ask you to look at the real app at gates
  G2 and G3.
- **Where the project lives:** this session is using a temporary folder. At Phase 0 you
  choose a real folder (suggested: `Documents\CatClock`), and `intent.md`, `spec.md`, and
  `plan.md` move into its `docs` folder.

## 1. Files that change

Everything is new. Grouped by area; the paths are inside the project folder.

| Area | Files |
|---|---|
| Project and docs | `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `.gitignore`; `docs/intent.md`, `docs/spec.md`, `docs/plan.md`, `docs/spike-alarmkit.md`, `docs/install-windows.md`, `docs/install-iphone.md`, `docs/weekly-renewal.md`, `docs/results.md` |
| App shell | `lib/main.dart`, `lib/app/app.dart`, `lib/app/theme.dart` |
| Clock | `lib/clock/clock.dart`, `lib/clock/time_format.dart` |
| Cat | `lib/cat/cat_painter.dart`, `lib/cat/walk_cycle.dart`, `lib/cat/cat_view.dart` |
| Display | `lib/display/seven_segment_painter.dart`, `lib/display/ampm_painter.dart`, `lib/display/belly_panel.dart` |
| Weather | `lib/weather/open_meteo_client.dart`, `lib/weather/weather_repository.dart`, `lib/weather/weather_codes.dart`, `lib/weather/units.dart`, `lib/weather/location_service.dart`, `lib/weather/weather_icons.dart`, `lib/weather/weather_panel.dart` |
| Alarm | `lib/alarm/alarm.dart`, `lib/alarm/alarm_store.dart`, `lib/alarm/alarm_controller.dart`, `lib/alarm/next_fire_time.dart`, `lib/alarm/alarm_scheduler.dart`, `lib/alarm/sound_catalog.dart`, `lib/alarm/sound_player.dart`, `lib/alarm/alarm_sheet.dart`, `lib/alarm/ringing_view.dart` |
| Windows only | `lib/platform/windows/in_app_scheduler.dart`, `lib/platform/windows/tray_and_window.dart`, `lib/platform/windows/startup_entry.dart`, `windows/runner/` icon and window tweaks |
| iPhone only | `lib/platform/ios/alarmkit_scheduler.dart`, `lib/platform/ios/signature_info.dart`, `ios/Runner/AlarmBridge.swift`, `ios/Runner/AppDelegate.swift` (wiring), `ios/Runner/Info.plist` (AlarmKit usage text, iOS 26 minimum, location text), `ios/Runner/Assets.xcassets` (app icon), `ios/Runner/Sounds/` |
| Assets and generators | `assets/sounds/` (6 sounds x 5 loudness levels), `assets/icons/`, `tool/make_sounds.dart`, `tool/make_icons.dart` |
| Installer | `installer/CatClock.iss` |
| Cloud build | `.github/workflows/spike-ipa.yml` (Phase 1), `.github/workflows/ios-ipa.yml` (Phase 7) |
| Test spike (Phase 1) | `spike/alarmkit_test/` (a small separate app, kept for reference after the gate) |
| Tests | `test/` (one file per area, listed in section 4) |

## 2. Order of work

Phases 2 to 6 (Windows) do not depend on the iPhone test. **Phase 7 (iPhone app) must not
start until gate G1 passes.** If your accounts are not ready for Phase 1, I can start
Phase 2 and come back.

### Phase 0 — Setup (you approve each install)

1. You choose the project folder. I create it, set up version control, and move the
   three documents into `docs`.
2. Install, one at a time with your OK: **Git**, **Flutter**, **Visual Studio 2022 Build
   Tools** with the "Desktop development with C++" workload (several gigabytes).
3. Run Flutter's own health check until the Windows part is green.
4. Create the empty Flutter project for Windows and iPhone, plus the first commit.

*Proof:* the health check passes for Windows; a blank app builds and opens on this laptop.

### Phase 1 — AlarmKit test on your phone  **(gate G1: go / no-go)**

This answers the biggest unknown (concern C2) before anything else is built on it.

1. **You create** a free GitHub account (if you have none) and decide whether the
   repository is private or public. Private keeps the code to yourself but its free
   cloud-build minutes may be limited; public is free but anyone can read the code. There
   are no passwords or keys in the code either way. **I ask before creating or pushing.**
2. I write the small test app in `spike/alarmkit_test`: one button, "ring in 2 minutes",
   plus a second button to try a repeating alarm, and a line that shows the signature's
   expiry date. It uses a placeholder sound.
3. I write the cloud workflow that builds an **unsigned** `.ipa` on a macOS 26 runner and
   saves it as a download.
4. **You install** Apple's iTunes and iCloud for Windows and AltServer (I give exact
   steps and confirm each), turn on Developer Mode on your iPhone, and install the
   `.ipa` through AltStore with your Apple ID. **You type the credentials yourself.**
5. You run the checks listed under G1 and tell me what happened.

**G1 checks (on your phone):** (a) the permission question appears; (b) a 2-minute alarm
rings with the phone **locked** and the app **closed**; (c) it rings with the **Silent**
switch on; (d) it rings with a **Focus** mode on; (e) the sound repeats until stopped, or
for how long; (f) a snooze of 9 minutes works, and whether it needs an extra app
component; (g) a daily repeat works; (h) the five pre-scaled loudness files are audibly
different; (i) the signature's expiry date can be read.

**Gate G1:** I write the results in `docs/spike-alarmkit.md`. **Pass:** go on. **Fail on
(b), (c), or (d):** I stop and you choose between the web-app fallback (spec 3.10) and
a different route. **Fail on only (e) to (i):** I adjust the design of that one piece and
tell you.

### Phase 2 — Pure logic, tests first (Windows laptop only)

Write each test first, watch it fail, then write the code. No screens yet.

1. `time_format`: 12-hour conversion and the AM/PM rule.
2. `next_fire_time`: next occurrence of a time, including clock-change days.
3. `alarm_controller`: the states (Off, Armed, Ringing, Snoozed, Missed), 9-minute
   snooze, 10-minute miss, daily repeat.
4. `weather_codes`: every code in the spec table to one of 12 icons.
5. `units`: US region gets Fahrenheit, everywhere else Celsius.
6. `weather_repository` rules: the 30-minute dim, the 3-hour "unavailable", and rounding
   coordinates to 2 decimals before a request.
7. `alarm_store`: saving and loading the alarm file.

*Proof:* all Phase 2 tests pass; static analysis is clean.

### Phase 3 — Visuals (Windows laptop only)

1. Seven-segment digits and the AM/PM letters, with a contrast test.
2. Twelve weather icons.
3. The belly panel layout: time, AM/PM, then the weather panel to the right.
4. The cat and its walk cycle, with the belly panel held still, 24 frames per second
   cap, and a still pose when reduce-motion is on.
5. The app screen putting them together, with the alarm bar and the footer credit link.

*Proof:* saved test images for digits 0 to 9, for each icon, and for the whole screen at
phone-portrait, phone-landscape, and laptop sizes. **I open and review the images
myself.** Layout, cat-stillness, and contrast tests pass.

### Phase 4 — Weather (Windows laptop)

1. The Open-Meteo client, using the exact request shape in spec 3.5, with a saved real
   response as the test sample.
2. The repository: refresh at start, on return to the screen, and every 15 minutes;
   last-good cache; dim and unavailable states.
3. The Windows location service and the permission explanation text.
4. The weather panel wired to real data, and the credit link.

*Proof:* parsing test on the saved response (the six hours after the current one are
shown, in order); failure tests (no network, no permission); one live run on this
laptop that I look at.

### Phase 5 — Windows alarm and app shell  **(gate G2: you try it)**

1. The sound generator (`tool/make_sounds.dart`, written in Dart so nothing else needs
   installing) and the six sounds in five loudness levels.
2. The sound player and the sound list with previews.
3. The in-app scheduler with the every-second check, the alarm sheet (time, on/off,
   repeat daily, sound, volume), and the ringing screen with Stop and Snooze.
4. The tray icon, hide-on-close, Quit with a warning, taskbar flash when ringing.
5. The **Start with Windows** switch (off by default, removable).

*Proof:* scheduler tests with a fake clock (rings on time; rings after a wake within 10
minutes; missed after more than 10); sound catalog test (30 files, total at most 6 MB,
each level quieter than the next); a run on this laptop.

**Gate G2:** you run the Windows app from the project and try: an alarm 2 minutes ahead
with the window minimized; closing with X; each sound and volume step; repeat daily; the
Start with Windows switch on and off. You tell me what feels wrong. **I fix before Phase
6.**

### Phase 6 — Windows icon and installer

1. The cat-face icon master and the multi-size `.ico` (`tool/make_icons.dart`).
2. The per-user installer with a Start-menu shortcut (`installer/CatClock.iss`), after
   you OK installing the installer tool.
3. `docs/install-windows.md`, including the SmartScreen "More info, Run anyway" step.

*Proof:* the `.ico` holds all seven sizes; the installer runs on this laptop (with your
OK) and the shortcut shows the icon; uninstalling removes the app and any startup entry.

### Phase 7 — iPhone app  *(only after G1 passes)*

1. Turn the tested AlarmKit code into `AlarmBridge.swift` and `AlarmKitScheduler`,
   with the permission flow, schedule, cancel, 9-minute snooze, and daily repeat.
2. Bundle the sounds in the five loudness levels.
3. Location while the app is in use; the days-left line and its warning colors.
4. The iPhone app icon set from the same master icon.
5. The cloud workflow `ios-ipa.yml` producing the unsigned `.ipa`.
6. `docs/install-iphone.md` and `docs/weekly-renewal.md` (exact weekly steps, and what to
   do if a renewal is missed).

*Proof:* the cloud build compiles and produces an `.ipa`; all shared tests still pass;
the iPhone checks in section 4 pass **on your phone**.

### Phase 8 — Final check and handover  **(gate G3: acceptance)**

1. Run every automated test and the static analysis.
2. You run the full device checklists (spec section 6, both devices).
3. Week 2: with a backup alarm set, test what a lapsed signature does to a pending
   alarm (spec check 8), and record the answer.
4. I write `docs/results.md`: what passed, what failed, what is still unknown.

**Gate G3:** version 1 is done when section 4's "must pass" items pass. Anything that
fails stays in `docs/results.md`, not hidden.

## 3. Risks

| Risk | Effect | What the plan does |
|---|---|---|
| AlarmKit does not work in a free-signed app (C2) | No reliable iPhone alarm | Phase 1 comes first; Phase 7 is blocked until G1 passes |
| iPhone code can only be compiled in the cloud | Slow fix cycle, about one cloud build per attempt | Keep the Swift part small; prove it in Phase 1; read cloud logs rather than guess |
| A missed weekly renewal (C6) | App will not open; a set alarm may not ring | Days-left line, `docs/weekly-renewal.md`, backup alarm advice, Phase 8 week-2 test |
| Large installs fail or need a restart | Delay in Phase 0 | One install at a time, health check after each |
| Cloud free minutes run out | Builds stop | Check the allowance in Phase 1; Codemagic is the alternative |
| Unsigned `.ipa` packaging mistakes (for example, links inside the zip) | AltStore rejects the file | Copy the app rather than link it; test the packaging in Phase 1 |
| Synthesized meow and purr sound poor (C8) | A weak sound menu | You listen at G2; swap in licensed recordings if needed |
| The Open-Meteo free terms change or the service is down (C7) | No weather | Cache and "unavailable" state; clock and alarm unaffected |
| Constant animation uses battery (C5) | Laptop battery | 24 fps cap, paused when minimized |
| Secrets leaking into the code | Account exposure | No keys are needed. Apple credentials are only ever typed by you into AltStore. A check before each push looks for secrets |

## 4. Proof

**Must pass before the build is called done:**

| Area | Automated check (test file) |
|---|---|
| 12-hour time | `time_format_test`: 0:00 is 12:00 AM; 12:00 is 12:00 PM; 12:59 PM; 23:59 is 11:59 PM; 1:05 AM |
| Next ring time | `next_fire_time_test`: later today; already passed so tomorrow; same minute; skipped hour on spring clock change; repeated hour on fall clock change |
| Alarm states | `alarm_controller_test`: arm; ring; stop; stop with repeat; 9-minute snooze; missed after 10 minutes; ring after wake |
| Weather codes | `weather_codes_test`: every code in spec 3.5 maps to its icon; unknown maps to "unavailable"; day and night versions |
| Weather data | `weather_parse_test`: saved real response gives "Now" plus the six following hours in order; `units_test`; `weather_staleness_test` (30 minutes, 3 hours); `rounding_test` |
| Digits and letters | `seven_segment_golden_test` (0 to 9, colon, blank leading digit); `ampm_golden_test`; `contrast_test` (at least 4.5 to 1) |
| Layout | `belly_layout_test`: weather panel starts right of the time at 390 x 844, 844 x 390, and 1280 x 800; text and icon minimum sizes at 390 wide |
| Cat | `cat_test`: belly panel position identical across 24 frames; still pose with reduce-motion |
| Sounds | `sound_catalog_test`: 6 sounds x 5 levels exist, total at most 6 MB, each level louder than the one below |
| Icon | `icon_test`: the `.ico` holds 16, 24, 32, 48, 64, 128, 256 |
| Windows alarm | `in_app_scheduler_test` with a fake clock |
| Whole project | static analysis clean; `flutter build windows` succeeds; the cloud iPhone build succeeds |

**Checked by you on real devices** (spec section 6): the Windows checks 1 to 4, and the
iPhone checks 1 to 8. The iPhone alarm behavior can only be proved this way.

## 5. Rollback

- Every phase is committed and tagged, so a bad phase can be undone with one command.
- The Windows app uninstalls from Windows Settings; the installer removes the shortcut
  and the optional startup entry.
- The iPhone app is deleted like any other app; AltStore can be removed afterward.
- If G1 fails, nothing from Phase 7 exists yet, and Phases 2 to 6 stand on their own as
  a complete Windows app.
- No system settings are changed except the optional startup entry, which only the app's
  own switch creates.

## 6. Approval (Build gate)

"Nothing is implemented without an accepted plan." A human accepts this file first.

- [x] The order of work and the three gates (G1, G2, G3) are right
- [x] The ground rules in section 0 are right
- [x] Project folder: chosen by the product owner at Phase 0 step 1 (suggested: `Documents\CatClock`)
- **Decision:** accepted  **By:** product owner (via chat: "Approve, start setup")  **Date:** 2026-11-11
