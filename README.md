# Dotfiles

基于 [chezmoi](https://www.chezmoi.io/) 管理的 Windows 个人开发环境配置仓库。

## 包含配置

| 类别 | 配置文件 | 说明 |
| :--- | :--- | :--- |
| **PowerShell 7** | [`Microsoft.PowerShell_profile.ps1`](./Documents/PowerShell/Microsoft.PowerShell_profile.ps1)、[`Sync-DevEnvironment.ps1`](./Documents/PowerShell/Sync-DevEnvironment.ps1)、[`powershell.config.json`](./Documents/PowerShell/powershell.config.json) | 终端预加载配置、CLI 静态缓存同步与执行策略 |
| **Windows Terminal** | [`settings.json`](./AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json) | 终端外观（AtomOneLight 主题）、字体与快捷键 |
| **Scoop** | [`config.json.tmpl`](./dot_config/scoop/config.json.tmpl)、[`scoopfile.json`](./dot_config/scoop/scoopfile.json) | 路径与软件清单；保留本机更新状态和凭证 |
| **Git & WSL** | [`dot_gitconfig`](./dot_gitconfig)、[`dot_wslconfig`](./dot_wslconfig) | Git 全局配置（delta 高亮）、WSL2 镜像网络与稀疏磁盘 |
| **Node.js & pnpm** | [`dot_npmrc`](./dot_npmrc)、[`config.yaml`](./AppData/Local/pnpm/config/config.yaml) | npm 镜像源与 pnpm 全局存储路径 |
| **Go & Maven** | [`env`](./AppData/Roaming/go/env)、[`settings.xml`](./dot_m2/settings.xml) | Go 代理/缓存路径与 Maven 本地仓库路径 |
| **编辑器 & AI 规范** | [`GEMINI.md`](./dot_gemini/GEMINI.md)、[`dot_markdownlint.json`](./dot_markdownlint.json)、[`Zed/`](./AppData/Roaming/Zed/) | 全局开发规则、Markdown 规范与 Zed 编辑器配置 |

## 新设备快速恢复

```powershell
# 1. 安装 chezmoi 并应用配置（先安装 Scoop 和 PowerShell 7）
scoop install chezmoi
chezmoi init --apply czefan/dotfiles-windows

# 2. 恢复 Scoop 软件源与工具
scoop import "$HOME\.config\scoop\scoopfile.json"

# 3. 生成 CLI 静态初始化缓存并同步环境变量
& "$(Split-Path -Parent $PROFILE)\Sync-DevEnvironment.ps1"

# 4. 恢复默认运行时与开发工具，并更新清理
. $PROFILE
scoop-update
uv tool install ruff
```

本仓库使用 `D:\Scoop`、`D:\Cache\Dev`，迁移时按需统一修改路径。同步完成后重开终端。Windows 与 WSL 的开发环境分别维护。

## 日常维护

* **VS Code 可视化编辑与提交**：

  ```powershell
  code (chezmoi source-path)
  ```

  打开仓库时先检查差异，再更新 Scoop 软件清单。保存时只同步对应配置；目标文件已被外部修改、源文件删除或改名时，任务会停止并提示。合并差异后重新运行同步任务。
* **命令行常用操作**：

  ```powershell
  chezmoi add <file>   # 纳入新配置文件
  chezmoi re-add <file> # 将确认保留的系统修改同步回仓库
  chezmoi diff         # 查看仓库与系统原文件的差异
  chezmoi apply --error-on-conflict # 应用配置，冲突时停止
  chezmoi merge <file> # 合并两边的修改
  ```

## License

[MIT](./LICENSE)
