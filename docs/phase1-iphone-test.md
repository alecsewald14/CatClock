# Phase 1: test whether an alarm rings on your iPhone

This test answers one question before anything else is built: **does Apple's alarm
feature (AlarmKit) work in an app installed the free way, with your own Apple ID?**
If it does, the iPhone app goes ahead as planned. If it does not, we stop and choose
another route (see `spec.md`, section 3.10).

You do these parts yourself because they involve your accounts. I never type your
passwords. Where AltStore's own instructions differ from the ones below, follow
AltStore's: <https://faq.altstore.io>.

Plan for about 45 minutes of setup, plus short waits during the tests.

## What you need

- Your iPhone, running iOS 26 or later, and its USB cable.
- This Windows laptop, turned on, on the same Wi-Fi as the iPhone.
- A free GitHub account (part A).
- A free Apple ID. A spare one is safer than your main one, because AltStore signs
  apps with it (part B).
- A backup alarm in the iPhone Clock app for any real wake-up while testing.

## Part A: GitHub (once)

1. Sign up at <https://github.com> if you have no account.
2. Create a new repository:
   - Name: `cat-clock` (or any name; tell me what you chose).
   - Visibility: **Public**.
   - Leave "Add a README", ".gitignore", and "license" **unticked**, so it starts empty.
3. Send me the repository address, which looks like `https://github.com/YOURNAME/cat-clock`.
4. I will ask you again before I send the code there. When I do, a Windows or browser
   window will ask you to sign in to GitHub. That sign-in is yours; I never see it.
5. After the code is there, open the repository's **Actions** tab. A build named
   "Phase 1 test app" starts by itself. When it shows a green tick, open it and download
   the file called **AlarmSpike-unsigned-ipa** from the "Artifacts" box at the bottom.
   It downloads as a zip; unzip it to get `AlarmSpike.ipa`. (GitHub asks you to be
   signed in to download.)

## Part B: AltStore on Windows and iPhone (once)

1. Install **iTunes** and **iCloud for Windows** from Apple's website (the versions on
   apple.com, not the Microsoft Store ones). AltStore needs these.
2. Install **AltServer** for Windows from AltStore's website, <https://altstore.io>, and
   start it. Its icon appears near the clock in the taskbar.
3. Plug in the iPhone, unlock it, and tap **Trust** when asked.
4. In iTunes, open the iPhone's page and tick **Sync with this iPhone over Wi-Fi**.
   This is what lets weekly renewals work without the cable.
5. Click the AltServer icon, choose **Install AltStore**, and pick your iPhone. Enter
   your Apple ID and password **when AltServer asks**.
6. On the iPhone, turn on **Developer Mode**: Settings, Privacy & Security, Developer
   Mode. The phone restarts.
7. If the iPhone says the app is from an untrusted developer, go to Settings, General,
   VPN & Device Management, and trust your Apple ID.

## Part C: install the test app

1. Hold **Shift** and click the AltServer icon. Choose **Sideload .ipa**, pick
   `AlarmSpike.ipa`, and choose your iPhone.
2. Open **Alarm Spike** on the iPhone. The top of the screen shows the iOS version, the
   alarm permission, and a line starting "Signature expires".

If the install fails, copy the exact message AltServer shows and send it to me.

## Part D: the tests

Keep the iPhone's ringer and volume at a normal level. Each test uses the buttons in the
app. The log at the bottom of the app records what the system does.

Before testing, set the loudness stepper to **3**.

| # | Do this | What to watch for |
|---|---|---|
| 1 | Tap **1. Allow alarms** | Does a permission question appear? What does it say? Tap Allow. |
| 2 | Tap **2. Ring in 2 min (no snooze)**, then **lock the phone and swipe the app away** | At about 2 minutes: does it ring with the phone locked and the app closed? What does the screen show? Does the beeping keep repeating until you stop it, or does it stop by itself? About how many seconds? |
| 3 | Flip the **Silent switch** on (or Silent mode), repeat test 2 | Does it still ring? |
| 4 | Turn on a **Focus** mode such as Do Not Disturb, repeat test 2 | Does it still ring? |
| 5 | Tap **3. Ring in 2 min, snooze 1 min**, lock the phone | When it rings, is there a **Snooze** button? Tap it. Does it ring again about a minute later? Is the countdown shown on the lock screen? |
| 6 | Tap **4. Ring in 2 min, snooze 9 min** and tap Snooze when it rings | The app should hold a 9-minute snooze. You do not need to wait the whole time; check the log shows the alarm in a countdown state. Then tap **Cancel all alarms**. |
| 7 | Tap **5. Daily repeat, first ring in about 3 min** | It should ring once at that time. Afterwards, does the "Alarms the system holds" list still show it as scheduled for tomorrow? Check again tomorrow without opening the app: does it ring? Then Cancel all alarms. |
| 8 | Set the stepper to **1**, run test 2; then set it to **5**, run test 2 | Is level 5 clearly louder than level 1? Then change the **ringer volume** and the **media volume** (Settings, Sounds & Haptics) and run again. Which one changes how loud the alarm is? |
| 9 | Look at the top of the app | Does the "Signature expires ... (N days left)" line show a date? Is N about 7? |
| 10 | Tap Cancel all alarms, set a 2-minute alarm, and **keep the app open on screen** | What happens when it rings with the app in front? |

## Part E: send me the results

Tell me, for each test number, what happened. A short list is enough. Screenshots of the
log help but are not required. I record them in `docs/spike-alarmkit.md`.

## After the test

The signature on this test app lasts 7 days. You can delete the app any time. Nothing
here changes your Apple ID or your iPhone's settings beyond turning on Developer Mode.
