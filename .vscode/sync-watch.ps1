$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path

# 启动前检查差异，避免覆盖仓库或系统中尚未合并的修改。
$status = @(chezmoi --source $repoRoot status)
if ($LASTEXITCODE -ne 0) { throw 'chezmoi 状态检查失败。' }
if ($status.Count) {
    $status | Write-Host
    throw '存在未合并差异。请先运行 chezmoi diff，再用 apply、re-add 或 merge 确认后重启同步任务。'
}

# 仅更新 Scoop 清单，不导出本机凭证与动态配置。
$rawExport = @(scoop export)
if ($LASTEXITCODE -ne 0) { throw 'Scoop 清单导出失败。' }
$export = ($rawExport -join "`n") | ConvertFrom-Json
$inventory = [ordered]@{
    buckets = @($export.buckets | Select-Object Name, Source)
    apps = @($export.apps | Select-Object Name, Version, Source, Info)
} | ConvertTo-Json -Depth 5
$inventoryPath = chezmoi --source $repoRoot target-path "$repoRoot\dot_config\scoop\scoopfile.json"
if ($LASTEXITCODE -ne 0) { throw '无法确定 Scoop 清单路径。' }
if ($inventory.Trim() -ne (Get-Content -LiteralPath $inventoryPath -Raw).Trim()) {
    Set-Content -LiteralPath $inventoryPath -Value $inventory -Encoding utf8
    chezmoi --source $repoRoot re-add $inventoryPath
    if ($LASTEXITCODE -ne 0) { throw 'Scoop 清单回写失败。' }
}

# 安装仓库自带的凭证检查钩子；保留其他自定义钩子。
$secretPattern = '(_authToken\s*=|_auth\s*=|"gh_token"\s*:|<password>[^<]+</password>|npm_[A-Za-z0-9]{10,}|gh[pousr]_[A-Za-z0-9]{10,}|github_pat_[A-Za-z0-9_]{10,})'
$preCommitPath = Join-Path $repoRoot '.git\hooks\pre-commit'
$preCommitScript = @"
#!/bin/sh
# chezmoi credential check
added=`$(git diff --cached --no-ext-diff --no-textconv -U0 -- . ':(exclude).vscode/sync-watch.ps1') || exit 1
if printf '%s\n' "`$added" | grep '^+' | grep -v '^+++' | grep -E -i '$secretPattern' >/dev/null 2>&1; then
    echo '[Security] 暂存区新增内容含疑似凭证，请检查后提交。'
    exit 1
fi
"@
if (-not (Test-Path -LiteralPath $preCommitPath) -or (Get-Content -LiteralPath $preCommitPath -Raw).Contains('# chezmoi credential check')) {
    Set-Content -LiteralPath $preCommitPath -Value ($preCommitScript.Replace("`r`n", "`n") + "`n") -Encoding utf8 -NoNewline
}

# 事件队列保留 apply 期间发生的保存；短暂等待以合并连续写入。
$knownSources = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$sourcePaths = @(chezmoi --source $repoRoot managed --include files --path-style source-absolute)
if ($LASTEXITCODE -ne 0) { throw '无法读取配置文件清单。' }
foreach ($path in $sourcePaths) { $null = $knownSources.Add([IO.Path]::GetFullPath($path)) }
$watcher = [IO.FileSystemWatcher]::new($repoRoot)
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::LastWrite
$eventPrefix = 'chezmoi.' + [Guid]::NewGuid().ToString('N')
$eventNames = 'Changed', 'Created', 'Deleted', 'Renamed', 'Error'
try {
    foreach ($name in $eventNames) {
        $null = Register-ObjectEvent $watcher $name -SourceIdentifier "$eventPrefix.$name"
    }
    $watcher.EnableRaisingEvents = $true
    Write-Host '[chezmoi] 保存后同步已启用；目标文件发生冲突时停止。' -ForegroundColor Green
    while ($true) {
        $null = Wait-Event -Timeout 1
        Start-Sleep -Milliseconds 200
        $events = @(Get-Event | Where-Object { $_.SourceIdentifier.StartsWith($eventPrefix + '.') })
        $paths = @()
        foreach ($event in $events) {
            Remove-Event -EventIdentifier $event.EventIdentifier
            if ($event.SourceIdentifier -eq "$eventPrefix.Error") { throw '文件监听发生错误，请检查差异后重启任务。' }
            $relative = [IO.Path]::GetRelativePath($repoRoot, $event.SourceEventArgs.FullPath)
            if ($relative -match '^(\.git|\.vscode)([\\/]|$)' -or $relative -in @('README.md', 'LICENSE')) { continue }
            if ($relative -match '(~|\.tmp|\.swp)$') { continue }
            $renamedSource = $event.SourceEventArgs -is [IO.RenamedEventArgs] -and $knownSources.Contains($event.SourceEventArgs.OldFullPath)
            $deletedSource = $knownSources.Contains($event.SourceEventArgs.FullPath) -and -not (Test-Path -LiteralPath $event.SourceEventArgs.FullPath)
            if ($relative -like '.chezmoi*' -or $renamedSource -or $deletedSource) {
                throw '源文件已删除、改名或同步规则已改变，请检查 chezmoi diff 后重启任务。'
            }
            if (Test-Path -LiteralPath $event.SourceEventArgs.FullPath -PathType Leaf) { $paths += $event.SourceEventArgs.FullPath }
        }
        foreach ($path in ($paths | Select-Object -Unique)) {
            chezmoi --source $repoRoot --source-path --error-on-conflict --no-tty apply $path
            if ($LASTEXITCODE -ne 0) { throw '同步失败或目标文件已被外部修改；已停止，请检查 chezmoi diff。' }
            $null = $knownSources.Add($path)
            Write-Host "[chezmoi] 已同步 $([IO.Path]::GetRelativePath($repoRoot, $path))"
        }
    }
} finally {
    $watcher.Dispose()
    foreach ($name in $eventNames) {
        Unregister-Event -SourceIdentifier "$eventPrefix.$name" -ErrorAction SilentlyContinue
        Remove-Event -SourceIdentifier "$eventPrefix.$name" -ErrorAction SilentlyContinue
    }
}
