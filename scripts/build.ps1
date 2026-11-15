param([string]$Configuration = "Release", [string]$Runtime = "win-x64", [string]$AppVersion = "1.0.0")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "src\Telegram.Desktop\Telegram.Desktop.csproj"
$publish = Join-Path $root "artifacts\publish"
$installerOut = Join-Path $root "artifacts\installer"
$iconDirectory = Join-Path $root "artifacts\icons"
$iconFile = Join-Path $iconDirectory "Telegram.ico"

Write-Host "== Telegram Desktop: validate, restore and build ==" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "validate.ps1")

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Path $iconDirectory -Force | Out-Null

function New-TelegramIcon([string]$Path) {
    $bitmap = [System.Drawing.Bitmap]::new(256, 256)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([System.Drawing.Color]::Transparent
    )
    $graphics.ScaleTransform(4, 4)

    $blue = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 34, 158, 217))
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
    $plane = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $stream = $null
    $icon = $null

    try {
        $graphics.FillEllipse($blue, 0, 0, 64, 64)
        $plane.StartFigure()
        $plane.AddLine(12.2, 30.3, 49.1, 16.1)
        $plane.AddBezier(49.1, 16.1, 50.8, 15.4, 52.3, 16.5, 51.8, 18.8)
        $plane.AddLine(51.8, 18.8, 45.5, 48.3)
        $plane.AddBezier(45.5, 48.3, 45.0, 50.4, 43.8, 50.9, 42.0, 49.8)
        $plane.AddLine(42.0, 49.8, 31.8, 42.3)
        $plane.AddLine(31.8, 42.3, 26.6, 47.3)
        $plane.AddBezier(26.6, 47.3, 26.0, 47.9, 25.5, 48.4, 24.4, 48.4)
        $plane.AddLine(24.4, 48.4, 25.2, 37.6)
        $plane.AddLine(25.2, 37.6, 44.9, 19.8)
        $plane.AddBezier(44.9, 19.8, 45.8, 19.0, 44.7, 18.6, 43.7, 19.4)
        $plane.AddLine(43.7, 19.4, 19.3, 36.7)
        $plane.AddLine(19.3, 36.7, 9.5, 33.6)
        $plane.AddBezier(9.5, 33.6, 7.4, 32.9, 7.3, 31.4, 9.9, 30.3)
        $plane.CloseFigure()
        $graphics.FillPath($white, $plane)

        $handle = $bitmap.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($handle)
        $stream = [System.IO.File]::Create($Path)
        $icon.Save($stream)
    }
    finally {
        if ($stream) { $stream.Dispose() }
        if ($icon) { $icon.Dispose() }
        $plane.Dispose()
        $white.Dispose()
        $blue.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

New-TelegramIcon $iconFile
if (!(Test-Path $iconFile)) { throw "Telegram application icon was not generated." }
Write-Host "Original Telegram paper-plane mark generated for the app, window and installer." -ForegroundColor Green

dotnet --info
dotnet restore $project
if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed." }

dotnet build $project -c $Configuration --no-restore -p:Version=$AppVersion -p:ApplicationIcon=$iconFile
if ($LASTEXITCODE -ne 0) { throw "dotnet build failed." }

if (Test-Path $publish) { Remove-Item $publish -Recurse -Force }
New-Item -ItemType Directory -Path $publish -Force | Out-Null

dotnet publish $project -c $Configuration -r $Runtime --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -p:Version=$AppVersion -p:ApplicationIcon=$iconFile -o $publish
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed." }

$exe = Join-Path $publish "Telegram.exe"
if (!(Test-Path $exe)) { throw "Published executable was not found." }
if ((Get-Item $exe).Length -lt 1MB) { throw "Published executable is unexpectedly small." }
Copy-Item -Path $iconFile -Destination (Join-Path $publish "Telegram.ico") -Force
Write-Host "Portable publish checks passed: $exe" -ForegroundColor Green

$compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if (!$compiler) {
    $candidate = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
    if (Test-Path $candidate) { $compiler = @{ Source = $candidate } }
}
if (!$compiler) { throw "Inno Setup 6 compiler not found. Install Inno Setup 6 before building the installer." }

New-Item -ItemType Directory -Path $installerOut -Force | Out-Null
& $compiler.Source "/DAppVersion=$AppVersion" "/DPublishDir=$publish" "/DOutputDir=$installerOut" "/DIconDir=$iconDirectory" (Join-Path $root "installer\Telegram.iss")
if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed." }
if (!(Test-Path (Join-Path $installerOut "Telegram-Setup.exe"))) { throw "Installer output missing." }
Write-Host "Installer created successfully." -ForegroundColor Green
