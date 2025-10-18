# Bitpoints.me - Quick Deploy to Android Device
# Run this in PowerShell

Write-Host "Deploying Bitpoints.me to Android Device..." -ForegroundColor Cyan

# Find Android Studio's Java
$possibleJavaPaths = @(
    "C:\Program Files\Android\Android Studio\jbr",
    "C:\Program Files\Android\Android Studio\jre",
    "$env:LOCALAPPDATA\Android\Android Studio\jbr",
    "$env:LOCALAPPDATA\Android\Android Studio\jre"
)

$javaHome = $null
foreach ($path in $possibleJavaPaths) {
    if (Test-Path "$path\bin\java.exe") {
        $javaHome = $path
        break
    }
}

if ($javaHome) {
    Write-Host "Found Java at: $javaHome" -ForegroundColor Green
    $env:JAVA_HOME = $javaHome
    $env:PATH = "$javaHome\bin;$env:PATH"
} else {
    Write-Host "Could not find Android Studio's Java. Please use Android Studio GUI instead." -ForegroundColor Red
    Write-Host "   Or set JAVA_HOME manually to your JDK installation." -ForegroundColor Yellow
    exit 1
}

# Build and install
Write-Host "Building APK..." -ForegroundColor Cyan
Set-Location "$PSScriptRoot\android"

.\gradlew installDebug

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "SUCCESS! Deployed to your device!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Look at your device - Bitpoints.me should be launching"
    Write-Host "  2. Grant permissions (Camera, Bluetooth, Location)"
    Write-Host "  3. Start using your Bitcoin-backed rewards wallet!"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Build failed. Please use Android Studio instead:" -ForegroundColor Red
    Write-Host "   1. Open Android Studio"
    Write-Host "   2. Open project: $PSScriptRoot\android"
    Write-Host "   3. Click Run button"
    Write-Host ""
}
