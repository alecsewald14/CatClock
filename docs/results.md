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

## Still to come

Phase 7 (iPhone app) and Phase 8 (final checks). This file is extended at each gate.
