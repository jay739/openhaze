; Inno Setup script for OpenHaze. Produces a real installer (Start Menu
; shortcut, optional desktop shortcut and "start with Windows", a proper
; Add/Remove Programs entry) instead of shipping the raw compiled .exe as if
; it were one. Per-user install, no admin elevation required, matching the
; project's "no permission prompts" design.
;
; Built by CI via `iscc installer.iss`; OPENHAZE_VERSION is passed with /D.
#ifndef OPENHAZE_VERSION
  #define OPENHAZE_VERSION "0.0.0-dev"
#endif

[Setup]
AppId={{CC44C3A5-153D-496D-AD3F-B81B247C68DD}
AppName=OpenHaze
AppVersion={#OPENHAZE_VERSION}
AppPublisher=Jayakrishna Konda
AppPublisherURL=https://github.com/jay739/openhaze
DefaultDirName={localappdata}\Programs\OpenHaze
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2
SolidCompression=yes
SetupIconFile=Support\AppIcon.ico
UninstallDisplayIcon={app}\OpenHaze.exe
OutputDir=dist
OutputBaseFilename=OpenHaze-{#OPENHAZE_VERSION}-Setup
WizardStyle=modern
; OpenHaze runs continuously as a tray app; close it automatically (via
; Restart Manager) rather than failing to overwrite/delete a running .exe.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
Name: "startupicon"; Description: "Start OpenHaze automatically when Windows starts"

[Files]
Source: "OpenHaze.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\OpenHaze"; Filename: "{app}\OpenHaze.exe"
Name: "{autodesktop}\OpenHaze"; Filename: "{app}\OpenHaze.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "OpenHaze"; ValueData: """{app}\OpenHaze.exe"""; Tasks: startupicon; Flags: uninsdeletevalue

[Run]
Filename: "{app}\OpenHaze.exe"; Description: "Launch OpenHaze"; Flags: nowait postinstall skipifsilent
