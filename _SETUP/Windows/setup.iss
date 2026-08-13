#define AppVersion GetEnv("NOTEBOT_VERSION")
#define SourceDir GetEnv("NOTEBOT_SOURCE_DIR")
#define PackageOutputDir GetEnv("NOTEBOT_OUTPUT_DIR")

#if AppVersion == ""
  #define AppVersion "1.7.0"
#endif

[Setup]
AppId={{3E658137-CE80-49E3-8084-FD0B0158CA31}
AppName=NoteBot
AppVersion={#AppVersion}
AppPublisher=Alonso Roman
DefaultDirName={autopf}\NoteBot
DefaultGroupName=NoteBot
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=gpl-3.0.txt
OutputDir={#PackageOutputDir}
OutputBaseFilename=NoteBot-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\NoteBot.exe
VersionInfoCompany=Alonso Roman
VersionInfoCopyright=Original copyright 2016-2020 Federico Dossena; modifications copyright 2026 Alonso Roman
VersionInfoDescription=NoteBot installer
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
Type: files; Name: "{app}\StickyNotes.exe"
Type: files; Name: "{app}\StickyNotes.jar"
Type: filesandordirs; Name: "{app}\jre"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\NoteBot"; Filename: "{app}\NoteBot.exe"
Name: "{autodesktop}\NoteBot"; Filename: "{app}\NoteBot.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\NoteBot.exe"; Description: "{cm:LaunchProgram,NoteBot}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "NoteBot"; ValueType: string; ValueData: """{app}\NoteBot.exe"" -autostartup"; Flags: uninsdeletevalue
