$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$secretPattern = '(_authToken\s*=|_auth\s*=|"gh_token"\s*:|<password>[^<]+</password>|npm_[A-Za-z0-9]{10,}|gh[pousr]_[A-Za-z0-9]{10,}|github_pat_[A-Za-z0-9_]{10,})'

# 1. 自动挂载 Git pre-commit 敏感信息拦截钩子（防止新设备克隆后丢失）
$preCommitPath = Join-Path $repoRoot '.git\hooks\pre-commit'
$preCommitScript = @"
#!/bin/sh
if git diff --cached -U0 -- . ':(exclude).vscode/sync-watch.ps1' | grep -E -i '$secretPattern' >/dev/null 2>&1; then
    echo "❌ [Security] 检测到暂存区包含疑似 Token 或密码，已拦截提交！请执行 git diff --cached 检查。"
    exit 1
fi
"@
if (-not (Test-Path $preCommitPath) -or (Get-Content $preCommitPath -Raw) -ne $preCommitScript) {
    Set-Content -Path $preCommitPath -Value $preCommitScript -Encoding utf8 -NoNewline
}

# 2. 打开 VS Code 时，自动导出最新 Scoop 软件清单（剥离 Updated 时间戳以消除 Git 噪音）并拉回外部改动
if (Get-Command jq -ErrorAction SilentlyContinue) {
    scoop export | jq 'walk(if type == "object" then del(.Updated) else . end)' | Out-File -FilePath "$HOME\.config\scoop\scoopfile.json" -Encoding utf8
} else {
    $export = scoop export | ConvertFrom-Json
    $export.buckets.ForEach({ $_.PSObject.Properties.Remove('Updated') })
    $export.apps.ForEach({ $_.PSObject.Properties.Remove('Updated') })
    $export | ConvertTo-Json -Depth 5 | Out-File -FilePath "$HOME\.config\scoop\scoopfile.json" -Encoding utf8
}
chezmoi re-add

# 检查拉回的改动中是否包含敏感凭证（如 npm login / scoop gh_token）
$diffOutput = git -C $repoRoot diff -U0 -- . ':(exclude).vscode/sync-watch.ps1'
if ($diffOutput -match $secretPattern) {
    Write-Host "[警告] 检测到外部配置拉回了疑似 Token/密码 ($($Matches[0]))，提交前请务必检查 git diff！" -ForegroundColor Red
}

# 3. 监听仓库内文件保存（Ctrl+S），防抖合并事件后实时同步回系统原文件
$watcher = [System.IO.FileSystemWatcher]::new($repoRoot)
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$changeTypes = [System.IO.WatcherChangeTypes]::Changed -bor [System.IO.WatcherChangeTypes]::Created -bor [System.IO.WatcherChangeTypes]::Renamed

Write-Host "[chezmoi] 已拉取外部最新配置，正在监听 Ctrl+S 保存实时同步..." -ForegroundColor Green

try {
    while ($true) {
        $result = $watcher.WaitForChanged($changeTypes)
        if ($result.Name -and $result.Name -notmatch '^(\.git|\.vscode)(\\|$)') {
            # 清空 200ms 内的连续文件写入事件，避免单次保存重复触发 apply
            while (-not $watcher.WaitForChanged($changeTypes, 200).TimedOut) {}
            chezmoi apply --force
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 已实时同步至系统: $($result.Name)" -ForegroundColor Cyan
        }
    }
} finally {
    $watcher.Dispose()
}
