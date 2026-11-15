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

# One official-style Telegram mark is shared by the executable, window, installer and shortcuts.
$bitmap = [System.Drawing.Bitmap]::new(256, 256)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)
$blue = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 34, 158, 217))
$white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
$graphics.FillEllipse($blue, 5, 5, 246, 246)
$plane = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(48, 124),
    [System.Drawing.Point]::new(211, 61),
    [System.Drawing.Point]::new(169, 204),
    [System.Drawing.Point]::new(128, 157),
    [System.Drawing.Point]::new(103, 181),
    [System.Drawing.Point]::new(109, 139)
)
$graphics.FillPolygon($white, $plane)
$foldPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 34, 158, 217), 5)
$foldPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$foldPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawLine($foldPen, 109, 139, 169, 204)
$handle = $bitmap.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($handle)
$iconStream = [System.IO.File]::Create($iconFile)
try {
    $icon.Save($iconStream)
}
finally {
    $iconStream.Dispose()
    $icon.Dispose()
    $foldPen.Dispose()
    $white.Dispose()
    $blue.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}
if (!(Test-Path $iconFile)) { throw "Telegram icon generation failed." }

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
