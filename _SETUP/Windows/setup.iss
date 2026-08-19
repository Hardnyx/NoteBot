; NoteBot installer.
;
; The installation is deliberately per user: NoteBot stores its notes under
; %LOCALAPPDATA% and never needs administrator rights, so asking for elevation only
; added a UAC prompt and a machine-wide startup entry that did not belong to a
; single-user application.

#define AppVersion GetEnv("NOTEBOT_VERSION")
#define SourceDir GetEnv("NOTEBOT_SOURCE_DIR")
#define PackageOutputDir GetEnv("NOTEBOT_OUTPUT_DIR")
#define LicenseSource GetEnv("NOTEBOT_LICENSE_FILE")

#if AppVersion == ""
  #define AppVersion "1.8.0"
#endif

; Identifier of the 1.7.x and earlier packages, which installed for all users.
#define LegacyAppId "{3E658137-CE80-49E3-8084-FD0B0158CA31}"

[Setup]
AppId={{7A2F1C64-9B3D-4F52-A0E7-2C48D5B61F09}
AppName=NoteBot
AppVersion={#AppVersion}
AppVerName=NoteBot {#AppVersion}
AppPublisher=Alonso Roman
AppCopyright=Original copyright 2016-2020 Federico Dossena; modifications copyright 2026 Alonso Roman
AppPublisherURL=https://github.com/adolfintel/NoteBot
AppSupportURL=https://github.com/adolfintel/NoteBot
AppUpdatesURL=https://github.com/adolfintel/NoteBot/releases
AppReadmeFile={app}\LICENSE.txt
DefaultDirName={localappdata}\Programs\NoteBot
DefaultGroupName=NoteBot
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
OutputDir={#PackageOutputDir}
OutputBaseFilename=NoteBot-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\NoteBot.exe
UninstallDisplayName=NoteBot
VersionInfoCompany=Alonso Roman
VersionInfoCopyright=Original copyright 2016-2020 Federico Dossena; modifications copyright 2026 Alonso Roman
VersionInfoDescription=NoteBot installer
VersionInfoVersion={#AppVersion}
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
MinVersion=10.0
SetupMutex=NoteBotSetupMutex
; Reputation heuristics look at how much an installer describes itself. Complete metadata,
; a real uninstall entry and no elevation request are what keep a legitimate unsigned
; installer out of the generic-detection buckets. UninstallDisplayName is already set above.
UsePreviousAppDir=yes
UsePreviousTasks=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
; Unchecked by default: writing to the Run key without being asked is both a surprise for
; the user and a common heuristic trigger.
Name: "startup"; Description: "{cm:StartWithWindows}"; GroupDescription: "{cm:StartupGroup}"; Flags: unchecked

[CustomMessages]
english.StartWithWindows=Start NoteBot when I sign in
english.StartupGroup=Startup:
english.RemoveLegacy=A version of NoteBot installed for all users was found. It has to be removed first. Your notes are not affected. Continue?
spanish.StartWithWindows=Iniciar NoteBot al iniciar sesion
spanish.StartupGroup=Inicio:
spanish.RemoveLegacy=Se encontro una version de NoteBot instalada para todos los usuarios. Debe quitarse primero. Tus notas no se ven afectadas. Continuar?
italian.StartWithWindows=Avvia NoteBot all'accesso
italian.StartupGroup=Avvio:
italian.RemoveLegacy=E' stata trovata una versione di NoteBot installata per tutti gli utenti. Deve essere rimossa prima. Le tue note non sono interessate. Continuare?

[InstallDelete]
Type: files; Name: "{app}\StickyNotes.exe"
Type: files; Name: "{app}\StickyNotes.jar"
Type: filesandordirs; Name: "{app}\jre"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#LicenseSource}"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\NoteBot"; Filename: "{app}\NoteBot.exe"
Name: "{autodesktop}\NoteBot"; Filename: "{app}\NoteBot.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "NoteBot"; ValueType: string; ValueData: """{app}\NoteBot.exe"" -autostartup"; Flags: uninsdeletevalue; Tasks: startup
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "NoteBot"; ValueType: none; Flags: deletevalue; Tasks: not startup

[Run]
Filename: "{app}\NoteBot.exe"; Description: "{cm:LaunchProgram,NoteBot}"; Flags: nowait postinstall skipifsilent

[Code]
function GetLegacyUninstallString(): String;
var
  UninstallKey: String;
  Value: String;
begin
  Result := '';
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#LegacyAppId}_is1';

  if RegQueryStringValue(HKEY_LOCAL_MACHINE, UninstallKey, 'UninstallString', Value) then
    Result := RemoveQuotes(Value)
  else if RegQueryStringValue(HKEY_CURRENT_USER, UninstallKey, 'UninstallString', Value) then
    Result := RemoveQuotes(Value);
end;

function InitializeSetup(): Boolean;
var
  UninstallCommand: String;
  ResultCode: Integer;
begin
  Result := True;
  UninstallCommand := GetLegacyUninstallString();

  if UninstallCommand = '' then
    Exit;

  if MsgBox(ExpandConstant('{cm:RemoveLegacy}'), mbConfirmation, MB_YESNO) <> IDYES then
  begin
    Result := False;
    Exit;
  end;

  // Notes live in %LOCALAPPDATA%\NoteBot and are untouched by this uninstall.
  Exec(UninstallCommand, '/SILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
end;
