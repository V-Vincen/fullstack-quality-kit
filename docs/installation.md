# 安装说明

当前仓库提供项目级安装和全局安装两种方式。安装前应先执行验证脚本；脚本默认不覆盖内容不同的已有文件。验证数量统一由 `scripts/validation-rules.conf` 维护，新增或删除 skill、工作流或清单时应同步调整该文件。

## 验证仓库

### macOS/Linux

~~~bash
./scripts/validate.sh
~~~

### Windows PowerShell

直接执行 PowerShell 脚本前，如果当前环境阻止未签名脚本，可以只对当前 PowerShell 进程放行：

~~~powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\validate.ps1
~~~

### Windows 命令提示符

在传统命令提示符中使用批处理入口：

~~~bat
scripts\validate.bat
~~~

## 项目级安装

将 skill 和清单安装到业务项目，不修改业务项目的 AGENTS.md：

### macOS/Linux

~~~bash
./scripts/install-project.sh /绝对路径/业务项目
~~~

### Windows PowerShell

~~~powershell
.\scripts\install-project.ps1 -ProjectDir 'D:\Projects\业务项目'
~~~

### Windows 命令提示符

~~~bat
scripts\install-project.bat "D:\Projects\业务项目"
~~~

如果目标文件不存在，脚本会创建；如果目标文件已存在且内容一致，脚本会跳过；如果内容不同，脚本会停止并报告冲突。

重复执行同一命令是安全的。

## 全局安装

默认安装到 `~/.codex/`，包括：

- `~/.codex/skills/fullstack-review/`
- `~/.codex/checklists/fullstack-quality-kit/`
- 全局 `AGENTS.md` 中受标记管理的联动规则区块

`~/.codex/skills/fullstack-review/` 直接包含主 `SKILL.md`、子 skill 和工作流，不会额外嵌套一层 `fullstack-review/` 目录。

### macOS/Linux

交互式执行：

~~~bash
./scripts/install-global.sh
~~~

非交互执行必须明确使用：

~~~bash
./scripts/install-global.sh --yes
~~~

也可以指定其他全局目录：

~~~bash
./scripts/install-global.sh --yes /绝对路径/Codex目录
~~~

### Windows PowerShell

~~~powershell
.\scripts\install-global.ps1
.\scripts\install-global.ps1 -Yes
.\scripts\install-global.ps1 -Yes -CodexHomePath 'D:\Codex'
~~~

### Windows 命令提示符

~~~bat
scripts\install-global.bat -Yes
~~~

脚本只合并 `rules/global-agents.block.md` 管理的规则区块，不覆盖用户完整的全局 `AGENTS.md`。已有不同内容的文件会触发冲突并停止。

全局安装会在 `~/.codex/checklists/fullstack-quality-kit/.fullstack-quality-kit.manifest` 写入安装清单 v2。清单只记录本次新增的文件和本次新插入的规则区块，并保存内容指纹；安装前已存在且内容一致的文件不会被纳入卸载范围。检测到旧版清单时，脚本仅在原文件和规则区块仍与当前源一致时升级为 v2；无法安全升级时会停止，不会删除或覆盖旧内容。

## 查看状态

### macOS/Linux

~~~bash
./scripts/status.sh /绝对路径/业务项目
~~~

第二个参数可以指定全局目录：

~~~bash
./scripts/status.sh /绝对路径/业务项目 /绝对路径/Codex目录
~~~

### Windows PowerShell

~~~powershell
.\scripts\status.ps1 -ProjectDir 'D:\Projects\业务项目' -CodexHomePath 'D:\Codex'
~~~

### Windows 命令提示符

~~~bat
scripts\status.bat "D:\Projects\业务项目" "D:\Codex"
~~~

状态结果分为两层：目录状态显示安装目标与当前仓库源的差异；安装清单 v2 显示由本工具管理的内容是否被修改、缺失或损坏。两者分别回答“是否跟随当前源”和“是否可由卸载脚本安全处理”。

## 全局卸载

全局卸载只处理安装清单 v2 记录的文件和受标记管理的规则区块，不删除用户原有的同名文件：

### macOS/Linux

~~~bash
./scripts/uninstall-global.sh
~~~

非交互执行：

~~~bash
./scripts/uninstall-global.sh --yes
~~~

### Windows PowerShell

~~~powershell
.\scripts\uninstall-global.ps1 -Yes
~~~

### Windows 命令提示符

~~~bat
scripts\uninstall-global.bat -Yes
~~~

卸载前脚本会按内容指纹核验每个记录：内容未变才删除；内容已被用户修改时保留文件和对应清单记录，并以非零状态结束，提示卸载未完全完成。旧版或无法核验的安装清单不会被卸载；请先运行全局安装脚本完成安全升级。移除规则区块前会备份全局 `AGENTS.md`。项目级安装需要由项目维护者根据项目 Git 状态回滚，不使用全局卸载脚本。
