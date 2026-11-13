# Installing Cat Clock on your iPhone

Cat Clock is installed the free way, with **AltStore** and your own Apple ID. Apple only
lets a free install last **7 days**, so you renew it once a week. The steps for that are in
[weekly-renewal.md](weekly-renewal.md).

You do these parts yourself because they involve your accounts. I never type your
passwords. Where AltStore's own instructions differ from the ones below, follow
AltStore's: <https://faq.altstore.io>.

## What you need

- Your iPhone, running iOS 26 or later, with **AltStore** and **Developer Mode** already
  set up. You did both in the Phase 1 test, so there is nothing new to install.
- This Windows laptop, turned on, **AltServer running** (its icon is near the clock), and
  on the same Wi-Fi as the iPhone. Have the USB cable ready in case the Wi-Fi does not
  connect.
- A backup alarm in the iPhone Clock app for any real wake-up until you trust Cat Clock.

## 1. Get the file

1. Open the build page in your browser (sign in to GitHub if it asks):

   <https://github.com/alecsewald14/CatClock/actions/runs/43375158742>

2. At the bottom, in the **Artifacts** box, download **CatClock-unsigned-ipa**. It
   downloads as a zip.
3. Unzip it. Inside is **CatClock.ipa** (about 12 MB).

GitHub keeps the file for 14 days. After that, open the **Actions** tab, pick the newest
green run of "Cat Clock for iPhone", and download it from there. Or ask me for a new build.

## 2. Put it on the phone

1. Unlock the iPhone and keep it on the same Wi-Fi as the laptop.
2. **Hold Shift** and click the AltServer icon near the clock. Choose **Sideload .ipa**,
   then choose your iPhone, then pick **CatClock.ipa**.
3. Type your Apple ID password **when AltServer asks**. That sign-in is yours; I never see
   it.
4. Wait until AltServer says it finished. **Cat Clock** appears on the Home Screen.

**If it says you have too many apps:** a free Apple ID can have 3 apps at once, and
AltStore may count as one. The Phase 1 test app, **Alarm Spike**, is no longer needed.
Delete it from the phone, then try again.

If the install fails for any other reason, copy the exact message AltServer shows and send
it to me.

## 3. First use

1. Open **Cat Clock**. A question asks to use your location while the app is open. Choose
   **Allow While Using App**. It is only used to find the weather, and only coordinates
   rounded to about 1 km are sent.
2. Tap the strip under the cat, choose a time, and turn the alarm **on**. The first time,
   iPhone asks to allow alarms. Choose **Allow**.
3. If you said no by mistake, the app shows a line saying so. Turn alarms on for Cat Clock
   in the iPhone's Settings, then turn the alarm on again.

When the alarm rings, the screen you see is **Apple's own alarm screen**, with Stop and
Snooze buttons. That is how it can ring with the phone locked, the app closed, and on
Silent. The cat is not shown there.

## 4. What I could and could not check

I checked, on this laptop and in the cloud:

- The app builds into an installable file on a cloud Mac.
- All automated tests pass, and the code analysis finds no problems.
- The names and settings used by the app and by the iPhone part match, and the file's
  settings (iOS 26 or later, alarm permission text, location text) are present.

**Nobody has yet seen this app run on a phone.** Only the Phase 1 test app was seen
working. Everything in the table is therefore **unknown** until you try it. You said you
would rather not run through a long test, so each row can be skipped, but a skipped row
stays "unknown" in [results.md](results.md).

| # | Try this | Should happen | Result |
|---|---|---|---|
| 1 | Open the app | The cat and the time appear. The line at the bottom says "Signature: 6 days left" (just under 7 days, counted down) | unknown |
| 2 | Turn the alarm on for 2 minutes ahead, lock the phone, swipe the app away | Rings at the time, with Apple's alarm screen | unknown |
| 3 | Same, with the Silent switch on | Still rings | unknown |
| 4 | Same, with a Focus mode on | Still rings | unknown |
| 5 | When it rings, tap Snooze | Rings again after 9 minutes; Stop ends it | unknown |
| 6 | Set volume 1, then 5 in the alarm sheet; ring each | Five steps are clearly different in loudness | unknown |
| 7 | Turn on "Repeat every day" and check the next morning | Rings again without opening the app | unknown |
| 8 | Renew through AltStore (see the renewal guide) | The days-left line goes back to "6 days left" | unknown |
| 9 | Look at the weather panel | Shows the weather for where you are | unknown |

Tell me the row numbers and what happened, and I will record it in `docs/results.md`.

## Uninstall

Press and hold the Cat Clock icon on the Home Screen, choose **Remove App**, then
**Delete App**. Your Apple ID and the phone's settings are not changed.
