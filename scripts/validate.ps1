# Static project validation
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$required = @(
    "README.md",
    "LICENSE",
    "src\Telegram.Desktop\Telegram.Desktop.csproj",
    "src\Telegram.Desktop\App.xaml",
    "src\Telegram.Desktop\App.xaml.cs",
    "src\Telegram.Desktop\AppSettings.cs",
    "src\Telegram.Desktop\SettingsWindow.xaml",
    "src\Telegram.Desktop\SettingsWindow.xaml.cs",
    "src\Telegram.Desktop\MainWindow.xaml",
    "src\Telegram.Desktop\MainWindow.xaml.cs",
    "src\Telegram.Desktop\app.manifest",
    "installer\Telegram.iss",
    "index.html",
    "assets\site.js",
    ".github\workflows\windows-build.yml"
)

foreach ($relative in $required) {
    $path = Join-Path $root $relative
    if (!(Test-Path $path)) { throw "Required project file is missing: $relative" }
}

[xml](Get-Content (Join-Path $root "src\Telegram.Desktop\Telegram.Desktop.csproj") -Raw) | Out-Null
[xml](Get-Content (Join-Path $root "src\Telegram.Desktop\App.xaml") -Raw) | Out-Null
[xml](Get-Content (Join-Path $root "src\Telegram.Desktop\MainWindow.xaml") -Raw) | Out-Null
[xml](Get-Content (Join-Path $root "src\Telegram.Desktop\app.manifest") -Raw) | Out-Null

$project = Get-Content (Join-Path $root "src\Telegram.Desktop\Telegram.Desktop.csproj") -Raw
if ($project -match "ApplicationIcon|Telegram\.ico") { throw "The app should not ship with a bundled icon." }

$appSource = Get-Content (Join-Path $root "src\Telegram.Desktop\App.xaml.cs") -Raw
if ($appSource -notmatch "Mutex" -or $appSource -notmatch "ActivationEventName") { throw "Single-instance activation is missing." }

$settingsSource = Get-Content (Join-Path $root "src\Telegram.Desktop\AppSettings.cs") -Raw
if ($settingsSource -notmatch "ZoomFactor" -or $settingsSource -notmatch "Theme" -or $settingsSource -notmatch "ToolbarOrder" -or $settingsSource -notmatch "IconMode") { throw "Persistent settings are incomplete." }

$settingsWindow = Get-Content (Join-Path $root "src\Telegram.Desktop\SettingsWindow.xaml") -Raw
[xml]$settingsWindow | Out-Null
if ($settingsWindow -notmatch "ThemeBox" -or $settingsWindow -notmatch "ZoomSlider" -or $settingsWindow -notmatch "ToolbarList" -or $settingsWindow -notmatch "BrowseIcon_Click") { throw "Settings UI controls are missing." }

$source = Get-Content (Join-Path $root "src\Telegram.Desktop\MainWindow.xaml.cs") -Raw
if ($source -notmatch 'https://web\.telegram\.org/a/') { throw "The official Telegram start URL is missing." }
if ($source -notmatch 'LocalApplicationData') { throw "The persistent per-user browser profile is not configured." }
if ($source -notmatch 'EnsureCoreWebView2Async') { throw "WebView2 initialization is missing." }
if ($source -notmatch 'PreviewKeyDown') { throw "Keyboard shortcuts are not wired to the window." }
if ($source -notmatch 'DownloadStarting') { throw "Custom WebView2 download handling is missing." }
if ($source -notmatch 'PermissionRequested' -or $source -notmatch 'CoreWebView2PermissionState.Allow') { throw "Camera and microphone permission prompts are missing." }
if ($source -notmatch 'PreferredColorScheme.Auto') { throw "WebView2 is not configured to follow the system color scheme." }
if ($source -notmatch 'DwmSetWindowAttribute') { throw "Windows system backdrop support is missing." }

$xaml = Get-Content (Join-Path $root "src\Telegram.Desktop\MainWindow.xaml") -Raw
if ($xaml -match 'Icon="Assets/Telegram\.ico"') { throw "The window must not reference the removed bundled icon." }
if ($xaml -notmatch 'DynamicResource ChromeBackground') { throw "The adaptive translucent app chrome is missing." }
if ($xaml -match 'Text="web.telegram.org/a/"') { throw "The browser-style address pill should not be shown in the app shell." }

$site = Get-Content (Join-Path $root "index.html") -Raw
if ($site -notmatch 'releases/latest/download/Telegram-Setup\.exe') { throw "The website installer link is not a direct release download." }

$siteScript = Get-Content (Join-Path $root "assets\site.js") -Raw
if ($siteScript -notmatch 'prefers-color-scheme') { throw "The website does not respect the system color scheme." }

$workflow = Get-Content (Join-Path $root ".github\workflows\windows-build.yml") -Raw
$iss = Get-Content (Join-Path $root "installer\Telegram.iss") -Raw
if ($workflow -notmatch 'softprops/action-gh-release') { throw "The Windows installer release step is missing." }
if ($workflow -notmatch 'APP_VERSION') { throw "The build version is not configured." }

if ($iss -notmatch "CreateInputOptionPage" -or $iss -notmatch "CreateInputFilePage" -or $iss -notmatch "SelectedValueIndex := 0") { throw "Installer icon selection must default to the branded icon and allow a custom ICO." }
if ($iss -notmatch "Telegram-Accent.ico" -or $iss -notmatch "FileCopy\(SelectedFile") { throw "Installer does not install the selected icon." }
if ($iss -notmatch "Tasks: startmenu" -or $iss -notmatch "Tasks: desktopicon") { throw "Optional shortcut tasks are missing." }
if ($source -notmatch "SHA256.HashDataAsync" -or $source -notmatch "checksumAsset") { throw "Updater SHA-256 verification is missing." }
if ($workflow -notmatch "Generate installer SHA-256 checksum" -or $workflow -notmatch "Telegram-Setup.exe.sha256") { throw "Release checksum generation is missing." }

if ($iss -notmatch "PrivilegesRequired=lowest" -or $iss -notmatch "DefaultDirName=\{localappdata\}") { throw "The installer must use a writable per-user installation directory." }
if ($source -notmatch "ApplyCustomIcon" -or $source -notmatch "PersistentIconDirectory" -or $source -notmatch "UpdateWindowsShortcutIcons" -or $source -notmatch "SHChangeNotify") { throw "The selected icon is not propagated to Windows shortcuts." }
if ($source -notmatch "ApplyToolbarSettings" -or $source -notmatch "HiddenToolbarItems") { throw "Toolbar customization is not applied." }

Write-Host "Static validation passed." -ForegroundColor Green
