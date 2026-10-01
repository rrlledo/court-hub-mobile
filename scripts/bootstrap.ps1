$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Install Flutter and add its bin directory to PATH before running this script.'
}
Push-Location $mobileRoot
try {
    # Generate native runners in a temporary project; preserve application source and tests.
    $runnerRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('court-hub-runners-' + [guid]::NewGuid())
    flutter create --platforms=android,ios --org com.courthub --project-name court_hub_mobile --no-pub $runnerRoot
    if ($LASTEXITCODE -ne 0) { throw 'Flutter runner generation failed.' }
    foreach ($platform in @('android', 'ios')) {
        $destination = Join-Path $mobileRoot $platform
        if (-not (Test-Path -LiteralPath $destination)) {
            Copy-Item -LiteralPath (Join-Path $runnerRoot $platform) -Destination $destination -Recurse
        }
    }
    $androidManifest = Join-Path $mobileRoot 'android\app\src\main\AndroidManifest.xml'
    if (Test-Path -LiteralPath $androidManifest) {
        $manifest = Get-Content -LiteralPath $androidManifest -Raw
        if ($manifest -notmatch 'android.permission.POST_NOTIFICATIONS') {
            $manifest = $manifest -replace '(<application)', "    <uses-permission android:name=`"android.permission.POST_NOTIFICATIONS`" />`r`n    `$1"
            [System.IO.File]::WriteAllText($androidManifest, $manifest)
        }
    }
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Analysis failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
} finally {
    Pop-Location
}
