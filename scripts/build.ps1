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

$iconSource = Join-Path $root "assets\telegram.ico"
New-Item -ItemType Directory -Path $iconDirectory -Force | Out-Null
if (!(Test-Path $iconSource)) { throw "The original Telegram ICO asset is missing: $iconSource" }
Copy-Item -Path $iconSource -Destination $iconFile -Force
Write-Host "Original Telegram icon copied for the executable, window and installer." -ForegroundColor Green

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
