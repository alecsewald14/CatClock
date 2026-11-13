# Renewing Cat Clock every week

An app installed with a free Apple ID stops working after **7 days**. Renewing signs it
again and starts a fresh 7 days. It takes about a minute.

Where AltStore's own instructions differ from the ones below, follow AltStore's:
<https://faq.altstore.io>.

## How you know when it is due

The line at the bottom of Cat Clock counts down:

| What it says | What it means |
|---|---|
| Signature: 6 days left, down to 3 days left | Fine |
| Signature: 2 days left, 1 day left (red, bold) | Renew now |
| Signature expires today (red, bold) | Renew right away |
| Signature expired (red, bold) | The app has lapsed. See "If you missed it" |

The number counts down, so "6 days left" never claims more than you have.

AltStore also shows the days left for each app, in its **My Apps** tab.

## The steps

You need the laptop turned on, **AltServer running** (icon near the clock), and the phone
on the same Wi-Fi.

1. Open **AltStore** on the iPhone.
2. Tap **My Apps**.
3. Tap the **days** button on the Cat Clock row (it says, for example, "2 DAYS"), or tap
   **Refresh All** at the top.
4. Type your Apple ID password if AltStore asks. That sign-in is yours; I never see it.
5. Wait for "Refreshed". Open Cat Clock and check the line at the bottom: it should say 6
   days left (just under 7, counted down).

AltStore can also refresh by itself in the background when the laptop and phone are on the
same Wi-Fi. Do not rely on it. Pick one day a week and do the steps yourself, for example
every Sunday evening.

If AltStore cannot reach the laptop, check that AltServer is running and that the phone is
on the same Wi-Fi. If it still fails, plug the phone into the laptop with the cable, unlock
it, and try again.

## If you missed it

1. Cat Clock will not open, or closes straight away.
2. Do the same steps above. If the Cat Clock row still shows expired, hold **Shift**, click
   the AltServer icon, choose **Sideload .ipa**, and install `CatClock.ipa` again (see
   [install-iphone.md](install-iphone.md)).
3. Open Cat Clock and set the alarm again if it is off. Your saved alarm should still be
   there, but do not count on it.

## Do not rely on Cat Clock alone yet

**What happens to an alarm that is already set when the signature lapses is not known.**
Whether Apple's alarm service still rings for an app whose signature has ended has not
been tested. This is spec check 8, planned for week 2.

Until that is written down in [results.md](results.md):

- Keep a **backup alarm in the iPhone Clock app** for any wake-up that matters.
- Renew **before** you go to bed on the day it says "2 days left" or less.
- Do not travel or go away for more than a few days without renewing first, because the
  laptop must be on and nearby for a renewal.

## Good to know

- You do not need to renew if you stop using the app. It just stops opening.
- Free Apple IDs allow 3 sideloaded apps at once. If you add another app, an older one may
  need to go.
- A renewal signs the app that is already on the phone again. It does not need the file.
  Whether every saved setting survives a renewal has not been checked on a phone.
