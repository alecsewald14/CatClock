# Phase 1 results: AlarmKit on a free-signed app

- **Plan reference:** `plan.md`, Phase 1 and gate G1
- **Test guide:** [phase1-iphone-test.md](phase1-iphone-test.md)
- **Status:** NOT RUN YET. This file is filled in after the tests on your phone.

## Setup actually used

| Item | Value |
|---|---|
| iPhone model | |
| iOS version | |
| Build source | GitHub Actions, workflow "Phase 1 test app" |
| Install method | AltStore (free Apple ID) |
| Date tested | |

## Results

| # | Question | Result | Notes |
|---|---|---|---|
| 1 | Permission question appears, and what it says | | |
| 2 | Rings with phone locked and app closed (check b) | | |
| 2 | Sound repeats until stopped? How long? (check e) | | |
| 3 | Rings with Silent switch on (check c) | | |
| 4 | Rings with a Focus mode on (check d) | | |
| 5 | Snooze button shows and re-rings after 1 minute (check f) | | |
| 6 | 9-minute snooze enters a countdown state (check f) | | |
| 6 | Snooze needed anything extra (widget extension)? | | |
| 7 | Daily repeat works, including the next day (check g) | | |
| 8 | Level 5 is clearly louder than level 1 (check h) | | |
| 8 | Which iPhone volume setting changes alarm loudness | | |
| 9 | Signature expiry date readable (check i) | | |
| 10 | Behavior when the app is open on screen | | |

## Gate G1 decision

- **Pass:** checks b, c, and d work. Go on to the iPhone app (Phase 7).
- **Fail on b, c, or d:** stop. Choose between the web-app fallback (spec 3.10) and
  another route.
- **Fail only on e to i:** adjust that one piece of the design and carry on.

**Decision:** ______  **By:** ______  **Date:** ______
