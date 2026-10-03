# 安装说明

当前仓库提供项目级安装和全局安装两种方式。安装前应先执行验证脚本；脚本默认不覆盖内容不同的已有文件。

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

## 全局卸载

全局卸载只处理安装清单记录的文件和受标记管理的规则区块，不删除用户原有的同名文件：

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

卸载前脚本会备份被移除规则区块的全局 `AGENTS.md`。项目级安装需要由项目维护者根据项目 Git 状态回滚，不使用全局卸载脚本。
