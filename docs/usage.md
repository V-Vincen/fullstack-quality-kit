# 使用说明

本文通过一个完整案例说明脚本作用、预期结果、项目级使用、全局使用和 Codex 调用方式。示例使用以下路径：

~~~text
质量工具仓库：/path/to/fullstack-quality-kit
业务项目：/path/to/demo-project
全局 Codex 目录：~/.codex
~~~

项目级安装不覆盖内容不同的已有文件；全局安装只会安全升级安装清单记录且未被用户修改的内容。没有安装记录、无法核验或已被用户修改的内容会触发冲突并停止，避免破坏业务项目或全局配置。

## 脚本总览

| 脚本 | 作用 | 执行后的预期结果 |
|---|---|---|
| `validate.sh`、`validate.ps1`、`validate.bat` | 验证 skill、工作流、清单、路由、脚本入口和旧引用 | 按 `scripts/validation-rules.conf` 的统一数量输出验证通过 |
| `install-project.sh`、`install-project.ps1`、`install-project.bat` | 将 skill 和清单复制到业务项目 `.codex/` | 输出项目级安装完成；一致文件跳过，冲突文件停止 |
| `install-global.sh`、`install-global.ps1`、`install-global.bat` | 安装或安全升级全局 Codex 内容，并按需合并受管理的全局规则区块 | 输出新增、升级和跳过数量；以安装清单 v2 记录本工具管理的内容及其内容哈希 |
| `uninstall-global.sh`、`uninstall-global.ps1`、`uninstall-global.bat` | 卸载全局安装清单中的文件和受管理规则区块 | 仅移除内容哈希仍一致的项目；已修改内容保留并提示未完全卸载 |
| `status.sh`、`status.ps1`、`status.bat` | 对比源文件、项目级安装和全局安装 | 分别输出与当前源的差异，以及安装清单 v2 的一致、已修改、缺失和格式异常状态 |

其中，`.sh` 适用于 macOS/Linux，`.ps1` 适用于 Windows PowerShell，`.bat` 是 Windows 命令提示符入口。批处理文件只负责转发到对应的 PowerShell 脚本。

## 案例一：项目级安装和调用

项目级安装适合先在一个业务项目中试用。它只修改业务项目的 `.codex/skills/` 和 `.codex/checklists/`，不修改业务项目的 `AGENTS.md`，也不影响其他项目。

### macOS/Linux

进入质量工具仓库并验证：

~~~bash
cd /path/to/fullstack-quality-kit
./scripts/validate.sh
~~~

预期结果：

~~~text
验证通过：8 个 skill、5 个工作流、4 个总清单、27 个领域子清单、工作流引用、活动引用、Unix 入口与语法、Windows 入口文件与批处理转发关系均正常。
~~~

安装到业务项目：

~~~bash
./scripts/install-project.sh /path/to/demo-project
~~~

预期结果：

~~~text
已处理 .../.codex/skills：新增若干文件，已存在且一致若干文件。
已处理 .../.codex/checklists：新增若干文件，已存在且一致若干文件。
项目级安装完成：/path/to/demo-project
~~~

检查项目级安装：

~~~bash
./scripts/status.sh \
  /path/to/demo-project \
  ~/.codex
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

全局安装适合让多个业务项目共用同一套 skill 和清单。默认目标是 `~/.codex/`，不会覆盖用户完整的全局 `AGENTS.md`，只合并 `rules/global-agents.block.md` 管理的规则区块。已有等效联动规则时，可以使用跳过规则参数，避免重复写入。

安装后的 `~/.codex/skills/fullstack-review/` 直接包含 `SKILL.md`、子 skill 和工作流。安装清单 v2 只记录本工具创建或安全升级的内容，并为每项保存内容哈希；因此全局卸载不会处理原先已存在、但内容刚好一致的用户文件。

### macOS/Linux

先在质量工具仓库中执行验证和状态检查：

~~~bash
cd /path/to/fullstack-quality-kit
./scripts/validate.sh
./scripts/status.sh \
  /path/to/demo-project \
  ~/.codex
~~~

交互式安装：

~~~bash
./scripts/install-global.sh
~~~

脚本会在修改前检查目标文件。安装清单记录且内容未被用户修改的旧版本可以安全升级；没有安装记录或已被用户修改的不同内容会触发冲突并停止。

如果全局 `AGENTS.md` 已经包含等效联动规则，只安装 skill 和清单：

~~~bash
./scripts/install-global.sh --skip-agents
~~~

预期结果：

~~~text
已备份全局规则：<Codex 全局目录>/backups/...
已处理 .../.codex/skills：新增若干文件，安全升级若干文件，已存在且一致若干文件。
已处理 .../.codex/checklists：新增若干文件，安全升级若干文件，已存在且一致若干文件。
全局安装完成：<Codex 全局目录>
~~~

非交互执行只能在已经明确确认安装范围后使用：

~~~bash
./scripts/install-global.sh --yes
~~~

已有等效全局规则时：

~~~bash
./scripts/install-global.sh --yes --skip-agents
~~~

安装后检查：

~~~bash
./scripts/status.sh \
  /path/to/demo-project \
  ~/.codex
~~~

全局部分应显示：

~~~text
已安装且一致：<Codex 全局目录>/skills/fullstack-review
已安装且一致：<Codex 全局目录>/checklists/fullstack-quality-kit
全局安装清单 v2：一致 N 个，已修改 0 个，缺失 0 个，格式异常 0 个
全局规则管理区块：已纳入安装清单
~~~

如果安装时使用了 `--skip-agents` 或 `-SkipAgents`，最后一行应改为：

~~~text
未合并全局规则管理区块
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

已有等效全局规则时：

~~~powershell
.\scripts\install-global.ps1 -SkipAgents
~~~

非交互安装：

~~~powershell
.\scripts\install-global.ps1 -Yes -CodexHomePath 'D:\Codex'
.\scripts\install-global.ps1 -Yes -SkipAgents -CodexHomePath 'D:\Codex'
~~~

### Windows 命令提示符

~~~bat
cd /d D:\Projects\fullstack-quality-kit
scripts\validate.bat
scripts\install-global.bat -Yes
scripts\install-global.bat -Yes -SkipAgents
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

## 工作流调用

工作流只在满足触发条件时由 `fullstack-review` 按需读取，普通且范围明确的调用仍走原有专业子 skill 和清单路由。工作流补充任务执行方式，不替代专业审查职责、授权门禁或清单门禁。

| 用户需要 | 可以明确提出的方式 | 预期结果 |
|---|---|---|
| 需求澄清 | “先进行需求澄清，不修改文件。” | 最多提出 5 个影响执行方向的问题，并输出目标、范围、授权、验收标准和待确认事项。 |
| 设计 | “为新增 Skill 先输出设计方案，暂不修改。” | 输出职责边界、路由、影响、风险、回滚和待确认事项；未经确认不写入。 |
| 验证 | “请验证刚修改的 Skill 或清单。” | 记录基线，执行正常、异常、边界和重复执行验证，并报告实际命令和结果。 |
| 画图 | “请画出 Skill、清单和验证脚本的调用关系。” | 基于真实文件和已验证路由输出 Mermaid 图，并标注待确认关系。 |
| 用户流程验收 | “请从普通用户入口完成用户流程验收，不修改产品。” | 实际验证核心任务、异常恢复、可理解性和页面表现，并报告证据、问题和未覆盖范围。 |

用户不必记住文件路径：目标、范围、授权或验收标准不清时，主 skill 会进入需求澄清；新增 Skill、清单、路由或目录结构时，会先进入设计；修改 Skill、清单、路由或脚本后，会进入验证；关系复杂或用户明确要求时，会输出图形化说明；用户要求用户流程或上线前体验验收，或审查覆盖核心用户流程时，会进入用户流程验收。

`visualize` 只是可选增强能力。无论它是否可用，默认都可以直接输出 Mermaid，因此不会形成外部依赖。

## 冲突、重复执行和回滚

### 重复执行

同一安装命令可以重复执行：

- 内容一致的文件会跳过。
- 不同内容的文件会报告冲突并停止。
- 不会因为重复执行而覆盖已有文件。

### 冲突处理

发现冲突时，先查看目标文件和仓库源文件的差异，确认目标文件归属后再决定保留、合并或备份迁移。不要直接删除或覆盖业务项目已有文件。

### 全局卸载

全局卸载只处理全局安装清单 v2 记录的文件和受标记管理的规则区块：

~~~bash
cd /path/to/fullstack-quality-kit
./scripts/uninstall-global.sh
~~~

预期结果：

~~~text
已备份全局规则：<Codex 全局目录>/backups/...
全局卸载完成：<Codex 全局目录>
~~~

如果某个已安装文件或规则区块在安装后被修改，脚本会保留它及其清单记录，并以非零状态结束：

~~~text
全局卸载完成：<Codex 全局目录>；已移除 N 个，保留已修改 M 个，缺失 0 个。
提示：存在已修改内容，卸载未完全完成；对应记录已保留。
~~~

检测到旧版或无法核验的安装清单时，先重新执行一次全局安装，让脚本在内容仍一致的前提下安全升级为 v2；升级失败时应先人工确认文件归属，不要绕过脚本直接删除。

项目级安装不使用全局卸载脚本。如需回滚项目级安装，应先检查业务项目 Git 状态，再由项目维护者恢复 `.codex/skills/` 和 `.codex/checklists/`。

### 旧目录清理

全局安装成功后不要立即删除旧目录。建议先完成一次真实项目审查，确认项目级优先路径、全局兜底路径和规则联动均正常，再经过明确确认后清理旧副本。

如果旧版清单直接位于 `~/.codex/checklists/` 根目录，清理对象只能是经过核对和备份的旧文件与旧领域目录；必须保留新命名空间 `~/.codex/checklists/fullstack-quality-kit/`。这些旧副本不属于安装清单管理范围，卸载脚本不会自动删除。

## 验收标准

一次完整案例至少满足以下条件：

- `validate` 脚本通过。
- 项目级或全局目标显示“已安装且一致”。
- 全局安装存在安装清单；未跳过全局规则时，规则管理区块已纳入安装清单；跳过规则时，原有全局 `AGENTS.md` 保持不变。
- 重新打开 Codex 后可以调用 `$fullstack-review`。
- 审查结果包含触发场景、证据、根因、影响、修复建议、验证结果、未覆盖项和已知风险。
- 常规测试用例覆盖正常、失败、异常、边界、权限、重复执行、并发与幂等、回归等适用场景。
- 未经确认不清理旧目录，不把局部验证描述为全项目通过。
