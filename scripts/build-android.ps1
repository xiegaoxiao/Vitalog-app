$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskJavaRoot = Join-Path $taskRoot '.tooling\java'
$taskJavaDirectory = if (Test-Path -LiteralPath $taskJavaRoot) { Get-ChildItem -LiteralPath $taskJavaRoot -Directory | Select-Object -First 1 }
if ($taskJavaDirectory) { $env:JAVA_HOME = $taskJavaDirectory.FullName }
$taskSdkDirectory = Join-Path $taskRoot '.tooling\android-sdk'
if (Test-Path -LiteralPath $taskSdkDirectory) { $env:ANDROID_HOME = $taskSdkDirectory; $env:ANDROID_SDK_ROOT = $taskSdkDirectory }
Push-Location -LiteralPath $taskRoot
try {
    flutter build apk --release --target-platform android-arm64
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed' }
    $taskOutputDirectory = Join-Path $taskRoot 'output'
    New-Item -ItemType Directory -Force -Path $taskOutputDirectory | Out-Null
    Copy-Item -LiteralPath (Join-Path $taskRoot 'build\app\outputs\flutter-apk\app-release.apk') -Destination (Join-Path $taskOutputDirectory 'Vitalog-0.1.0-arm64.apk')
} finally { Pop-Location }
