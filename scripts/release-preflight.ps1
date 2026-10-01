param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,
    [switch]$BuildAndroidRelease
)

$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Install Flutter and add its bin directory to PATH before running this script.'
}
if ($ApiBaseUrl -notmatch '^https://') {
    throw 'Release candidates require an HTTPS API_BASE_URL.'
}

$requiredFiles = @(
    (Join-Path $mobileRoot 'android\app\google-services.json'),
    (Join-Path $mobileRoot 'ios\Runner\GoogleService-Info.plist')
)
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile)) {
        throw "Missing Firebase configuration file: $requiredFile"
    }
}
if ($BuildAndroidRelease -and -not (Test-Path -LiteralPath (Join-Path $mobileRoot 'android\key.properties'))) {
    throw 'Missing android\key.properties required to sign an Android release.'
}
if ($BuildAndroidRelease) {
    $keyProperties = Get-Content -LiteralPath (Join-Path $mobileRoot 'android\key.properties') -Raw
    foreach ($key in @('storeFile', 'storePassword', 'keyAlias', 'keyPassword')) {
        if ($keyProperties -notmatch "(?m)^\s*$key\s*=\s*.+$") {
            throw "android\key.properties is missing a value for $key."
        }
    }
}

Push-Location $mobileRoot
try {
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
    if ($BuildAndroidRelease) {
        flutter build appbundle --release "--dart-define=API_BASE_URL=$ApiBaseUrl"
        if ($LASTEXITCODE -ne 0) { throw 'Android release bundle build failed.' }
    }
} finally {
    Pop-Location
}
