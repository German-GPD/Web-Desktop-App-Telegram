param([string]$Configuration = "Release", [string]$Runtime = "win-x64", [string]$AppVersion = "1.0.0")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "src\Telegram.Desktop\Telegram.Desktop.csproj"
$publish = Join-Path $root "artifacts\publish"
$installerOut = Join-Path $root "artifacts\installer"
Write-Host "== Telegram Desktop: validate, restore and build ==" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "validate.ps1")
# Generate the Telegram-orange application icon before compilation so it is embedded in Telegram.exe.
Add-Type -AssemblyName System.Drawing
$iconDirectory = Join-Path $root "artifacts\icons"
New-Item -ItemType Directory -Path $iconDirectory -Force | Out-Null

function New-AppIcon([string]$Name, [string]$Style) {
    $bitmap = [System.Drawing.Bitmap]::new(256, 256)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $accent = [System.Drawing.Color]::FromArgb(255, 34, 158, 217)
    $white = [System.Drawing.Color]::White
    $background = $null

    if ($Style -eq "Accent") {
        $background = [System.Drawing.SolidBrush]::new($accent)
        $graphics.FillEllipse($background, 8, 8, 240, 240)
        $foreground = [System.Drawing.SolidBrush]::new($white)
    } elseif ($Style -eq "Monochrome") {
        $background = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 38, 42, 39))
        $graphics.FillEllipse($background, 8, 8, 240, 240)
        $foreground = [System.Drawing.SolidBrush]::new($white)
    } else {
        $foreground = [System.Drawing.SolidBrush]::new($accent)
        $pen = [System.Drawing.Pen]::new($accent, 12)
        $graphics.DrawEllipse($pen, 18, 18, 220, 220)
        $pen.Dispose()
    }

    $font = [System.Drawing.Font]::new("Segoe UI", 132, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $rect = [System.Drawing.RectangleF]::new(0, 10, 256, 236)
    $graphics.DrawString("G", $font, $foreground, $rect, $format)

    $handle = $bitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($handle)
    $stream = [System.IO.File]::Create((Join-Path $iconDirectory "$Name.ico"))
    try { $icon.Save($stream) } finally {
        $stream.Dispose()
        $icon.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
        $font.Dispose()
        $format.Dispose()
        $foreground.Dispose()
        if ($background) { $background.Dispose() }
    }
}

New-AppIcon "Telegram-Accent" "Accent"
Write-Host "Built-in icon variants generated." -ForegroundColor Green
$iconFile = Join-Path $iconDirectory "Telegram-Accent.ico"
if (!(Test-Path $iconFile)) { throw "Telegram application icon was not generated." }


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
Write-Host "Publish checks passed: $exe" -ForegroundColor Green


$compiler = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if (!$compiler) {
    $candidate = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
    if (Test-Path $candidate) { $compiler = @{ Source = $candidate } }
}
if ($compiler) {
    New-Item -ItemType Directory -Path $installerOut -Force | Out-Null
    & $compiler.Source "/DAppVersion=$AppVersion" "/DPublishDir=$publish" "/DOutputDir=$installerOut" "/DIconDir=$iconDirectory" (Join-Path $root "installer\Telegram.iss")
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed." }
    if (!(Test-Path (Join-Path $installerOut "Telegram-Setup.exe"))) { throw "Installer output missing." }
    Write-Host "Installer created successfully." -ForegroundColor Green
} else {
    throw "Inno Setup 6 compiler not found. Install Inno Setup 6 before building the installer."
}
