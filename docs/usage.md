# 使用说明

本文通过一个完整案例说明脚本作用、预期结果、项目级使用、全局使用和 Codex 调用方式。示例使用以下路径：

~~~text
质量工具仓库：/Users/vincent/Projects/AiCode/fullstack-quality-kit
业务项目：/Users/vincent/Projects/AiCode/demo-project
全局 Codex 目录：/Users/vincent/.codex
~~~

脚本默认不覆盖内容不同的已有文件；发现冲突时会停止并报告，避免破坏业务项目或全局配置。

## 脚本总览

| 脚本 | 作用 | 执行后的预期结果 |
|---|---|---|
| `validate.sh`、`validate.ps1`、`validate.bat` | 验证 skill、清单、路由、脚本入口和旧引用 | 输出 8 个 skill、4 个总清单、26 个领域子清单验证通过 |
| `install-project.sh`、`install-project.ps1`、`install-project.bat` | 将 skill 和清单复制到业务项目 `.codex/` | 输出项目级安装完成；一致文件跳过，冲突文件停止 |
| `install-global.sh`、`install-global.ps1`、`install-global.bat` | 安装到全局 Codex 目录，并合并受标记管理的全局规则区块 | 输出全局安装完成；备份全局规则并生成安装清单 |
| `uninstall-global.sh`、`uninstall-global.ps1`、`uninstall-global.bat` | 卸载全局安装清单中的文件和受管理规则区块 | 输出全局卸载完成；卸载前备份全局规则 |
| `status.sh`、`status.ps1`、`status.bat` | 对比源文件、项目级安装和全局安装 | 输出已安装且一致、缺失文件、冲突文件、安装清单和规则区块状态 |

其中，`.sh` 适用于 macOS/Linux，`.ps1` 适用于 Windows PowerShell，`.bat` 是 Windows 命令提示符入口。批处理文件只负责转发到对应的 PowerShell 脚本。

## 案例一：项目级安装和调用

项目级安装适合先在一个业务项目中试用。它只修改业务项目的 `.codex/skills/` 和 `.codex/checklists/`，不修改业务项目的 `AGENTS.md`，也不影响其他项目。

### macOS/Linux

进入质量工具仓库并验证：

~~~bash
cd /Users/vincent/Projects/AiCode/fullstack-quality-kit
./scripts/validate.sh
~~~

预期结果：

~~~text
验证通过：8 个 skill、4 个总清单、26 个领域子清单、活动引用、Unix 入口和 Windows 入口均正常。
~~~

安装到业务项目：

~~~bash
./scripts/install-project.sh /Users/vincent/Projects/AiCode/demo-project
~~~

预期结果：

~~~text
已处理 .../.codex/skills：新增若干文件，已存在且一致若干文件。
已处理 .../.codex/checklists：新增若干文件，已存在且一致若干文件。
项目级安装完成：/Users/vincent/Projects/AiCode/demo-project
~~~

检查项目级安装：

~~~bash
./scripts/status.sh \
  /Users/vincent/Projects/AiCode/demo-project \
  /Users/vincent/.codex
~~~

项目级目标应显示：

~~~text
已安装且一致：.../.codex/skills
已安装且一致：.../.codex/checklists
~~~

### Windows PowerShell

~~~powershell
Set-Location 'D:\Projects\fullstack-quality-kit'
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\validate.ps1
.\scripts\install-project.ps1 -ProjectDir 'D:\Projects\demo-project'
.\scripts\status.ps1 -ProjectDir 'D:\Projects\demo-project' -CodexHomePath 'D:\Codex'
~~~

### Windows 命令提示符

~~~bat
cd /d D:\Projects\fullstack-quality-kit
scripts\validate.bat
scripts\install-project.bat "D:\Projects\demo-project"
scripts\status.bat "D:\Projects\demo-project" "D:\Codex"
~~~

### 在项目中调用

安装完成后，在业务项目目录重新打开 Codex，在对话框中输入：

~~~text
$fullstack-review

请先识别当前项目技术栈，再审查当前项目。
只进行分析，不修改文件。
请输出问题、证据、根因、影响、修复建议、常规测试用例、未覆盖项和已知风险。
~~~

主 skill 会根据项目文件、依赖和请求自动选择专业 skill：

- Java 和 JVM 代码：`backend/java-review`
- Spring Boot 配置、接口、事务和消息：`backend/springboot-review`
- 数据库引擎、SQL、索引、事务、锁和迁移：`backend/database-review`
- MyBatis、JPA/Hibernate、JDBC、Mapper 和 Repository：`backend/data-access-review`
- 前端页面、组件、状态和浏览器交互：`frontend-review`
- 认证、授权、注入、敏感数据和依赖安全：`security-review`
- 测试计划、常规测试用例和测试代码：`test-generation`

项目级清单优先于全局清单。只要业务项目存在对应文件，主 skill 会优先使用业务项目中的清单。

## 案例二：全局安装和调用

全局安装适合让多个业务项目共用同一套 skill 和清单。默认目标是 `~/.codex/`，不会覆盖用户完整的全局 `AGENTS.md`，只合并 `rules/global-agents.block.md` 管理的规则区块。

### macOS/Linux

先在质量工具仓库中执行验证和状态检查：

~~~bash
cd /Users/vincent/Projects/AiCode/fullstack-quality-kit
./scripts/validate.sh
./scripts/status.sh \
  /Users/vincent/Projects/AiCode/demo-project \
  /Users/vincent/.codex
~~~

交互式安装：

~~~bash
./scripts/install-global.sh
~~~

脚本会在修改前检查目标文件。目标全局目录中如已有不同内容，脚本会停止，不会覆盖；如果需要更新，先处理冲突，再重新执行。

预期结果：

~~~text
已备份全局规则：/Users/vincent/.codex/backups/...
已处理 .../.codex/skills：新增若干文件，已存在且一致若干文件。
已处理 .../.codex/checklists：新增若干文件，已存在且一致若干文件。
全局安装完成：/Users/vincent/.codex
~~~

非交互执行只能在已经明确确认安装范围后使用：

~~~bash
./scripts/install-global.sh --yes
~~~

安装后检查：

~~~bash
./scripts/status.sh \
  /Users/vincent/Projects/AiCode/demo-project \
  /Users/vincent/.codex
~~~

全局部分应显示：

~~~text
已安装且一致：/Users/vincent/.codex/skills/fullstack-review
已安装且一致：/Users/vincent/.codex/checklists/fullstack-quality-kit
存在全局安装清单
已合并全局规则管理区块
~~~

重新打开 Codex 后，在任意业务项目中调用：

~~~text
$fullstack-review

请审查当前项目的 Java、Spring Boot、数据库访问、前端交互、安全和测试覆盖。
只分析当前改动，不修改文件。
~~~

### Windows PowerShell

~~~powershell
Set-Location 'D:\Projects\fullstack-quality-kit'
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\validate.ps1
.\scripts\install-global.ps1
.\scripts\status.ps1 -ProjectDir 'D:\Projects\demo-project' -CodexHomePath 'D:\Codex'
~~~

非交互安装：

~~~powershell
.\scripts\install-global.ps1 -Yes -CodexHomePath 'D:\Codex'
~~~

### Windows 命令提示符

~~~bat
cd /d D:\Projects\fullstack-quality-kit
scripts\validate.bat
scripts\install-global.bat -Yes
scripts\status.bat "D:\Projects\demo-project" "D:\Codex"
~~~

## 清单解析和调用关系

清单解析顺序固定为：

~~~text
当前业务项目/.codex/checklists/
    ↓ 对应文件不存在时
~/.codex/checklists/fullstack-quality-kit/
~~~

调用关系如下：

~~~text
$fullstack-review
    ↓ 识别项目技术栈和受影响范围
选择专业 skill
    ↓
读取对应总清单和领域子清单
    ↓
输出审查结果和常规测试用例
~~~

不需要手动调用清单，也不建议把所有领域 skill 一次性全部加载。主 skill 会按实际范围组合 Java、Spring Boot、数据库、数据访问、前端、安全和测试检查。

## 冲突、重复执行和回滚

### 重复执行

同一安装命令可以重复执行：

- 内容一致的文件会跳过。
- 不同内容的文件会报告冲突并停止。
- 不会因为重复执行而覆盖已有文件。

### 冲突处理

发现冲突时，先查看目标文件和仓库源文件的差异，确认目标文件归属后再决定保留、合并或备份迁移。不要直接删除或覆盖业务项目已有文件。

### 全局卸载

全局卸载只处理全局安装清单记录的文件和受标记管理的规则区块：

~~~bash
cd /Users/vincent/Projects/AiCode/fullstack-quality-kit
./scripts/uninstall-global.sh
~~~

预期结果：

~~~text
已备份全局规则：/Users/vincent/.codex/backups/...
全局卸载完成：/Users/vincent/.codex
~~~

项目级安装不使用全局卸载脚本。如需回滚项目级安装，应先检查业务项目 Git 状态，再由项目维护者恢复 `.codex/skills/` 和 `.codex/checklists/`。

### 旧目录清理

全局安装成功后不要立即删除旧目录。建议先完成一次真实项目审查，确认项目级优先路径、全局兜底路径和规则联动均正常，再经过明确确认后清理旧副本。

## 验收标准

一次完整案例至少满足以下条件：

- `validate` 脚本通过。
- 项目级或全局目标显示“已安装且一致”。
- 全局安装存在安装清单和规则管理区块。
- 重新打开 Codex 后可以调用 `$fullstack-review`。
- 审查结果包含触发场景、证据、根因、影响、修复建议、验证结果、未覆盖项和已知风险。
- 常规测试用例覆盖正常、失败、异常、边界、权限、重复执行、并发与幂等、回归等适用场景。
- 未经确认不清理旧目录，不把局部验证描述为全项目通过。
