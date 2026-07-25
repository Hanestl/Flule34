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
$aapt = Join-Path $buildTools.FullName 'aapt.exe'
$readelf = Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'ndk') -Recurse -Filter 'llvm-readelf.exe' |
    Sort-Object FullName -Descending |
    Select-Object -First 1
$apks = Get-ChildItem -LiteralPath $resolvedDirectory -Filter '*-release.apk'
if (-not $apks) {
    throw "未找到 Release APK：$resolvedDirectory"
}

foreach ($apk in $apks) {
    Write-Host "正在验证 $($apk.Name)"
    & $apksigner verify --verbose --print-certs $apk.FullName
    if ($LASTEXITCODE -ne 0) {
        throw "APK 签名校验失败：$($apk.Name)"
    }

    $badging = & $aapt dump badging $apk.FullName
    if (-not $badging -or -not ($badging -match "package: name='com\.hanestl\.flule34'")) {
        throw "APK 包名或 manifest 无法验证：$($apk.Name)"
    }
    $badging | Select-Object -First 1

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($apk.FullName)
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('flule34-release-verify-' + [Guid]::NewGuid().ToString('N'))
    try {
        $nativeEntries = @($zip.Entries | Where-Object { $_.FullName -match '^lib/([^/]+)/[^/]+\.so$' })
        if (-not $nativeEntries) {
            throw "APK 中未找到原生库：$($apk.Name)"
        }
        $abis = @($nativeEntries | ForEach-Object {
            [regex]::Match($_.FullName, '^lib/([^/]+)/').Groups[1].Value
        } | Sort-Object -Unique)
        $expectedAbi = if ($apk.Name -match '(arm64-v8a|armeabi-v7a|x86_64)') { $Matches[1] } else { $null }
        if ($expectedAbi -and ($abis.Count -ne 1 -or $abis[0] -ne $expectedAbi)) {
            throw "APK ABI 与文件名不一致：$($apk.Name) 包含 $($abis -join ', ')"
        }
        Write-Host "ABI：$($abis -join ', ')"

        if ($readelf) {
            New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
            $index = 0
            foreach ($entry in $nativeEntries) {
                $index += 1
                $tempFile = Join-Path $tempRoot ("$index-" + [IO.Path]::GetFileName($entry.FullName))
                $input = $entry.Open()
                $output = [IO.File]::Create($tempFile)
                try {
                    $input.CopyTo($output)
                }
                finally {
                    $output.Dispose()
                    $input.Dispose()
                }
                $sections = & $readelf.FullName -SW $tempFile 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "无法检查 ELF：$($entry.FullName)"
                }
                if ($sections -match '\.(?:debug_|zdebug_)|\.symtab\b|\.strtab\b') {
                    throw "APK 包含调试符号 section：$($entry.FullName)"
                }
            }
            Write-Host 'ELF 调试 section：未发现'
        }
    }
    finally {
        $zip.Dispose()
        if (Test-Path -LiteralPath $tempRoot) {
            $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
            $systemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
            if (-not $resolvedTemp.StartsWith($systemTemp, [StringComparison]::OrdinalIgnoreCase)) {
                throw "拒绝清理系统临时目录之外的路径：$resolvedTemp"
            }
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}

$apks | Get-FileHash -Algorithm SHA256 |
    Sort-Object Path |
    Format-Table Algorithm, Hash, Path -AutoSize
