# 基础环境与包管理入口 (Scoop & pnpm)
$env:PNPM_HOME = 'D:\Scoop\persist\pnpm'
$commandPaths = @("$env:PNPM_HOME\bin", 'D:\Scoop\shims')
$env:PATH = ($commandPaths + @($env:PATH -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -notin $commandPaths })) -join ';'
# JAVA_HOME 由 Scoop 管理。

# 终端代理 (Clash 混合端口)
$env:http_proxy  = 'http://127.0.0.1:7897'
$env:https_proxy = 'http://127.0.0.1:7897'
$env:all_proxy   = 'http://127.0.0.1:7897'

# 加载 CLI 静态缓存 (Starship 提示符 & zoxide 目录记录)
if (Test-Path -LiteralPath "$PSScriptRoot\starship_init.ps1") { . "$PSScriptRoot\starship_init.ps1" }
if (Test-Path -LiteralPath "$PSScriptRoot\zoxide_init.ps1") {
    $global:__zoxide_hooked = 0
    . "$PSScriptRoot\zoxide_init.ps1"
}

# 浅色模式色彩优化 (仅当终端使用 AtomOneLight 时激活)
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if ([IO.File]::Exists($wt) -and ([IO.File]::ReadAllText($wt) -match '"colorScheme"\s*:\s*.*AtomOneLight')) {
    Set-PSReadLineOption -Colors @{
        ListPredictionSelected = "`e[48;2;208;223;238m"
        Selection              = "`e[30;48;2;208;223;238m"
        InlinePrediction       = "`e[38;2;168;172;180;3m"
        ListPredictionTooltip  = "`e[38;2;168;172;180;3m"
        Number                 = "`e[38;2;180;110;20m"
    }
}

# 防止 Windows 无障碍读屏状态干扰自动补全
if ((Get-Command Set-PSReadLineOption).Parameters.ContainsKey('EnableScreenReaderMode')) {
    Set-PSReadLineOption -EnableScreenReaderMode:$false
}

# 常用 CLI 别名与维护函数
Set-Alias -Name lg -Value lazygit -Option AllScope

function scoop-update {
    $ErrorActionPreference = 'Stop'
    scoop update &&
        scoop update * &&
        & {
            $issues = @(scoop status --local)
            if ($LASTEXITCODE -ne 0 -or $issues.Count) {
                $issues | Format-Table
                throw 'Scoop 状态异常，停止更新与清理。'
            }
        } &&
        & "$PSScriptRoot\Sync-DevEnvironment.ps1" &&
        pnpm runtime set node lts -g &&
        pnpm add -g npm@latest &&
        uv python install 3 --upgrade &&
        uv python upgrade &&
        uv tool upgrade --all &&
        go install golang.org/x/tools/gopls@latest &&
        go install github.com/go-delve/delve/cmd/dlv@latest &&
        go install honnef.co/go/tools/cmd/staticcheck@latest &&
        . $PROFILE &&
        scoop cleanup * &&
        scoop cache rm * &&
        pnpm store prune &&
        uv cache prune
}
