; Inno Setup script for Cat Clock (Windows).
; Build the app first (flutter build windows --release), then compile this file with
; Inno Setup's ISCC.exe. The result is build\installer\CatClock-Setup-<version>.exe.
;
; The installer is per-user: no administrator rights, installs under the user's own
; Programs folder, adds a Start-menu shortcut, and registers an uninstaller. It is NOT
; signed, so Windows SmartScreen shows a warning the first time ("More info", then
; "Run anyway").

#define AppName "Cat Clock"
#define AppVersion "1.0.0"
#define AppExe "cat_clock.exe"
#define SourceDir "..\build\windows\x64\runner\Release"

[Setup]
; Keeps upgrades and the uninstaller pointed at the same app. Never change it.
AppId={{8B7E5C1A-3D52-4F0B-9A64-2C1E7D9F4A10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Cat Clock
DefaultDirName={autopf}\Cat Clock
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\build\installer
OutputBaseFilename=CatClock-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; The app hides in the tray instead of closing, so it is stopped in the code below.
CloseApplications=no
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Start {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Removes the "Start with Windows" entry if the person had turned it on.
Filename: "{sys}\reg.exe"; Parameters: "delete ""HKCU\Software\Microsoft\Windows\CurrentVersion\Run"" /v CatClock /f"; Flags: runhidden; RunOnceId: "RemoveStartWithWindows"

[Code]
// Cat Clock lives in the tray when its window is closed, so ask Windows to end it before
// files are replaced or removed. This only ever ends the current user's own copy.
procedure StopRunningApp;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM {#AppExe}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  StopRunningApp;
  Result := '';
end;

function InitializeUninstall(): Boolean;
begin
  StopRunningApp;
  Result := True;
end;

// After uninstalling, offer to delete the saved alarm and settings. The answer is "no"
// when the uninstaller runs silently, so nothing is deleted without being asked.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    if SuppressibleMsgBox('Also delete your saved alarm and settings?', mbConfirmation, MB_YESNO or MB_DEFBUTTON2, IDNO) = IDYES then
      DelTree(ExpandConstant('{userappdata}\app.catclock'), True, True, True);
  end;
end;
