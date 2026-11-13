# Trying the Windows app (gate G2)

This is the Phase 5 test build. It is not installed; you run it straight from its folder.
Phase 6 adds the installer and the final cat icon (the tray icon is already the cat).

**To start it:** open this folder, inside the project folder (`Documents\CatClock`), in
File Explorer and double-click `cat_clock.exe`:

```
build\windows\x64\runner\Release
```

Keep the other files in that folder next to it. Nothing is written outside your own user
folder, except the optional "Start with Windows" entry (see test 8).

## What to try

1. **The look.** You should see the cat, the time in blue digits with AM or PM, and live
   weather for where you are. If the weather says location is off, turn it on in Windows
   Settings, Privacy & security, Location, and allow desktop apps. It should recover by
   itself within a few minutes.
2. **Set an alarm for 2 minutes ahead.** Click the strip at the bottom. Tap the big time
   and choose a time. Choosing a time turns the alarm on.
3. **Sounds and volume.** In the same sheet, tap the play button beside each of the six
   sounds, and drag the volume slider through its five steps. Is each step clearly
   different? Which sounds do you like? Do the three cat sounds sound like a cat, or
   like a synthesizer? (They are made by arithmetic, so the meow is the least certain.)
4. **Let it ring with the window open.** When the time comes the sound plays, the
   digits pulse, and the strip is replaced by **Stop** and **Snooze 9 min**. Try both.
   After Snooze it should ring again about 9 minutes later.
5. **Close the window with the X.** The first time, a notice appears. After that the
   window disappears, and a cat icon should be near the clock (it may be behind the small
   up-arrow). Left-click it to bring the window back. Right-click it for Show and Quit.
6. **Let it ring while it is in the tray.** Set another alarm 2 minutes ahead, close the
   window, and wait. The window should come back to the front, and the taskbar button
   should flash.
7. **Repeat every day.** Turn that switch on, let the alarm ring, press Stop, and check
   the strip says it is set for tomorrow.
8. **Start with Windows (optional).** Turn the switch on. Tell me, and I will check the
   entry with a read-only query. Turn it off again when you are done. Turning it off
   removes the entry.
9. **Quit.** With an alarm on, right-click the tray icon and choose Quit. It should ask
   first.
10. **Second copy.** With the window hidden, double-click `cat_clock.exe` again. The
    window should come back, and no second copy should start.

## Things that are expected, not bugs

- With the laptop asleep, the alarm does not ring. That is in the plan; version 1 does
  not wake the laptop.
- If you quit the app from the tray, the alarm is cancelled.
- The Windows volume (and the speaker) still sets how loud the top level is.

## Tell me

For each test number: worked, or what went wrong. Also, in a few words: the sounds, the
volume steps, and anything that felt confusing or ugly.

## If something goes wrong

The app keeps a short log of problems at
`%APPDATA%\app.catclock\cat_clock\problems.log`. It never holds your location or alarm
details. To forget everything the app saved, quit it and delete the folder
`%APPDATA%\app.catclock`.
