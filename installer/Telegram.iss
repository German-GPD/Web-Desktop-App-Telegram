#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef PublishDir
  #define PublishDir "..\artifacts\publish"
#endif
#ifndef OutputDir
  #define OutputDir "..\artifacts\installer"
#endif
#ifndef IconDir
  #define IconDir "..\artifacts\icons"
#endif

[Setup]
AppId={{A31E7D42-4B6C-4D8A-9F21-6C2A7E51B903}
AppName=Telegram Desktop
AppVersion={#AppVersion}
AppPublisher=German-GPD
AppPublisherURL=https://github.com/German-GPD/Web-Desktop-App-Telegram
SetupIconFile={#IconDir}\Telegram.ico
DefaultDirName={localappdata}\Programs\German-GPD\Telegram Desktop
DefaultGroupName=Telegram Desktop
OutputDir={#OutputDir}
OutputBaseFilename=Telegram-Setup
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
PrivilegesRequired=lowest
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
DisableProgramGroupPage=yes
CloseApplications=yes
RestartApplications=no
LicenseFile=..\LICENSE

[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Telegram"; Filename: "{app}\Telegram.exe"; IconFilename: "{app}\Telegram.ico"; Tasks: startmenu
Name: "{autodesktop}\Telegram"; Filename: "{app}\Telegram.exe"; IconFilename: "{app}\Telegram.ico"; Tasks: desktopicon

[Tasks]
Name: "startmenu"; Description: "Create a Start menu shortcut"; GroupDescription: "Shortcuts:"
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Run]
Filename: "{app}\Telegram.exe"; Description: "Launch Telegram Desktop"; Flags: postinstall nowait skipifsilent; Check: IsWebView2Installed

[Code]
function IsWebView2Installed: Boolean;
var
  Version: String;
begin
  Result :=
    (RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> '')) or
    (RegQueryStringValue(HKCU, 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> ''));
end;

function InitializeSetup: Boolean;
begin
  Result := True;
  if not IsWebView2Installed then
    Result := MsgBox('Microsoft Edge WebView2 Runtime was not detected. Telegram Desktop needs it. Continue installation and open the official Microsoft download page afterwards?', mbConfirmation, MB_YESNO) = IDYES;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ErrorCode: Integer;
begin
  if (CurStep = ssPostInstall) and (not IsWebView2Installed) then
    ShellExec('', 'https://developer.microsoft.com/microsoft-edge/webview2/', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
end;
