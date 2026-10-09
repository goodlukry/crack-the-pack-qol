param([string]$GameDir)
. (Join-Path $PSScriptRoot 'PatchCore.ps1')
$GameDir = Resolve-GameFolder $GameDir
Assert-GameClosed $GameDir
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$dataPath = Join-Path $GameDir 'data.win'
$current = Get-PatchHash $dataPath
$backupDir = Join-Path $GameDir $manifest.backup_directory
$metadataPath = Join-Path $backupDir 'backup.json'
$target = @($manifest.targets | Where-Object { $_.base_sha256 -eq $current })
if ($target.Count -ne 1) {
    if (@($manifest.targets | Where-Object { $_.target_sha256 -eq $current }).Count -gt 0 -and (Test-Path -LiteralPath $metadataPath)) {
        Write-Host '本补丁已经安装，无需重复安装。'; exit 0
    }
    throw '当前 data.win 版本不支持。请查看 README 的版本与安装顺序。'
}
$target = $target[0]
$patchPath = Join-Path $PSScriptRoot $target.patch_file
if ((Get-PatchHash $patchPath) -ne $target.patch_sha256) { throw '差分补丁校验失败。' }
foreach ($asset in $manifest.assets) {
    if ($asset.name -notmatch '^[A-Za-z0-9_.-]+$' -or (Get-PatchHash (Join-Path $PSScriptRoot $asset.name)) -ne $asset.sha256) { throw '配套文件名或校验失败。' }
}
$tempPath = Join-Path $GameDir 'data.win.patch.tmp'
try {
    Expand-DataPatch $dataPath $patchPath $tempPath
    if ((Get-PatchHash $tempPath) -ne $target.target_sha256) { throw '生成文件校验失败，未替换游戏数据。' }
    if (Test-Path -LiteralPath $metadataPath) {
        $meta = Get-Content -LiteralPath $metadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($meta.base_sha256 -ne $current -or (Get-PatchHash (Join-Path $backupDir 'data.win')) -ne $current) { throw '已有备份与当前数据不一致。' }
    } else {
        if (Test-Path -LiteralPath $backupDir) { throw '备份目录已存在但记录缺失，请保留备份并检查。' }
        New-Item -ItemType Directory -Path $backupDir | Out-Null
        Copy-Item -LiteralPath $dataPath -Destination (Join-Path $backupDir 'data.win')
        $saved = @()
        foreach ($asset in $manifest.assets) {
            $exists = Test-Path -LiteralPath (Join-Path $GameDir $asset.name)
            if ($exists) { Copy-Item -LiteralPath (Join-Path $GameDir $asset.name) -Destination (Join-Path $backupDir $asset.name) }
            $saved += @{name = $asset.name; existed = $exists}
        }
        $previousLang = $null
        if ($manifest.set_language) {
            $options = Get-Content -LiteralPath (Join-Path $GameDir 'options.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            $previousLang = $options.lang
        }
        $meta = @{base_sha256=$current; target_sha256=$target.target_sha256; assets=$saved; previous_language=$previousLang}
        Write-Utf8Json $metadataPath $meta
    }
    Assert-GameClosed $GameDir
    foreach ($asset in $manifest.assets) {
        $destination = Join-Path $GameDir $asset.name
        if ($asset.overwrite -or -not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $asset.name) -Destination $destination -Force }
    }
    if ($manifest.set_language) {
        $options = Get-Content -LiteralPath (Join-Path $GameDir 'options.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $options.lang = $manifest.set_language
        Write-Utf8Json (Join-Path $GameDir 'options.json') $options
    }
    [IO.File]::Replace($tempPath, $dataPath, [System.Management.Automation.Language.NullString]::Value)
    Write-Host "安装完成：$($manifest.title)"
    Write-Host "备份目录：$backupDir"
} finally {
    if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath }
}
