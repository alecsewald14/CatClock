# Spec: Cat alarm clock (Windows laptop + iPhone)

- **Source:** [intent.md](intent.md), accepted 2026-11-11, including the product owner's answers
- **Author:** Claude (Design stage: read-only, no code written yet)
- **Date:** 2026-11-11
- **Revision:** the product owner chose **Option B, a native iPhone app**, on 2026-11-11.
  This file now designs for that choice. The earlier web-app option is kept only as a
  fallback (section 3.10).
- **Status:** ACCEPTED on 2026-11-11 by the product owner, with the three additions
  described in sections 3.6, 3.8, and 3.9 (daily repeat, Start with Windows, days-left line)
- **Next artifact:** [plan.md](plan.md) (Build stage). Nothing is built until it is accepted.

---

## 1. Decision in one page

1. **One codebase, two apps.** The cat, the blue digits, and the weather panel are drawn
   by one Flutter (Dart) project, so both devices show the same thing.
   - **Windows laptop:** a desktop app with a tray icon and a Start-menu icon.
   - **iPhone:** a native app. The alarm itself is handed to Apple's **AlarmKit**
     (iOS 26 and later), which lets an alarm ring with the app closed, the screen
     locked, the Silent switch on, and a Focus mode on.
2. **What Option B costs, because you won't pay Apple.** Without Apple's paid
   membership, the only way to put this app on your iPhone is a free signature that
   **lapses every 7 days**. It must be renewed each week with this laptop on and your
   iPhone nearby. The app shows how many days are left. If a renewal is missed, the app
   stops opening, and **I do not yet know whether an alarm already set would still
   ring** (concern C6).
3. **The riskiest assumption is tested first.** I have not confirmed that AlarmKit works
   in an app signed with a free Apple ID. The first step of Build is a tiny test app on
   your phone. If it fails, the fallback is the web-app design (section 3.10).
4. **Weather** comes from Open-Meteo, a free service with no account or key: current
   conditions plus the next 6 hours, with the credit link its licence requires.
5. **The Windows alarm** rings from a clock check that runs every second, so it still
   fires on time after the laptop wakes or the clock changes.

## 2. What is guaranteed, and what is not

An alarm that fails to ring is worse than no alarm, so this table is part of the design
and is shown to the user in the app when they turn the alarm on.

| Situation | Windows app | iPhone native app |
|---|---|---|
| App open, screen on | Rings | Rings |
| Window minimized, or hidden to the tray | Rings | not applicable |
| Window closed with the X button | Rings (app hides to the tray) | not applicable |
| App quit from the tray menu | **Does not ring** (asks first if an alarm is on) | not applicable |
| Laptop asleep | **Does not ring** | not applicable |
| iPhone locked, or app closed | not applicable | Rings (system alarm), to be confirmed on your phone |
| iPhone Silent switch or a Focus mode on | not applicable | Designed to ring, to be confirmed on your phone |
| More than 7 days since the last renewal | not applicable | App will not open; a pending alarm **may not ring, unknown** |
| iPhone switched off or battery dead | not applicable | **Does not ring** |
| Loudness | In-app level (5 steps), capped by laptop volume | In-app level (5 steps), capped by iPhone volume |

**Your weekly duty (iPhone):** once every 7 days, with this laptop on and the iPhone on
the same Wi-Fi, AltStore renews the app's signature. The app shows "Signature expires
in N days" and warns when 2 days or fewer remain. For the first few weeks, also keep a
backup alarm in the iPhone Clock app.

## 3. Approach

### 3.1 Technology

- **Flutter** (Dart), one project, targets `windows` and `ios`.
- **iPhone alarm bridge:** a small piece of Swift code that talks to AlarmKit (ask
  permission, schedule, cancel, report Stop and Snooze). The Dart side sees it only
  through the `AlarmScheduler` interface (section 3.7).
- Everything visual (cat, digits, weather icons, app icon) is **drawn in code** as vector
  shapes. No third-party artwork or fonts, so there is nothing to license.
- Candidate packages, to be confirmed in Build against current versions: `window_manager`
  and `tray_manager` (Windows window and tray), `audioplayers` (sound previews and the
  Windows alarm), `geolocator` (location), `http`, `shared_preferences`.

### 3.2 Screen layout

```
+--------------------------------------------------------------+
|   ground line scrolls to the left as the cat walks right ->  |
|          /\_/\                                               |
|     ----( o.o )----- belly display (fixed, does not bob) --  |
|    |  7:42 PM        |  NOW  [sun] 54F                    |  |
|    |  blue digits    |  8PM [cloud] 54   9PM [cloud] 53   |  |
|    |                 | 10PM [rain]  51  11PM [rain]  50   |  |
|    |                 | 12AM [rain]  49   1AM [cloud] 48   |  |
|     -----------------------------------------------------   |
|        legs and tail animate                                 |
+--------------------------------------------------------------+
|  Alarm 6:30 AM  [ ON ]   Sound: Soft Chime   Volume: ---o-   |
|  Weather data by Open-Meteo.com     (iPhone: Signature: 5 d) |
+--------------------------------------------------------------+
```

- The **belly display** is one fixed-shape panel drawn at a design size of 960 x 420
  units and scaled to fit, so "weather to the right of the time" holds on a wide
  laptop window and on a narrow phone.
- Left to right inside the panel: the **time**, the **AM/PM letters**, then the
  **weather panel**: a large "Now" cell (icon and temperature) and six small cells
  (hour label, icon, temperature) for the next six hours.
- Minimum sizes on a 390-point-wide iPhone in portrait: time digits at least 70 points
  tall; weather icons at least 20 points; hour labels and temperatures at least 11
  points. Landscape gives larger sizes.
- Tapping the alarm bar opens the **alarm sheet**: time picker (12-hour with AM/PM),
  on/off, a **Repeat every day** switch, sound list with a 3-second preview on tap,
  volume slider (5 steps). On Windows only, the sheet also has a **Start with Windows**
  switch (section 3.8).
- **When the alarm rings:** on Windows the digits pulse once a second and **Stop** and
  **Snooze** buttons cover the alarm bar. On iPhone the system's own alarm screen
  shows Stop and Snooze (AlarmKit), because that is what works with the phone locked.

### 3.3 The cat

- Friendly cartoon cat, side view, facing right, walking in place.
- **Walk cycle:** 1 second per step cycle. Diagonal leg pairs swing in opposite phase,
  the tail sways, the head bobs slightly, and the cat blinks every 3 to 5 seconds. The
  ground line scrolls to the left at walking speed so it reads as walking.
- **The belly display never moves.** The body shape is drawn behind it and may bob by
  at most 2% of its height, but the panel is drawn in screen space on top, so the digits
  stay perfectly still and readable.
- Drawn at 24 frames per second at most. Animation pauses when the app is hidden or
  minimized. If the device's reduce-motion setting is on, the cat stands still.

### 3.4 Time and digits

- Digits are drawn as **seven-segment** shapes in **azure blue (about `#3FA9FF`)** with
  a soft glow, on a near-black navy panel (about `#0A1020`). Unlit segments are visible
  at about 12% strength, like a real LED clock. The colon blinks once a second (steady
  if reduce-motion is on).
- Contrast between lit digits and the panel must be at least 4.5 to 1 (my estimate for
  these colors is about 7 to 1; Build computes the exact figure in a test).
- **12-hour time** with a blank leading zero: `7:42`, `12:05`. The letters **AM** and
  **PM** are always both shown to the right of the digits; the active one is lit and
  the other is dim. Letters are drawn as simple strokes in the same blue.
- Seconds are not shown. The display updates when the minute changes.
- Conversion rule, covered by unit tests: hour 0 is `12 AM`, hour 12 is `12 PM`,
  hours 13 to 23 are `1 PM` to `11 PM`.
- The clock reads the device's local time and re-syncs whenever the app returns to the
  screen or the device changes time zone.

### 3.5 Weather

- **Source:** Open-Meteo forecast API. A test request from this laptop on 2026-11-11
  returned HTTP 200 with the expected fields. Request shape (checked):

  ```
  GET https://api.open-meteo.com/v1/forecast
      ?latitude={lat}&longitude={lon}
      &current=temperature_2m,weather_code,is_day
      &hourly=temperature_2m,weather_code,is_day
      &forecast_hours=7
      &temperature_unit={fahrenheit|celsius}
      &timezone=auto
  ```

  `forecast_hours=7` is deliberate: the first hourly entry is the **current hour**
  (a test with 6 returned 6 entries starting at the current hour), so entries 1 to 6
  are the next six hours. The `current` block fills the large "Now" cell.
- **Units:** Fahrenheit when the device region is the United States, Celsius
  otherwise. No settings toggle in version 1.
- **Location:** the device's location service while the app is in use, asked for with a
  plain-language explanation. Coordinates are **rounded to 2 decimals (about 1 km)**
  before they are sent, and only the last good result and its coordinates are kept, on
  the device.
- **When it refreshes:** at start, when the app comes back to the screen, every 15
  minutes while visible, and right after location permission is granted.
- **When something is wrong:** the last good result stays on screen. If it is more than
  30 minutes old it is dimmed with "updated 6:15 PM"; if it is more than 3 hours old or
  missing, every weather cell shows an "unavailable" icon. The clock and alarm are never
  affected.
- **Icons** (12, drawn in code, restrained colors so the blue digits stay the focus):

  | Icon | Open-Meteo weather codes |
  |---|---|
  | clear-day / clear-night | 0, 1 (by `is_day`) |
  | partly-day / partly-night | 2 (by `is_day`) |
  | cloudy | 3 |
  | fog | 45, 48 |
  | drizzle | 51, 53, 55 |
  | rain | 61, 63, 65, 80, 81, 82 |
  | sleet | 56, 57, 66, 67 |
  | snow | 71, 73, 75, 77, 85, 86 |
  | thunder | 95, 96, 97, 99 |
  | unavailable | anything else, or no data |

- **Attribution (required):** Open-Meteo's licence (CC BY 4.0) requires a link next to
  displayed data. The footer shows "Weather data by Open-Meteo.com" linking to
  `https://open-meteo.com/`.
- **Terms:** the free tier is for non-commercial use only, and apps with ads or
  subscriptions count as commercial. Personal use is fine. See concern C7.

### 3.6 Alarm behavior

- **One alarm:** `{ hour (0-23), minute, enabled, repeatDaily, soundId, volumeLevel (1-5) }`,
  saved on the device as a small JSON file. No account, no server.
- **Clock-change rules (tested):** if the chosen time does not exist on a day because
  clocks jump forward, the alarm rings at the first valid moment after it; if the time
  happens twice because clocks fall back, it rings the first time only.
- **States:** Off, Armed, Ringing, Snoozed, Missed.
  - Turn on: Off to Armed. Show the section 2 notice. On iPhone, the first time, the
    system asks for permission to schedule alarms; if you say no, the app explains that
    the alarm cannot be turned on.
  - Time reached: Armed to Ringing. Sound loops until stopped.
  - **Stop:** Ringing to Off, unless **Repeat every day** is on, in which case it goes
    back to Armed for the same time tomorrow. A Missed alarm also re-arms when repeat is
    on. On iPhone, repeating uses an AlarmKit schedule that repeats on all seven
    weekdays; to be confirmed in the first test.
  - **Snooze:** Ringing to Snoozed, then Ringing again after **9 minutes**. On iPhone
    this uses AlarmKit's repeat button with a 9-minute countdown; to be confirmed in the
    first test.
  - **No response for 10 minutes (Windows):** sound stops, state becomes Missed, and the
    bar shows "Alarm missed at 6:30 AM" until dismissed. On iPhone, how long the system
    alarm keeps ringing is decided by Apple; the first test records it.
- **Next ring time** is the next 6:30 AM (for example) strictly after now, in local
  time. It is recomputed whenever the app returns to the screen and whenever the time
  zone or clock changes.
- **Windows: a check every second, not one long timer.** Each second the app compares
  the current time with the ring time. If the laptop slept through it and wakes within
  10 minutes after, the alarm rings immediately; later than that, it is Missed.
- **iPhone: the system rings it.** The app schedules the alarm with AlarmKit and
  re-checks it each time the app opens, so a time-zone change is picked up.
- **Sounds:** six original sounds made by a script (no recordings): Classic Beep, Soft
  Chime, Morning Bells, Purr Rise, Meow Melody, Cat Bell. About 6 seconds each. Whether
  the iPhone system alarm repeats a short sound until stopped, or needs a longer file,
  is checked in the first test. Total sound files at most 6 MB per target. Concern C8
  covers quality.
- **Volume, Windows:** the audio player's volume set from the 5-step slider.
- **Volume, iPhone:** the system alarm is not under the app's volume control, so each
  sound is made in **5 pre-scaled loudness versions** and the slider picks the matching
  file. The iPhone's own volume still caps it. Whether this audibly works with AlarmKit
  is checked in the first test.

### 3.7 Parts and their boundaries

```
lib/
  app/        theme, app shell
  clock/      time ticker, 12-hour formatter
  cat/        cat painter, walk cycle, reduce-motion handling
  display/    seven-segment painter, AM/PM painter, belly panel layout
  weather/    OpenMeteoClient, WeatherRepository, code-to-icon map, icon painters, panel
  alarm/      Alarm model, AlarmStore, AlarmController (state machine), SoundCatalog, sheet UI
  platform/   windows/ (tray, window, in-app scheduler); ios/ (Swift AlarmKit bridge,
              signature-expiry reader)
assets/       sounds, icons
```

Interfaces that hide platform differences (each has a fake for tests):

- `Clock` (now), `AlarmScheduler` (arm, cancel, events), `SoundPlayer` (play, stop,
  preview), `LocationService`, `WeatherClient`, `Storage`, `SignatureInfo` (days left).
- `AlarmScheduler` has two real versions: `InAppScheduler` (Windows) and
  `AlarmKitScheduler` (iPhone). Everything else is shared.

### 3.8 Windows app details

- Closing the window hides it to the **tray**; the tray menu has Show and Quit. Quit
  while an alarm is on asks "Quitting will cancel your alarm" first.
- When the alarm rings while hidden, the window is restored, brought to the front, and
  flashes on the taskbar.
- **Installer:** a per-user Windows installer (no administrator rights) that adds a
  Start-menu shortcut with the cat icon. It will be **unsigned**, so Windows SmartScreen
  will show a warning the first time; "More info", then "Run anyway" gets past it.
- **Start with Windows (accepted at sign-off):** a switch in the alarm sheet, **off by
  default**. When on, the app starts at sign-in, hidden in the tray, using a per-user
  startup entry that needs no administrator rights. Turning the switch off, or
  uninstalling, removes the entry.
- **Not in version 1:** waking the laptop from sleep, and preventing sleep. Both change
  power behavior and need their own testing (concern C3).

### 3.9 iPhone app details

**Building it.** This laptop cannot compile iPhone apps, so a Mac in the cloud does it.
GitHub's macOS 26 runners include Xcode 26, which AlarmKit needs. The steps, from
community guides that I will re-check in Build: build with `flutter build ios --release
--no-codesign`, copy the resulting app into a `Payload` folder, zip it, and rename the
zip to `.ipa`. The result is unsigned on purpose; AltStore signs it in the next step.
Free-minute allowances differ for public and private repositories and are checked in
Build. Codemagic is the alternative cloud builder.

**Installing it.**
- Install **AltServer** on this laptop, which needs Apple's own **iTunes** and
  **iCloud** for Windows (the versions from Apple's website, not the Microsoft Store).
- Turn on **Developer Mode** on the iPhone. Connect it by USB once; later renewals work
  over Wi-Fi.
- AltStore signs the app with your free Apple ID and installs it.

**Keeping it alive.**
- The signature lasts **7 days**. AltStore renews it only while this laptop is running
  AltServer and the iPhone can reach it.
- Free accounts allow **three** sideloaded apps at once; AltStore itself counts as one.
  AltStore's own notes also cap new App IDs at 10 per 7 days.
- **Expiry warning (accepted at sign-off):** the app reads its own
  signature's expiry date and shows "Signature expires in N days", turning red at 2
  days or fewer. Whether the date can be read after AltStore re-signs is checked in the
  first test; if not, the line is hidden rather than wrong.

**AlarmKit requirements.** iOS **26 or later** (the app will not install on older
versions), a usage-description text in the app's settings file
(`NSAlarmKitUsageDescription`), the user's permission on first use, and custom sounds
bundled inside the app. Apple's session notes say alarms ring through Silent mode and
Focus.

### 3.10 Fallback: iPhone web app (only if the first test fails)

If AlarmKit does not work in a free-signed app, the same Flutter code can be built as a
web app and added to the iPhone Home Screen. It has no 7-day limit and needs no Mac, but
it **only rings while it is open on screen and the iPhone is awake and charging**, and
user reports say sound in Home Screen web apps on iOS 26 may work only the first time
after install. It needs free static hosting that you set up. Using it would mean
revising this spec and getting a new sign-off.

### 3.11 App icon

- One master cat-face icon drawn in code on a dark navy square (no transparency, as
  iOS requires), with two blue segment-style eyes and no text so it stays clear when
  small.
- Windows: a multi-size `.ico` (16, 24, 32, 48, 64, 128, 256). iPhone: the full set of
  sizes iOS asks for, generated from the 1024 x 1024 master.

## 4. Interfaces affected

- **Open-Meteo HTTP API** (read-only, no key): section 3.5.
- **Windows:** location service, audio output, system tray, installer shortcut.
- **iPhone:** CoreLocation (while in use), AlarmKit, the app's own signature file (for
  the days-left line), bundled sound files.
- **Build and install tools:** a cloud Mac runner, AltStore / AltServer, Apple's free
  Apple ID signing.
- **Stored on the device only:** alarm settings (JSON), last weather result and its
  rounded coordinates. Nothing is sent anywhere except the rounded coordinates to
  Open-Meteo. No account, no analytics, no ads.

## 5. How each intent item is met and checked

| Intent item | Design | Checked by |
|---|---|---|
| Cat, walking, time on belly | 3.2, 3.3 | Image comparison tests of the standing pose; test that the belly panel does not move between frames; reduce-motion test; you look at both devices |
| Blue digital numerals | 3.4 | Image tests for digits 0 to 9; computed contrast of at least 4.5 to 1 |
| AM / PM letters | 3.4 | Unit tests for 12:00 AM, 12:00 PM, 11:59 PM, 1:00 AM; image tests |
| Weather right of the time: now, temperature, next 6 hours | 3.2, 3.5 | Unit tests for every weather code in the table; parsing test on a saved Open-Meteo response; layout test that the weather panel starts to the right of the time; real-location check on both devices |
| Set an alarm, on/off | 3.6 | Unit tests for next ring time (including daylight saving changes) and for each state change |
| Alarm sounds at the time and can be stopped | 3.6 | Windows: tests with a fake clock and fake player, then a real test 2 minutes ahead. iPhone: real test only (section 6) |
| Choose the sound, with preview | 3.6 | Test that all six sounds load and play; you listen to each |
| Volume control | 3.6 | Test that each of the 5 steps maps to the right setting or file; you check that the loudness steps differ on both devices |
| Icon on laptop and phone | 3.11 | Test that the `.ico` holds all sizes; you check the Start menu and the Home Screen |
| Feels like one app | 3.1 | Same code on both; side-by-side check |

## 6. Verification plan

**Automated, run on this laptop:** unit tests, image tests, static analysis, and a
Windows build that launches. Phone-sized layouts are checked by resizing the Windows app
to phone proportions. The cloud Mac can prove the iPhone app **compiles**, but not that
it behaves correctly; behavior can only be checked on your phone.

**By you on real devices** (I cannot do these from here):

- *Windows:* (1) set an alarm 2 minutes ahead with the window minimized: rings.
  (2) Close the window with X: still rings. (3) Quit from the tray: no ring, as
  documented. (4) Put the laptop to sleep: no ring, as documented.
- *iPhone:* (1) Install through AltStore. (2) Alarm 2 minutes ahead with the app
  closed and the screen locked: rings. (3) Silent switch on: rings. (4) A Focus mode
  on: rings. (5) Snooze rings again after 9 minutes; Stop ends it. (6) The five volume
  steps are audibly different. (7) Renew through AltStore and confirm the days-left line
  resets. (8) In week 2, with a backup alarm set, see what happens to a pending test
  alarm if the signature is allowed to lapse, and write the answer down.

**Done for version 1** means all automated tests pass, the Windows checks pass, and
iPhone checks 1 to 6 pass on your phone, with check 7 working and check 8 recorded.
Anything that fails is written down rather than hidden.

## 7. Environment: what is missing, and what you need to provide

Found by a read-only check on 2026-11-11: **present** are the .NET SDK and VS Code;
**not found** are Flutter, Git, and Visual Studio's C++ build tools (Flutter needs them
to build Windows apps).

- **Installs on this laptop (each needs your OK):** Flutter, Git, Visual Studio 2022
  Build Tools with the "Desktop development with C++" workload (several gigabytes), the
  Windows installer tool, AltServer, and Apple's iTunes and iCloud for Windows.
- **Accounts you create yourself (I cannot create accounts):** a free GitHub account for
  the cloud Mac builds, and a free Apple ID for signing. I suggest a **spare Apple ID**
  (concern C11).
- **On the iPhone:** iOS 26 or later, Developer Mode turned on, and a USB cable for the
  first install.

## 8. Open concerns (for your sign-off)

| # | Concern | Why it matters | What I recommend |
|---|---|---|---|
| C1 | **Decided: Option B, native iPhone app.** Costs a signature renewal every 7 days. | Your choice on 2026-11-11. | Recorded. Fallback is section 3.10. |
| C2 | **AlarmKit in a free-signed app is unconfirmed.** Free accounts restrict some app capabilities; I could not find a source on AlarmKit specifically. | The whole iPhone alarm depends on it. | First Build step is a tiny AlarmKit test app on your phone. If it fails, stop and choose between the web fallback and a paid account. |
| C3 | **Windows must be awake and the app running.** | Otherwise no alarm. | **Decided: added** (3.8), off by default. Sleep-waking stays for later. |
| C4 | **One-time alarm.** The intent default has no repeat, so you must turn it on every night. | Easy to forget and oversleep. | **Decided: added** (3.6), as a switch in the alarm sheet. |
| C5 | **Windows battery use.** A constantly walking cat. | Battery on a laptop. | 24 frames per second cap, pause when minimized. On iPhone the system rings the alarm, so the animation matters only while the app is open. |
| C6 | **A missed weekly renewal** stops the app opening, and a pending alarm may not ring. Unknown until tested. | An alarm that fails silently is the worst outcome. | Days-left line and warning (3.9), a backup Clock alarm for the first weeks, and check 8 in section 6. |
| C7 | **Open-Meteo free tier is non-commercial,** and needs the credit link. | Fine for you; not if the app is ever sold or has ads. | Keep the footer link. Revisit if scope ever changes. |
| C8 | **Synthesized sounds, especially the meow and purr, may sound poor.** | Sound choice is a core feature. | Listen at Build; if weak, swap in properly licensed free recordings. |
| C9 | **Installs and accounts** (section 7). | Build cannot start without them. | I ask before each install. |
| C10 | **The Windows installer is unsigned** and shows a SmartScreen warning. | Surprise factor only. | Accept. |
| C11 | **AltStore asks for your Apple ID and password** to create the signature. They go to Apple, but through third-party software. | Account safety. | Use a spare Apple ID. You type the credentials yourself; I will never enter them. |
| C12 | **AltStore is a third-party tool;** Apple's rules or the tool could change, and the three-app cap applies. | The install route could break later. | Accept; the web fallback exists. |

## 9. Explicitly rejected alternatives

- **Paid Apple membership (TestFlight or normal install):** you said no.
- **iPhone web app as the main iPhone version:** free and does not expire, but cannot
  ring with the phone locked. Kept only as the fallback in 3.10.
- **Separate native apps (WinUI for Windows, SwiftUI for iPhone):** two codebases, the
  cat would drift apart, and iPhone builds still need a Mac.
- **React Native / Expo:** Windows support is a separate add-on project.
- **.NET MAUI:** iPhone builds need a paired Mac.
- **Notification-only alarm on iPhone (no AlarmKit):** notification sounds follow the
  Silent switch and are short, so it is not a dependable alarm.
- **Letting the iPhone Clock app do the ringing through Shortcuts:** reliable, but loses
  the in-app sound and volume choices and needs manual setup. Kept as the advice for
  backup alarms only.
- **Server push notifications as the alarm:** needs a server and an account, sends
  data, and cannot loop a chosen sound.
- **Waking or keeping Windows awake in version 1:** changes power settings; needs its
  own test. Later.

## 10. What comes next

After sign-off, `plan.md` lists the files to change, the order of work, the risks, and
the proof for each step. The order starts with the **AlarmKit test app** (C2): a
bare-bones iPhone app that sets one alarm for two minutes ahead, built on the cloud Mac,
installed with AltStore, and checked with the phone locked and on Silent. Everything
else waits on that answer.

## 11. Sign-off (Design gate)

Nothing is built until a human accepts this file.

- [x] **C1:** iPhone version is **B (native app, weekly renewal)** — chosen by the product owner in chat, 2026-11-11
- [x] I accept the alarm guarantees in section 2, including the unknown in the "more than 7 days" row
- [x] **C3:** add a "Start with Windows" switch — **yes**
- [x] **C4:** add a "Repeat every day" switch — **yes**
- [x] **Days-left line** (section 3.9): include — **yes**
- [x] I agree to the installs and accounts in section 7, each confirmed when it happens
- **Decision:** accepted  **By:** product owner (via chat: "Yes, sign off", answering "Sign off the spec with all three recommended additions?")  **Date:** 2026-11-11
