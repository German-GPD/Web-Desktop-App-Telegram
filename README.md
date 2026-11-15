# Telegram Desktop

A dedicated Windows desktop window for the official Telegram Web client, built with C# WPF, .NET 8 and Microsoft WebView2.

[![Windows](https://img.shields.io/badge/Windows-10%20%2F%2011-229ED9)](https://www.microsoft.com/windows)
[![.NET](https://img.shields.io/badge/.NET-8-512BD4)](https://dotnet.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-229ED9)](LICENSE)

## Features

- Official Telegram Web A: https://web.telegram.org/a/
- Dedicated persistent WebView2 profile; sign-in survives app restarts.
- Compact Windows 11-style 44 px top bar.
- Light, dark and system themes.
- Website zoom from 80% to 150%.
- Custom ICO icon and configurable toolbar order/visibility.
- Single-instance activation.
- Download handling and camera/microphone permission prompts.
- Optional Start Menu and desktop shortcuts.
- No autostart and no system-tray process.
- Portable self-contained publish, Windows installer and SHA-256 checksum.
- GitHub Actions build and release workflow.

## Download

Download the latest `Telegram-Setup.exe` from [GitHub Releases](https://github.com/German-GPD/Web-Desktop-App-Telegram/releases/latest).

## Requirements

- Windows 10 (1809+) or Windows 11, x64.
- Microsoft Edge WebView2 Evergreen Runtime.
- For building: .NET 8 SDK and Inno Setup 6.

The installer checks for WebView2 Runtime and can open Microsoft's official download page if it is missing.

## Build

Run PowerShell from the repository root:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\build.ps1
```

Outputs:
- `artifacts\publish\Telegram.exe` — portable publish output.
- `artifacts\installer\Telegram-Setup.exe` — Windows installer.

## Privacy

Telegram Web authentication and site data are stored in the local WebView2 profile:
`%LOCALAPPDATA%\GermanGPD\Telegram\WebView2`.

Settings are stored under `%LOCALAPPDATA%\GermanGPD\Telegram`. The app does not intentionally collect analytics or send telemetry. Do not share the WebView2 profile folder because it may contain active session data.

This is an independent web wrapper. It does not modify Telegram or bypass its authentication. Telegram controls its service, account security and website behavior.

## Disclaimer

Independent project by **German-GPD**. Not affiliated with or endorsed by Telegram Messenger Inc. Telegram is a trademark of its respective owner.

MIT License — see [LICENSE](LICENSE).
