# Installing Cat Clock on Windows

## Install

1. Run `CatClock-Setup-1.0.0.exe`. After a build it is here:

   ```
   C:\Users\alecs\Documents\CatClock\build\installer\CatClock-Setup-1.0.0.exe
   ```

2. **Windows will probably show a blue "Windows protected your PC" box.** That is because
   the installer is not signed with a paid certificate. Click **More info**, then **Run
   anyway**.
3. Follow the steps. It does not ask for an administrator password: it installs into your
   own folder, `%LOCALAPPDATA%\Programs\Cat Clock`.
4. On the last page, leave **Start Cat Clock** ticked.

It adds a **Cat Clock** shortcut to the Start menu. A desktop shortcut is offered but is
off unless you tick it.

If Cat Clock is already running (it hides in the tray), the installer closes it first,
which would cancel an alarm you had set. Set it again afterwards.

## Use

- Click the strip under the cat to set the alarm. See the in-app help text, and
  [windows-tryout.md](windows-tryout.md) for a tour.
- Closing the window keeps the app running in the tray so the alarm can ring. Quit it from
  the tray icon's menu.
- The laptop must be awake for the alarm to ring.
- **Start with Windows** is a switch in the alarm sheet. It is off by default.

## Uninstall

Open Windows **Settings, Apps, Installed apps**, find **Cat Clock**, and choose
**Uninstall**. It removes the program, the Start-menu shortcut, and the "Start with
Windows" entry if you had turned it on. At the end it asks whether to **also delete your
saved alarm and settings**. They are kept unless you say yes.

Your saved alarm and settings are in `%APPDATA%\app.catclock`. You can delete that folder
yourself any time the app is not running.

## For developers: making the installer

1. `flutter build windows --release`
2. Compile `installer\CatClock.iss` with Inno Setup's compiler:

   ```
   "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" installer\CatClock.iss
   ```

The version number in the script must match `pubspec.yaml`; a test checks that.
