# Phase 1 results: AlarmKit on a free-signed app

- **Plan reference:** `plan.md`, Phase 1 and gate G1
- **Test guide:** [phase1-iphone-test.md](phase1-iphone-test.md)
- **Status:** G1 PASSED on 2026-11-12. The key checks passed; several secondary checks
  were **not run**, by the product owner's choice. They are listed as unverified below and
  are carried into Phase 7.

## Setup actually used

| Item | Value |
|---|---|
| iPhone model | iPhone 14 Plus |
| iOS version | 26.7.2 (as reported by the product owner) |
| Build source | GitHub Actions, workflow "Phase 1 test app", run #4 (`phase-1/alarmkit-test`) |
| Install method | AltServer on Windows, free Apple ID, "Sideload .ipa" |
| Signature | Readable by the app: expiry shown as Nov 19, "6 days" left on Nov 12 |
| Date tested | 2026-11-12 |

The newer alert form (iOS 26.1 and later) was the one in use on this phone. The iOS 26.0
fallback code path has not been run.

## Results

Results are as reported by the product owner in chat. Details marked "not recorded" were
not given.

| # | Question | Result | Notes |
|---|---|---|---|
| 1 | Permission question appears | Not recorded | Tests that followed worked, so permission was granted |
| 2 | Rings with phone locked and app closed (check b) | **PASS** | Rang on schedule. Screen was Apple's plain system alarm screen |
| 2 | Sound repeats until stopped? How long? (check e) | Reported as pass | Exact length not recorded |
| 3 | Rings with Silent switch on (check c) | **PASS** | |
| 4 | Rings with a Focus mode on (check d) | **PASS** | |
| 5 | Snooze button shows and re-rings after 1 minute (check f) | **PASS** | No widget extension was needed for this basic snooze |
| 6 | 9-minute snooze enters a countdown state | **Not run** | |
| 7 | Daily repeat works, including the next day (check g) | **Not run** | |
| 8 | Level 5 is clearly louder than level 1 (check h) | **Not run** | The pre-scaled loudness idea is unverified |
| 8 | Which iPhone volume setting changes alarm loudness | **Not run** | |
| 9 | Signature expiry date readable (check i) | **PASS** | Showed Nov 19, 6 days left |
| 10 | Behavior when the app is open on screen | **Not run** | |

## What this means

- **AlarmKit works in an app signed with a free Apple ID**, on this phone. It rings
  locked, with the app closed, on Silent, and in a Focus mode, and the Snooze button
  works. This was the biggest risk in the plan (spec concern C2).
- **The signature really lapses weekly.** The test app was signed on Nov 12 and shows an
  expiry of Nov 19. The days-left line works as designed.

## Unverified items carried into Phase 7

These were not tested, so they must be treated as unknown, not as working:

1. **Volume levels.** Whether five pre-scaled sound files give audibly different
   loudness, and which iPhone volume control affects the alarm. If the files do not
   differ audibly, the in-app volume slider changes design.
2. **Daily repeat.** Whether a repeating alarm rings on following days with the app never
   reopened.
3. **9-minute snooze** state, and the alarm behavior with the app open on screen.
4. **How long the sound repeats** if left alone.
5. **A lapsed signature.** What happens to a pending alarm after 7 days with no renewal
   (spec concern C6, and check 8 of the spec's own list). Still unknown.

Each of these will be checked in the real app in Phase 7 and Phase 8 instead.

## Gate G1 decision

- **Pass:** checks b, c, and d work. Go on to the iPhone app (Phase 7).
- **Fail on b, c, or d:** stop. Choose between the web-app fallback (spec 3.10) and
  another route.
- **Fail only on e to i:** adjust that one piece of the design and carry on.

**Decision:** passed (b, c, d all work)  **By:** product owner, who chose to skip the
remaining secondary tests  **Date:** 2026-11-12
