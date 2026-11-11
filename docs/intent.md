# Intent: Cat alarm clock (Windows laptop + iPhone)

- **Requested by:** Project owner (the requester), 2026-11-11
- **Author:** Claude, drafted from the requester's own words
- **Status:** ACCEPTED on 2026-11-11 by the product owner. The proposed items and the suggested defaults stand as written.
- **Next artifact:** `spec.md` (Design stage), started after this approval.

> How to read this file: the "What they said" section is the request exactly as given.
> Everything after it is Claude's interpretation. Items marked **(proposed)** are
> suggestions the product owner has not yet asked for, so confirm or strike each one.

---

## What they said

> A software alarm clock app, shaped like a cat, with versions that run on my windows laptop, my iphone, with the following features: with blue digital numbers, with AM and PM letters, with an alarm setting feature, volume control, options for the alarm sound, includes an icon for the application on my laptop and phone, with weather icons on the right side of the time that indicates the weather in the present time and location of the device.

## Problem

The requester wants a personal alarm clock with character: a clock that looks like a
cat, shows the time in a distinctive blue digital style, wakes them up with a sound
they chose, and shows the current weather at a glance. They want the same app on two
devices they own, a Windows laptop and an iPhone. No deadline or trigger was stated.

*Interpretation to confirm:* the goal is a delightful, personal, everyday-use clock,
not a commercial product. Reliability of the alarm matters more than any decoration.

## Proposed outcome

When this work is done, on **both** the Windows laptop and the iPhone, the requester can:

- [ ] **See a cat.** The main screen is a cat-shaped clock, not a generic rectangle with
      a cat sticker on it. It is a friendly cartoon cat that moves as if it is walking,
      with the time shown on its belly.
- [ ] **Read the time in blue digital numerals.** The numbers look like a digital
      (segmented-display) clock and are blue.
- [ ] **See AM or PM.** The time is shown in 12-hour form with the letters AM or PM
      visible next to it.
- [ ] **See the weather beside the time.** Weather icons sit on the **right side** of the
      time and show the **current** conditions with the **temperature**, plus the weather
      icon and temperature for each of the **next 6 hours**, at the **device's current
      location**.
- [ ] **Set an alarm.** They can choose an alarm time and turn the alarm on and off.
- [ ] **Hear the alarm at that time.** The alarm sounds at the chosen time and they can
      stop it.
- [ ] **Choose the alarm sound.** They can pick from several sound options and hear a
      preview before choosing.
- [ ] **Control the volume.** They can adjust how loud the alarm is.
- [ ] **Find the app by its icon.** A cat-themed app icon appears where apps are launched
      on each device (Windows Start menu / taskbar, iPhone home screen).
- [ ] **Feel it is one app.** The two versions look and behave recognisably the same.

## Affected users and systems

- **Users:** one person, the requester, for personal use.
- **Windows laptop.** This session runs on Windows 11 Home; confirm that this is the
  target laptop.
- **iPhone.** Model and iOS version are not known (see open questions).
- **External dependencies:**
  - a source of current weather data (needs internet access);
  - the device's location service (needs the user's permission);
  - each operating system's facilities for scheduling and playing alarms;
  - the device speakers and volume system.

## Constraints

Stated or implied by the request:

- **Platforms:** Windows laptop and iPhone only.
- **Content:** blue digital numerals, AM/PM letters, weather icons to the right of the
  time, cat shape, and a launcher icon on both devices are all required as written.
- **Weather meaning:** "present time and location of the device" means live, current
  conditions for wherever the device is now, not a fixed city.

Known from the environment (the spec must deal with these, not assume them away):

- **Building for iPhone from Windows.** iPhone apps are normally built with Apple's
  tooling (a Mac with Xcode, or a cloud build service). Installing on a personal iPhone
  for more than a short trial usually needs Apple's paid developer membership. The
  spec must pick a route and state what the requester needs to provide. Verify these
  details at Design time; they change.
- **Alarm reliability.** An alarm that fails to ring is worse than no alarm. Windows and
  iOS both limit what an app can do when it is closed, the screen is locked, the phone
  is on silent, or the laptop is asleep. The spec must say exactly what is guaranteed
  on each platform and what is not.
- **Weather depends on permission and network.** If location is denied or the device is
  offline, the clock and alarm must keep working and the weather area must show a clear
  "unavailable" state rather than wrong data or a crash.

Proposed (confirm or strike):

- **Privacy (proposed):** location is used only to fetch weather, only the coarse
  location needed is sent, and there are no accounts, ads, or analytics.
- **Assets (proposed):** the cat artwork, icon, and alarm sounds are original or properly
  licensed. No copyrighted audio or art.
- **Legibility (proposed):** blue digits stay readable from across a room and in a dark
  bedroom.
- **Cost (proposed):** no ongoing paid services; any weather source is free to use for
  one person.

## Explicitly out of scope (proposed)

- Publishing to the Apple App Store or Microsoft Store.
- Android, macOS, Linux, or web versions.
- User accounts, cloud sync, sharing, or social features.
- Weather maps, alerts, or any forecast beyond the next 6 hours.
- Sleep tracking, smart-home links, or any feature not listed above.

## Open questions

Each has a suggested default so the product owner can answer "yes" or correct it.

1. **Cat design.** Friendly cartoon cat? Which color? Where does the time appear (belly
   screen, eyes, a display held by the cat)? *Default: cartoon cat with the time on a
   display on its body.*
2. **How many alarms, and what happens when it rings?** *Default for v1: one alarm
   time with on/off, a Stop button, and a Snooze button; no repeating days.*
3. **What does "volume control" mean?** An in-app alarm volume slider, or just following
   the device's volume? iOS and Windows restrict how an app can override device volume
   and silent mode. *Default: an in-app alarm volume slider on both, with a test play;
   the spec states the limits per platform.*
4. **Alarm sounds.** How many, and what style? *Default: 5 to 8 original sounds, some
   cat-themed.*
5. **Seconds.** Show seconds? *Default: hours and minutes only, plus AM/PM.*
6. **Weather icons.** One icon for the current condition (with day and night versions)
   or several? Show the temperature too? How often does it refresh? *Default: one icon
   for current conditions, no temperature, refreshed periodically and when the app
   opens.*
7. **Windows behavior.** Must the alarm ring if the app is minimized? If the laptop is
   asleep? *Default: rings while the app is running, including minimized; waking the
   laptop from sleep is evaluated in the spec and not promised yet.*
8. **iPhone details.** Which iPhone and iOS version? Newer iOS versions offer an alarm
   facility that can ring through Silent mode and Focus; older ones rely on notification
   sounds, which are shorter and follow silent settings. The answer decides what is
   possible.
9. **iPhone install path.** Do you have access to a Mac? Are you willing to pay for
   Apple's developer membership, or is a short-lived test install enough for now?
10. **App name.** *Default working title: "Cat Clock".*
11. **Colors.** Blue digits on what background? *Default: dark background.*

## Answers given by the product owner (2026-11-11)

These replace the suggested defaults for the questions they answer. Every other open
question keeps its suggested default.

- **Q1, cat design:** a friendly cartoon cat that moves as if it is walking, with the
  time shown on its belly. (This adds animation, which the original request did not
  mention.)
- **Q6, weather:** show the temperature and the weather for the next 6 hours, in
  addition to current conditions. (This widens the scope from "current conditions only.")
- **Q8, iPhone:** a newer iOS version. The exact version was not stated; the spec
  assumes iOS 26 or later.
- **Q9, iPhone install path:** will **not** pay for Apple's developer membership. This
  rules out the usual install routes for a native iPhone app. The spec must work within
  free options and say plainly what that costs. The question about access to a Mac was
  not answered.

## Scope additions accepted at Design sign-off (2026-11-11)

These go beyond the original request. They were proposed in `spec.md` and accepted by
the product owner.

- A **Repeat every day** switch for the alarm.
- A **Start with Windows** switch (off by default) on the Windows app.
- A **days-left line** on the iPhone app showing when its 7-day signature expires.
- The iPhone version is a **native app** (not a web app), renewed every 7 days with a
  free Apple ID, as chosen by the product owner.

## Approval gate

This is the Plan-stage gate. A human, the product owner, confirms that this file says
what they meant, corrects what Claude got wrong, and decides to accept or reject it.
Only an accepted `intent.md` goes on to Design.

- [x] Summary of the problem matches what I meant
- [x] Proposed items above are confirmed or struck
- [x] Open questions answered or given a default
- **Decision:** accepted  **By:** product owner (via chat: "now i approve everything")  **Date:** 2026-11-11

*This folder is not yet a git repository. The playbook records the accept or reject
decision in git history (as a merge or closing review), so initialize one before
approval, or record the decision in the lines above for now.*

## What happens next

`intent.md` (this file) → `spec.md` (Design: approach, interfaces, flagged concerns,
sign-off) → `plan.md` (Build: files that change, order of work, risks, proof) → code
with tests → review. Each stage ends with a human decision before the next begins.
