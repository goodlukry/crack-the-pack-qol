param([string]$GameDir)
. (Join-Path $PSScriptRoot 'PatchCore.ps1')
$GameDir = Resolve-GameFolder $GameDir
Assert-GameClosed $GameDir
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$backupDir = Join-Path $GameDir $manifest.backup_directory
$meta = Get-Content -LiteralPath (Join-Path $backupDir 'backup.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$dataPath = Join-Path $GameDir 'data.win'
$backupPath = Join-Path $backupDir 'data.win'
$current = Get-PatchHash $dataPath
if ($current -ne $meta.target_sha256 -and $current -ne $meta.base_sha256) { throw '游戏数据随后又被其他补丁修改，请按安装顺序逆序恢复。' }
if ((Get-PatchHash $backupPath) -ne $meta.base_sha256) { throw '备份校验失败。' }
foreach ($asset in $meta.assets) {
    if ($asset.name -notmatch '^[A-Za-z0-9_.-]+$') { throw '备份记录文件名异常。' }
    if ($asset.existed -and -not (Test-Path -LiteralPath (Join-Path $backupDir $asset.name))) { throw '配套文件备份缺失。' }
}
$tempPath = Join-Path $GameDir 'data.win.patch.tmp'
Copy-Item -LiteralPath $backupPath -Destination $tempPath -Force
Assert-GameClosed $GameDir
[IO.File]::Replace($tempPath, $dataPath, [System.Management.Automation.Language.NullString]::Value)
foreach ($asset in $meta.assets) {
    $destination = Join-Path $GameDir $asset.name
    if ($asset.existed) { Copy-Item -LiteralPath (Join-Path $backupDir $asset.name) -Destination $destination -Force }
    elseif (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination }
}
if ($manifest.set_language) {
    $optionsPath = Join-Path $GameDir 'options.json'
    $options = Get-Content -LiteralPath $optionsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $options.lang = $meta.previous_language
    Write-Utf8Json $optionsPath $options
}
Write-Host '已恢复为安装此补丁前的版本。备份仍保留。'
