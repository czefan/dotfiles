# 开发环境同步 (依赖缓存路径 & CLI 初始化缓存；PowerShell 7)
$ErrorActionPreference = 'Stop'

$starshipExe = Join-Path (Get-Item 'D:\Scoop\apps\starship\current').Target 'starship.exe'
$zoxideExe = Join-Path (Get-Item 'D:\Scoop\apps\zoxide\current').Target 'zoxide.exe'
$pnpmExe = Join-Path (Get-Item 'D:\Scoop\apps\pnpm\current').Target 'pnpm.exe'

# 1. 生成初始化脚本并校验内容
$starshipInit = & $starshipExe init powershell --print-full-init
if ($LASTEXITCODE -ne 0 -or -not $starshipInit) { throw 'Starship 初始化失败，保留原缓存。' }
$starshipInit = $starshipInit -join "`n"
$shimPath = "'D:\Scoop\shims\starship.exe'"
$currentPath = "'D:\Scoop\apps\starship\current\starship.exe'"
if (-not ($starshipInit.Contains($shimPath) -or $starshipInit.Contains($currentPath) -or $starshipInit.Contains("'$starshipExe'"))) {
    throw 'Starship 初始化脚本路径格式已改变，请检查后再清理旧版本。'
}
$starshipInit = $starshipInit.Replace($shimPath, "'$starshipExe'").Replace($currentPath, "'$starshipExe'")

$zoxideInit = & $zoxideExe init powershell
if ($LASTEXITCODE -ne 0 -or -not $zoxideInit) { throw 'zoxide 初始化失败，保留原缓存。' }
$cacheScripts = [ordered]@{
    'starship_init.ps1' = $starshipInit
    'zoxide_init.ps1' = $zoxideInit -join "`n"
}
foreach ($source in $cacheScripts.Values) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
}

# 2. 恢复依赖缓存路径 (Scoop 更新可能重置)
$env:PNPM_HOME = 'D:\Scoop\persist\pnpm'
[Environment]::SetEnvironmentVariable('PNPM_HOME', $env:PNPM_HOME, 'User')
$pnpmBin = "$env:PNPM_HOME\bin"
$commandPaths = @($pnpmBin, 'D:\Cache\Dev\go\bin')
$legacyBin = 'D:\Scoop\apps\pnpm\current\bin'
$userPaths = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
$userPath = ($commandPaths + @($userPaths | Where-Object { $_ -and $_.TrimEnd('\') -notin ($commandPaths + $legacyBin) })) -join ';'
[Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
$env:PATH = ($commandPaths + @($env:PATH -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -notin ($commandPaths + $legacyBin) })) -join ';'
& $pnpmExe config set storeDir 'D:\Cache\Dev\pnpm-store' --global
if ($LASTEXITCODE -ne 0) { throw 'pnpm 缓存路径设置失败。' }
$dataPaths = @{
    UV_CACHE_DIR = 'D:\Cache\Dev\uv'
    DENO_DIR = 'D:\Cache\Dev\deno'
    GRADLE_USER_HOME = 'D:\Cache\Dev\gradle'
}
foreach ($entry in $dataPaths.GetEnumerator()) {
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'User')
    [Environment]::SetEnvironmentVariable($entry.Key, $entry.Value, 'Process')
}

# 3. 使用独立临时文件替换缓存
$pending = [ordered]@{}
try {
    foreach ($name in $cacheScripts.Keys) {
        $pending[$name] = Join-Path $PSScriptRoot "$name.$([Guid]::NewGuid().ToString('N')).tmp"
        Set-Content -LiteralPath $pending[$name] -Value $cacheScripts[$name] -Encoding utf8
    }
    foreach ($name in $cacheScripts.Keys) {
        [System.IO.File]::Move($pending[$name], (Join-Path $PSScriptRoot $name), $true)
    }
} finally {
    foreach ($path in $pending.Values) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue }
    }
}
Write-Host '开发环境配置与 CLI 初始化缓存已同步。'
