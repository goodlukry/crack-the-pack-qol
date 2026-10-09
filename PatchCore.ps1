$ErrorActionPreference = 'Stop'
function Get-PatchHash([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $algorithm.Dispose() }
}
function Resolve-GameFolder([string]$Folder) {
    if ([string]::IsNullOrWhiteSpace($Folder)) {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = '选择包含 CrackThePack.exe 和 data.win 的 game 文件夹'
        try {
            if ($dialog.ShowDialog() -ne 'OK') { throw '已取消。' }
            $Folder = $dialog.SelectedPath
        } finally { $dialog.Dispose() }
    }
    $Folder = (Resolve-Path -LiteralPath $Folder).Path
    if (-not (Test-Path -LiteralPath (Join-Path $Folder 'CrackThePack.exe')) -or
        -not (Test-Path -LiteralPath (Join-Path $Folder 'data.win'))) { throw '所选文件夹不是游戏目录。' }
    return $Folder
}
function Assert-GameClosed([string]$Folder) {
    foreach ($process in @(Get-Process -Name CrackThePack -ErrorAction SilentlyContinue)) {
        if (-not $process.Path -or [string]::Equals([IO.Path]::GetDirectoryName($process.Path), $Folder, [StringComparison]::OrdinalIgnoreCase)) {
            throw '请正常退出这个目录中的游戏，保存进度后再操作。'
        }
    }
}
function Expand-DataPatch([string]$SourcePath, [string]$PatchPath, [string]$OutputPath) {
    $sourceBytes = [IO.File]::ReadAllBytes($SourcePath)
    $file = [IO.File]::OpenRead($PatchPath)
    $deflate = $null; $reader = $null; $output = $null
    try {
        $magic = New-Object byte[] 8
        if ($file.Read($magic, 0, 8) -ne 8 -or [Text.Encoding]::ASCII.GetString($magic) -ne 'CTPDIFF1') { throw '差分补丁格式错误。' }
        $deflate = New-Object IO.Compression.DeflateStream($file, [IO.Compression.CompressionMode]::Decompress)
        $reader = New-Object IO.BinaryReader($deflate)
        $expected = $reader.ReadUInt64()
        if ($expected -gt 1073741824) { throw '补丁输出大小异常。' }
        $output = New-Object IO.MemoryStream
        while ($true) {
            $opcode = $reader.ReadByte()
            if ($opcode -eq 2) { break }
            if ($opcode -eq 0) {
                $offset = $reader.ReadUInt64(); $length = $reader.ReadUInt32()
                if ($offset -gt $sourceBytes.LongLength -or $length -gt ($sourceBytes.LongLength - $offset)) { throw '补丁引用越界。' }
                $output.Write($sourceBytes, [int]$offset, [int]$length)
            } elseif ($opcode -eq 1) {
                $length = $reader.ReadUInt32()
                if ($length -gt $expected -or $output.Length + $length -gt $expected) { throw '补丁字面数据过长。' }
                $literal = $reader.ReadBytes([int]$length)
                if ($literal.Length -ne $length) { throw '补丁文件截断。' }
                $output.Write($literal, 0, $literal.Length)
            } else { throw '补丁指令错误。' }
            if ($output.Length -gt $expected) { throw '补丁输出越界。' }
        }
        if ($output.Length -ne $expected -or $reader.BaseStream.ReadByte() -ne -1) { throw '补丁输出大小或末尾错误。' }
        [IO.File]::WriteAllBytes($OutputPath, $output.ToArray())
    } finally {
        if ($output) { $output.Dispose() }
        if ($reader) { $reader.Dispose() } elseif ($deflate) { $deflate.Dispose() }
        $file.Dispose()
    }
}
function Write-Utf8Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding($false)))
}
