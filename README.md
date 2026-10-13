# Dotfiles

基于 [chezmoi](https://www.chezmoi.io/) 管理的 Windows 个人开发环境配置仓库。

## 包含配置

| 类别 | 配置文件 | 说明 |
| :--- | :--- | :--- |
| **PowerShell 7** | [`Microsoft.PowerShell_profile.ps1`](./Documents/PowerShell/Microsoft.PowerShell_profile.ps1)、[`Sync-DevEnvironment.ps1`](./Documents/PowerShell/Sync-DevEnvironment.ps1)、[`powershell.config.json`](./Documents/PowerShell/powershell.config.json) | 终端预加载配置、CLI 静态缓存同步与执行策略 |
| **Windows Terminal** | [`settings.json`](./AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json) | 终端外观（AtomOneLight 主题）、字体与快捷键 |
| **Scoop** | [`config.json`](./dot_config/scoop/config.json)、[`scoopfile.json`](./dot_config/scoop/scoopfile.json) | Scoop 路径配置与已安装 Bucket / 软件清单 |
| **Git & WSL** | [`dot_gitconfig`](./dot_gitconfig)、[`dot_wslconfig`](./dot_wslconfig) | Git 全局配置（delta 高亮）、WSL2 镜像网络与稀疏磁盘 |
| **Node.js & pnpm** | [`dot_npmrc`](./dot_npmrc)、[`config.yaml`](./AppData/Local/pnpm/config/config.yaml) | npm 镜像源与 pnpm 全局存储路径 |
| **Go & Maven** | [`env`](./AppData/Roaming/go/env)、[`settings.xml`](./dot_m2/settings.xml) | Go 代理/缓存路径与 Maven 本地仓库路径 |
| **编辑器 & AI 规范** | [`GEMINI.md`](./dot_gemini/GEMINI.md)、[`dot_markdownlint.json`](./dot_markdownlint.json)、[`Zed/`](./AppData/Roaming/Zed/) | 全局开发规则、Markdown 规范与 Zed 编辑器配置 |

## 新设备快速恢复

```powershell
# 1. 安装 chezmoi 并拉取应用全部配置
scoop install chezmoi
chezmoi init --apply czefan/dotfiles-windows

# 2. (可选) 批量恢复 Scoop 软件源与已安装工具
scoop import "$HOME\.config\scoop\scoopfile.json"

# 3. 生成 CLI 静态初始化缓存并同步环境变量
& "$(Split-Path -Parent $PROFILE)\Sync-DevEnvironment.ps1"
```

## 日常维护

* **VS Code 可视化编辑与提交**：

  ```powershell
  code (chezmoi source-path)
  ```

  打开仓库时会自动执行 `scoop export` 与 `chezmoi re-add` 拉取外部修改；在 VS Code 中按 `Ctrl+S` 保存文件会自动触发 `chezmoi apply` 实时同步回系统原文件。
* **命令行常用操作**：

  ```powershell
  chezmoi add <file>   # 纳入新配置文件
  chezmoi re-add       # 将外部系统原文件的修改同步回仓库
  chezmoi diff         # 查看仓库与系统原文件的差异
  chezmoi apply        # 将仓库配置应用到系统
  ```

## License

[MIT](./LICENSE)
