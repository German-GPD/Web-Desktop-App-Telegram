# Static project validation
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$required = @(
    "README.md", "LICENSE",
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
    "index.html", "assets\site.js", "assets\telegram.svg", "assets\telegram.ico",
    ".github\workflows\windows-build.yml"
)
foreach ($relative in $required) {
    if (!(Test-Path (Join-Path $root $relative))) { throw "Required project file is missing: $relative" }
}

[xml](Get-Content (Join-Path $root "src\Telegram.Desktop\Telegram.Desktop.csproj") -Raw) | Out-Null
[xml](Get-Content (Join-Path $root "src\Telegram.Desktop\App.xaml") -Raw) | Out-Null
[xml](Get-Content (Join-Path $root "src\Telegram.Desktop\MainWindow.xaml") -Raw) | Out-Null
[xml](Get-Content (Join-Path $root "src\Telegram.Desktop\app.manifest") -Raw) | Out-Null
[xml](Get-Content (Join-Path $root "src\Telegram.Desktop\SettingsWindow.xaml") -Raw) | Out-Null

$project = Get-Content (Join-Path $root "src\Telegram.Desktop\Telegram.Desktop.csproj") -Raw
if ($project -notmatch "TargetFramework>net8.0-windows") { throw ".NET 8 Windows target is missing." }

$appSource = Get-Content (Join-Path $root "src\Telegram.Desktop\App.xaml.cs") -Raw
if ($appSource -notmatch "Mutex" -or $appSource -notmatch "ActivationEventName") { throw "Single-instance activation is missing." }

$settingsSource = Get-Content (Join-Path $root "src\Telegram.Desktop\AppSettings.cs") -Raw
if ($settingsSource -notmatch "ZoomFactor" -or $settingsSource -notmatch "Theme" -or $settingsSource -notmatch "ToolbarOrder") { throw "Persistent settings are incomplete." }
if ($settingsSource -match "IconMode|CustomIconPath") { throw "User-selectable app icon settings must be removed." }

$settingsWindow = Get-Content (Join-Path $root "src\Telegram.Desktop\SettingsWindow.xaml") -Raw
if ($settingsWindow -notmatch "ThemeBox" -or $settingsWindow -notmatch "ZoomSlider" -or $settingsWindow -notmatch "ToolbarList") { throw "Settings UI controls are missing." }
if ($settingsWindow -match "IconModeBox|BrowseIcon_Click|Иконка приложения") { throw "The icon selector must not appear in settings." }

$source = Get-Content (Join-Path $root "src\Telegram.Desktop\MainWindow.xaml.cs") -Raw
if ($source -notmatch 'https://web\.telegram\.org/a/') { throw "The official Telegram Web A URL is missing." }
if ($source -notmatch "EnsureCoreWebView2Async" -or $source -notmatch "DownloadStarting") { throw "WebView2 initialization or download handling is missing." }
if ($source -notmatch "PermissionRequested" -or $source -notmatch "CoreWebView2PermissionState.Allow") { throw "Camera and microphone permission prompts are missing." }
if ($source -notmatch "SHA256.HashDataAsync" -or $source -notmatch "checksumAsset") { throw "Updater SHA-256 verification is missing." }
if ($source -notmatch "ApplyTelegramIcon" -or $source -match "ApplyCustomIcon|CustomIconPath") { throw "The fixed Telegram app icon is not wired correctly." }
if ($source -notmatch "UpdateWindowsShortcutIcons") { throw "The Telegram icon is not propagated to Windows shortcuts." }

$iss = Get-Content (Join-Path $root "installer\Telegram.iss") -Raw
if ($iss -match "IconChoicePage|CustomIconPage|CreateInputOptionPage|CreateInputFilePage") { throw "The installer must not ask the user to choose an icon." }
if ($iss -notmatch "Telegram.ico" -or $iss -notmatch "PrivilegesRequired=lowest") { throw "Installer icon or per-user install configuration is missing." }
if ($iss -notmatch "Check: IsWebView2Installed") { throw "The installer must not launch the app before WebView2 is installed." }
if ($iss -notmatch "Tasks: startmenu" -or $iss -notmatch "Tasks: desktopicon") { throw "Optional shortcut tasks are missing." }

$xaml = Get-Content (Join-Path $root "src\Telegram.Desktop\MainWindow.xaml") -Raw
if ($xaml -notmatch "DynamicResource ChromeBackground") { throw "The adaptive Windows chrome is missing." }
if ($xaml -match 'Text="web.telegram.org/a/"') { throw "The browser-style address pill should not be shown in the app shell." }

$build = Get-Content (Join-Path $PSScriptRoot "build.ps1") -Raw
if ($build -notmatch "New-TelegramIcon" -or $build -notmatch "ApplicationIcon" -or $build -notmatch "FillPath") { throw "The Telegram paper-plane icon is not generated and embedded." }
if ($build -notmatch "Copy-Item.*Telegram.ico") { throw "The portable build is missing the app icon file." }

$site = Get-Content (Join-Path $root "index.html") -Raw
if ($site -notmatch 'releases/latest/download/Telegram-Setup\.exe') { throw "The website installer link is not a direct release download." }
if ($site -notmatch 'assets/telegram\.svg') { throw "The website is not using the Telegram logo." }
if ($site -match 'chatgpt|What can I help with|ChatGPT') { throw "The website still contains the old AI product mockup." }

$siteScript = Get-Content (Join-Path $root "assets\site.js") -Raw
if ($siteScript -notmatch "telegram-desktop-theme" -or $siteScript -notmatch "prefers-color-scheme") { throw "The website theme preference is not correctly namespaced." }

$workflow = Get-Content (Join-Path $root ".github\workflows\windows-build.yml") -Raw
if ($workflow -notmatch "softprops/action-gh-release" -or $workflow -notmatch "APP_VERSION") { throw "The release workflow is incomplete." }
if ($workflow -notmatch "Telegram-Setup.exe.sha256") { throw "Release checksum generation is missing." }

Write-Host "Static validation passed." -ForegroundColor Green
