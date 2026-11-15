#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef PublishDir
  #define PublishDir "..\\artifacts\\publish"
#endif
#ifndef OutputDir
  #define OutputDir "..\\artifacts\\installer"
#endif
#ifndef IconDir
  #define IconDir "..\\artifacts\\icons"
#endif

[Setup]
AppId={{A31E7D42-4B6C-4D8A-9F21-6C2A7E51B903}
AppName=Telegram Desktop
AppVersion={#AppVersion}
AppPublisher=German-GPD
AppPublisherURL=https://github.com/German-GPD/Web-Desktop-App-Telegram
SetupIconFile={#IconDir}\\Telegram-Accent.ico
DefaultDirName={localappdata}\\Programs\\German-GPD\\Telegram Desktop
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
LicenseFile=..\\LICENSE

[Files]
Source: "{#PublishDir}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#IconDir}\\Telegram-Accent.ico"; DestDir: "{app}"; DestName: "Custom.ico"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\\Telegram"; Filename: "{app}\\Telegram.exe"; IconFilename: "{app}\\Custom.ico"; Tasks: startmenu
Name: "{autodesktop}\\Telegram"; Filename: "{app}\\Telegram.exe"; IconFilename: "{app}\\Custom.ico"; Tasks: desktopicon

[Tasks]
Name: "startmenu"; Description: "Create a Start menu shortcut"; GroupDescription: "Shortcuts:"
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Run]
Filename: "{app}\\Telegram.exe"; Description: "Launch Telegram Desktop"; Flags: postinstall nowait skipifsilent

[Code]
var
  IconChoicePage: TInputOptionWizardPage;
  CustomIconPage: TInputFileWizardPage;

function IsWebView2Installed: Boolean;
var
  Version: String;
begin
  Result :=
    (RegQueryStringValue(HKLM, 'SOFTWARE\\WOW6432Node\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> '')) or
    (RegQueryStringValue(HKCU, 'Software\\Microsoft\\EdgeUpdate\\Clients\\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}', 'pv', Version) and (Version <> ''));
end;

procedure InitializeWizard;
begin
  IconChoicePage := CreateInputOptionPage(wpSelectDir,
    'Application icon', 'Choose the icon for Telegram Desktop.',
    'The standard Telegram icon is selected by default. You can also use your own ICO file.',
    True, False);
  IconChoicePage.Add('Use the standard Telegram icon');
  IconChoicePage.Add('Use my own .ico file');
  IconChoicePage.SelectedValueIndex := 0;

  CustomIconPage := CreateInputFilePage(IconChoicePage.ID,
    'Custom application icon', 'Choose your own Windows icon.',
    'Select an .ico file:');
  CustomIconPage.Add('ICO file:', 'Windows icon (*.ico)|*.ico', '.ico');
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = CustomIconPage.ID) and (IconChoicePage.SelectedValueIndex = 0);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  SelectedFile: String;
begin
  Result := True;
  if CurPageID = CustomIconPage.ID then
  begin
    SelectedFile := CustomIconPage.Values[0];
    if (SelectedFile = '') or (not FileExists(SelectedFile)) or
       (Lowercase(ExtractFileExt(SelectedFile)) <> '.ico') then
    begin
      MsgBox('Choose an existing Windows .ico file, or go back and select the standard icon.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

function InitializeSetup: Boolean;
begin
  Result := True;
  if not IsWebView2Installed then
    Result := MsgBox('Microsoft Edge WebView2 Runtime was not detected. Telegram Desktop needs it. Continue and open the official download page afterwards?',
      mbConfirmation, MB_YESNO) = IDYES;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ErrorCode: Integer;
  SelectedFile: String;
begin
  if CurStep = ssPostInstall then
  begin
    if IconChoicePage.SelectedValueIndex = 1 then
    begin
      SelectedFile := CustomIconPage.Values[0];
      if not FileCopy(SelectedFile, ExpandConstant('{app}\\Custom.ico'), False) then
        RaiseException('The selected icon could not be copied into the application folder.');
      if not RegWriteStringValue(HKCU, 'Software\GermanGPD\Telegram', 'InstalledIconMode', 'Custom') then
        RaiseException('The selected icon preference could not be saved.');
    end
    else
    begin
      if not RegWriteStringValue(HKCU, 'Software\GermanGPD\Telegram', 'InstalledIconMode', 'Default') then
        RaiseException('The icon preference could not be saved.');
    end;

    if not IsWebView2Installed then
      ShellExec('', 'https://developer.microsoft.com/microsoft-edge/webview2/', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
  end;
end;
