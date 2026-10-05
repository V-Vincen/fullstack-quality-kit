# 变更记录

## 未发布

### 第 9 步阶段性进展

- 已在 `/Users/vincent/Projects/AiCode/devops/devops-platform` 完成项目级安装。
- 8 个 skill 和 30 个清单已安装且内容一致。
- 工具调用验收、全局安装、切换和旧目录清理仍待执行。
- 上次调用测试超出只读工具验收范围，已停止，不作为通过结果。

## v0.1.1 - 2026-10-05

### 使用案例说明

- 将 `docs/usage.md` 完善为案例使用说明。
- 在文档开头补充全部脚本的作用、平台入口和预期结果。
- 补充项目级安装、全局安装、Codex 调用、验证、冲突处理、回滚和旧目录清理流程。

### 正式发布

- 创建正式版本标签 `v0.1.1`。
- 本版本基于 `v0.1.0`，补充完整的脚本说明和项目级、全局使用案例。
- 第 9 步全局安装、切换和旧目录清理仍待执行。

## v0.1.0 - 2026-10-04

### 第 2 步：确定仓库结构并建立骨架

- 创建仓库根目录维护规则。
- 创建项目说明、许可证占位文件和变更记录。
- 创建 .codex、rules、scripts 和 docs 目录骨架。
- 保留已有 Git 初始化、远程地址和未跟踪文件。
- 尚未迁移 skills、清单或全局规则。

### 第 3 步：迁移规则、清单和 skills

- 迁移 1 个主 skill 和 6 个专业子 skill。
- 迁移 4 个总清单和 25 个领域子清单。
- 提取全局 AGENTS.md 中的 skill 与清单联动区块。
- 新增迁移映射文档。
- 保留源文件不变。
- 尚未调整全局路径，尚未创建安装脚本。

### 第 4 步：统一路径和联动关系

- 将 skill 和总清单中的直接全局路径统一为 CHECKLIST_ROOT。
- 明确项目级清单优先、全局命名空间清单兜底的解析顺序。
- 补充主 skill 和专业子 skill 的路径解析说明。
- 新增清单路由说明文档。
- 保持 25 个领域子清单正文不变。
- 尚未创建安装、卸载、验证和状态脚本。

### 第 4 步设计修正：拆分数据库与数据访问审查

- 将 backend/mysql-review 拆分为 backend/database-review 和 backend/data-access-review。
- database-review 覆盖 MySQL、PostgreSQL、Oracle、SQL Server、SQLite 等数据库引擎、表结构、SQL、索引、事务、锁、迁移和回滚。
- data-access-review 覆盖 MyBatis、JPA/Hibernate、JDBC、Mapper、Repository、ORM 和查询构建器的数据访问实现。
- 同步更新仓库内 skill 与本地源 skill：`/Users/vincent/Projects/AiCode/Codex/skills/fullstack-review/`。
- 删除旧 mysql-review skill 文件；未修改 25 个领域子清单正文。

### 第 4 步设计修正：拆分数据库与数据访问代码审查清单

- 将 `code-review/mysql-mybatis-quality.md` 拆分为 `code-review/database-quality.md` 和 `code-review/data-access-quality.md`。
- database-quality 覆盖数据库引擎、表结构、SQL、索引、执行计划、事务、锁、迁移和回滚。
- data-access-quality 覆盖 MyBatis、JPA/Hibernate、JDBC、Mapper、Repository、ORM、参数绑定、映射、N+1、批处理和数据权限。
- 同步更新仓库清单、全局源清单和本地源 skill；旧清单文件已删除并保留备份。
- 领域子清单数量由 25 个增加为 26 个，总清单和领域子清单合计由 29 个增加为 30 个。

### 第 5 步：编写安装、卸载和验证脚本

- 新增 `validate.sh`，检查 skill 元数据、清单数量、路由文件、旧引用和脚本语法。
- 新增 `install-project.sh`，支持项目级首次安装、重复执行和冲突停止。
- 新增 `install-global.sh`，支持全局 skill、命名空间清单和受标记规则区块的安全安装。
- 新增 `uninstall-global.sh`，只卸载安装清单记录的文件和受标记规则区块。
- 新增 `status.sh`，显示源文件、项目级安装和全局安装状态。
- 新增安装说明和使用说明；尚未完成示例项目验证和正式发布。

### 第 5 步补充：增加 Windows 入口

- 新增 5 个 PowerShell 脚本，覆盖仓库验证、项目级安装、全局安装、全局卸载和状态查询。
- 新增 5 个批处理入口，统一转发到对应的 PowerShell 脚本。
- 保留 Bash 脚本作为 macOS/Linux 入口，不改变原有参数和安装目录。
- 更新仓库验证脚本、安装说明、使用说明和执行计划。
- 当前环境不是 Windows，Windows 入口已完成静态检查，尚未在真实 Windows 主机上执行闭环验证。

### 第 5 步补充：统一 Markdown 文档排版

- 新增 docs/markdown-style-guide.md，统一仓库内 Markdown 的标题、空行、代码块、列表、表格、链接和文档类型结构。
- 为根目录 AGENTS.md 和 README.md 增加规范入口。
- 统一相关 skill、清单和说明文档的代码围栏格式。
- 同步本地源 skill 和全局源清单，保持仓库版本与本地版本一致。

### 第 6 步：执行静态和结构验证

- 通过 8 个 skill、4 个总清单和 26 个领域子清单的数量检查。
- 通过活动引用、脚本语法、Windows 入口转发目标和重复执行检查。
- 通过仓库验证脚本和 16 个 skill 目录的元数据检查。
- 尚未执行示例项目验证、真实 Windows 闭环、真实全局安装和 GitHub 发布。

### 第 7 步：使用示例项目进行实际验证

- 使用临时多技术栈示例项目验证 Java、Spring Boot、MyBatis、数据库索引、前端重复提交、权限和测试覆盖 7 类场景。
- 验证 7 类问题均能路由到正确的子 skill 和领域子清单。
- 修正主 skill 统一审查结果模板，补充触发场景、根因、处理状态和未覆盖风险字段，并同步本地源 skill。
- 生成 7 条常规测试用例，覆盖正常、失败、异常、空值和边界、权限、重复执行、并发与幂等、回归 8 个测试维度。
- 未执行真实服务、数据库、浏览器、Windows 主机、全局安装和 GitHub 发布验证。

### 第 8 步：创建 Git 仓库并提交 GitHub

- 新增 `.gitignore`，排除系统文件、编辑器文件、本地环境变量和构建产物。
- 创建首个提交 `7ccb35a`，包含仓库 skill、清单、规则、文档和跨平台脚本。
- 将 `main` 推送到 GitHub，并建立远程分支跟踪。
- 初始 GitHub 发布时暂不创建正式版本标签；许可证当时仍待确认。

### 许可证确认

- 将根目录 `LICENSE` 的占位内容替换为 Apache License 2.0 官方文本。
- README 和执行计划同步记录许可证状态。

### 正式发布

- 创建正式版本标签 `v0.1.0`。
- 当前版本包含 8 个 skill、4 个总清单、26 个领域子清单，以及 Unix 和 Windows 安装、卸载、验证和状态脚本。
- 第 9 步全局安装、切换和旧目录清理仍待执行。
