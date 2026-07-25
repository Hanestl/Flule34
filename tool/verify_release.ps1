param(
    [string]$ApkDirectory = 'build\app\outputs\flutter-apk',
    [string]$AndroidSdk = 'D:\tools\android-sdk'
)

$ErrorActionPreference = 'Stop'
$resolvedDirectory = (Resolve-Path -LiteralPath $ApkDirectory).Path
$buildTools = Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'build-tools') -Directory |
    Sort-Object { [version]$_.Name } -Descending |
    Select-Object -First 1

if (-not $buildTools) {
    throw "未找到 Android build-tools：$AndroidSdk"
}

$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$apks = Get-ChildItem -LiteralPath $resolvedDirectory -Filter '*-release.apk'
if (-not $apks) {
    throw "未找到 Release APK：$resolvedDirectory"
}

foreach ($apk in $apks) {
    & $apksigner verify --verbose --print-certs $apk.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "APK 签名校验失败：$($apk.Name)"
    }
}

$apks | Get-FileHash -Algorithm SHA256 |
    Sort-Object Path |
    Format-Table Algorithm, Hash, Path -AutoSize
