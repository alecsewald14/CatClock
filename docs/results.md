# Results so far

Plain record of what was tested, by whom, and what is still unknown. Details for the
iPhone test are in [spike-alarmkit.md](spike-alarmkit.md).

## Gate G1 (iPhone alarm test): passed, 2026-11-12

AlarmKit works in an app signed with a free Apple ID on an iPhone 14 Plus (iOS 26.7.2):
locked, app closed, Silent, Focus, and Snooze all passed. Volume levels, daily repeat, a
lapsed signature, and a few smaller checks were **not tested** and are carried into the
iPhone phase.

## Gate G2 (Windows app): passed, 2026-11-13

Tried by the product owner on the Windows laptop, from the Phase 5 release build, using
[windows-tryout.md](windows-tryout.md).

| Test | Result |
|---|---|
| 3. Sounds and volume steps | Reported as passing |
| 4. Ringing with the window open (sound, Stop, Snooze) | Reported as passing |
| 5. Closing to the tray, cat icon, show and quit menu | Reported as passing |
| 6. Ringing while hidden in the tray (window returns) | Reported as passing |
| 1, 2, 7, 8, 9, 10 | **Not individually reported.** The product owner said "all of the things you asked pass", which referred to tests 3 to 6 |

Not yet confirmed by a person: "Start with Windows" (test 8) on a real sign-in; daily
repeat across a day; a quit warning with the alarm on (test 9). These are covered by
automated tests, but have not been seen working.

Found and fixed while building Phase 5: an alarm would have been pushed to tomorrow if the
laptop woke just after its time (caught by a test); a second copy of the app showed its
own window instead of the first copy's; a raw close message ended the app instead of
hiding it; and the window opened taller than a 1080-pixel screen at 150% scaling.

## Phase 6 (icon and installer): done, 2026-11-13

Checked by me on this laptop, with the owner's approval for the test install:

| Check | Result |
|---|---|
| The cat icon file holds all seven sizes (16, 24, 32, 48, 64, 128, 256), each a real PNG of the right size | Passed (automated) |
| The built program file shows the cat icon and the name "Cat Clock" in Windows | Passed |
| Installer compiles with Inno Setup 6.7.3 | Passed (11.4 MB) |
| Installs with no administrator prompt, into `%LOCALAPPDATA%\Programs\Cat Clock` | Passed |
| Start-menu shortcut exists and shows the cat icon; app appears in Installed apps | Passed |
| Uninstalling removes the program, the shortcut, the Installed-apps entry, and the "Start with Windows" entry | Passed |
| Uninstalling silently keeps the saved alarm and settings | Passed |
| The app's own start-up code stores the quoted path plus `--hidden`, also for a folder name with spaces (real registry, scratch key only) | Passed |

**Not done:** the installer was not started by a person with a window, only silently, so
the setup pages and the "also delete your saved alarm and settings?" question have not
been seen. The installed app was deliberately not launched during the test. The installer
is unsigned, so Windows shows a SmartScreen warning.

## Phase 7 (iPhone app): built, not yet seen on a phone, 2026-11-13

Checked by me on this laptop and on a cloud Mac (GitHub Actions, run
`43375158742`, commit `d331c8c`):

| Check | Result |
|---|---|
| Static analysis | Passed, no issues |
| All automated tests | Passed (489), including the iPhone alarm service with a fake AlarmKit, the days-left messages, the PNG writer and iPhone icon files, and a check that the Dart and Swift channel names, methods, and settings agree |
| The Swift code compiles, the app builds without signing, and an `.ipa` is produced | Passed on the first cloud build (12.5 MB) |
| The built app's Info.plist: name "Cat Clock", minimum iOS 26.0, alarm and location permission texts, Live Activities flag | Passed (read from the cloud build) |
| All 30 sound files (6 sounds x 5 levels) are placed at the top of the app, where the alarm service looks for them | Passed (the check fails the build if the count is not 30) |
| The iPhone icons are 15 files of the sizes the project asks for, with no transparency | Passed (automated) |

**Not done, so UNKNOWN:** nothing below has been seen on a phone. The product owner chose
not to run a device test for now.

- Whether the app opens and looks right on the iPhone 14 Plus.
- The alarm permission question, and the message shown when it is refused.
- Ringing with the phone locked, with the app closed, with Silent, and with a Focus mode,
  using the app's own alarm (only the Phase 1 test app was seen doing this).
- Snooze for 9 minutes, and the five volume steps sounding clearly different.
- Daily repeat across a night.
- The days-left line showing 6 days after install, and going back after a renewal.
- Weather from the phone's location.
- What a pending alarm does when the signature lapses (spec check 8, planned for week 2).
- That AltStore accepts the file and installs it, and that the 3-app limit leaves room.

How to install and try each of these: [install-iphone.md](install-iphone.md) and
[weekly-renewal.md](weekly-renewal.md).

## Phase 8 (final check): automated part done, 2026-11-13

Run by me on this laptop, on the final code:

| Check | Result |
|---|---|
| Static analysis | Passed, no issues |
| All automated tests | Passed: **509** (20 added in this phase, see below) |
| `flutter build windows --release` | Passed |
| The new Windows build starts, is responding, and its window is titled "Cat Clock" | Passed (started for 8 seconds, then closed by me) |
| Cloud iPhone build | Passed (Phase 7 run `43375158742`, built from the same app code; later changes in this phase touch `lib/` and were **not** built in the cloud, see below) |
| A scan of every tracked file for passwords, keys, tokens, and keystores | Nothing found. Only prose that mentions passwords |
| Personal details | The owner's Windows user name appeared in two docs as a file path. Removed. It is still in earlier commits, including the already-pushed `phase-7/iphone` branch. The owner's GitHub name appears in the install guide's link, which is their own public repository |
| Commit author on every commit | `Cat Clock Builder`, with no real email address |

**Found by this check, and fixed:** nothing tested the iPhone's days-left line on the
screen, the iPhone note in the alarm settings, or what the app does when it comes back to
the front. 20 tests were added for them, including that the longest footer (credit,
"updated" text, an alarm message, and a signature warning) fits at phone portrait, phone
landscape, and laptop size at normal and double text size. Three deliberate breaks proved
the tests catch real faults: no re-read of the signature on return, no alarm check on
return, and a warning that is not bold. (My first attempt at the first break did not apply
and wrongly showed "still passes"; I redid it and checked it applied.)

**Also changed:** the signature date is now read again whenever the app comes back to the
front, because AltStore may renew it in the background, and a failed read keeps the days
already known. One sentence in the iPhone alarm note claimed the phone's volume decides how
loud the alarm is. That has never been tested, so it now says the phone's volume "may"
change it.

**Not built in the cloud yet:** those two changes to `lib/` came after the cloud build, so
the build that you would download is one commit behind. They are Dart-only changes covered
by the 509 tests, and the cloud build was clean, but a new cloud build is the proof. It
runs when `phase-7/iphone` or `main` is pushed.

### Plan section 4, "must pass", against what exists

The plan named some test files that ended up with different names. This table uses the
real ones.

| Area (plan section 4) | Tests | Result |
|---|---|---|
| 12-hour time | `time_format_test` | Passed |
| Next ring time, including both clock changes | `next_fire_time_test` | Passed |
| Alarm states | `alarm_controller_test`, `alarm_service_test` | Passed |
| Weather codes | `weather_codes_test`, `weather_icons_test` | Passed |
| Weather data, units, staleness (30 minutes, 3 hours), rounding | `open_meteo_client_test`, `open_meteo_fetch_test`, `units_test`, `weather_rules_test`, `weather_repository_test`, `weather_cache_test` | Passed |
| Digits, AM/PM, contrast of at least 4.5 to 1 | `digits_test` (pictures in `test/goldens`) | Passed (7.52 to 1) |
| Layout at 390 x 844, 844 x 390, 1280 x 800, and minimum text and icon sizes | `screen_test`, `belly_panel_test` | Passed |
| Cat: belly panel fixed across 24 frames, still pose with reduce motion | `cat_test`, `walk_cycle_test` | Passed |
| Sounds: 6 x 5 exist, at most 6 MB, each level louder | `sound_catalog_test` | Passed (5.76 MB) |
| Icon sizes | `icon_test`, `ico_test` | Passed |
| Windows alarm with a fake clock | `alarm_service_test`, `widget_test` | Passed |
| Windows start-up entry, installer script | `registry_startup_entry_test`, `installer_script_test` | Passed |
| iPhone alarm service, signature message, icons, project settings | `ios_alarm_service_test`, `signature_test`, `ios_icon_test`, `ios_project_test`, and the iPhone group in `widget_test` | Passed |
| Whole project: analysis clean, Windows build, cloud iPhone build | see the table above | Passed |

### Gate G3 (acceptance): **not yet decided**

"Done for version 1" in `spec.md` section 6 needs the Windows checks to pass and iPhone
checks 1 to 6 to pass on a phone, with check 7 working and check 8 recorded. The state of
each:

| Device check | State |
|---|---|
| Windows 1 to 4 (rings while minimized, rings after Close, Quit stops it, sleep stops it) | Rings with the window open and while hidden in the tray were **reported as passing**. Quit and sleep behavior were not individually reported |
| iPhone 1 Install through AltStore | **Not done** |
| iPhone 2 to 4 (rings locked and closed, with Silent, with Focus) | **Not done on this app.** Seen working only in the Phase 1 test app |
| iPhone 5 Snooze of 9 minutes | **Not done** (a 1-minute snooze worked in the Phase 1 test app) |
| iPhone 6 Five volume steps audibly different | **Not done** |
| iPhone 7 Renewal resets the days-left line | **Not done** |
| iPhone 8 What a lapsed signature does to a pending alarm | **Not done.** Planned for week 2 |

So version 1 is **built and passes every automated check, but is not accepted**: the
iPhone app has not been seen running, and the owner chose not to run the phone checks for
now. If the owner accepts it as it is, that acceptance should say so in these words, and
the unknowns above stay unknowns.

**Gate record**

- [ ] Accept version 1 now, with the unknowns above left open
- [ ] Hold acceptance until the iPhone checks 1 to 6 (and 7) have been run on the phone
- **Decision:** (to be filled in by the product owner)  **Date:**

### Known limits, unchanged

- The Windows installer is unsigned, so Windows shows a SmartScreen warning.
- Windows must be awake with the app running for the alarm to ring; sleep-waking was left
  out on purpose.
- The Windows installer's setup pages and "Start with Windows" at a real sign-in have not
  been seen by a person.
- The iPhone alarm screen when ringing is Apple's own, not the cat.
- The iPhone signature lasts 7 days; a missed renewal stops the app opening.
- The cloud build and AltStore depend on third parties (GitHub, Apple, AltStore).
