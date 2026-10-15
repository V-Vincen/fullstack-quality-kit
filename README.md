# fullstack-quality-kit

全栈质量审查、清单和常规测试用例生成工具集。

## 当前状态

当前正式版本为 `v0.1.4`。规则、清单和 skill 已完成迁移，路径和联动关系已统一，数据库审查与数据访问审查已拆分，Unix 和 Windows 安装、卸载、验证及状态入口已经建立；全局安装支持安全升级和按需跳过规则合并。

第 9 步正在进行：项目级安装已完成，工具调用验收、全局安装、切换和旧目录清理仍待执行。

## 目标能力

~~~text
Java
Spring Boot
数据库引擎与 SQL（MySQL、PostgreSQL、Oracle、SQL Server、SQLite 等）
数据访问层（MyBatis、JPA/Hibernate、JDBC、Mapper、Repository、ORM）
前端
安全
常规测试用例
~~~

## 目标结构

~~~text
.codex/
├── skills/fullstack-review/
└── checklists/

rules/
scripts/
docs/
├── checklist-routing.md
├── installation.md
├── migration-map.md
├── markdown-style-guide.md
└── usage.md
~~~

## 使用方式

支持两种方式：

1. 项目级安装：将本仓库内容安装到业务项目。
2. 全局安装：将主 skill 和命名空间清单安装到用户全局目录。

详细安装命令见 [安装说明](docs/installation.md)，使用方式见 [使用说明](docs/usage.md)，Markdown 排版规则见 [Markdown 排版规范](docs/markdown-style-guide.md)。

## 维护流程

仓库按以下顺序维护和验收：

~~~text
设计 → 迁移 → 验证 → 发布
~~~

## 当前限制

- 已迁移 1 个主 skill 和 7 个专业子 skill。
- 当前工作区包含 4 个总清单和 27 个领域子清单。
- 当前正式版本包含 5 个按需读取的工作流，其中包括用户流程验收工作流。
- 已提取全局规则中的联动区块。
- 已统一项目级优先、全局兜底的清单路径。
- 已补充清单路由说明。
- 已将原 mysql-review 拆分为 database-review 和 data-access-review，并同步本地源 skill。
- 已新增 macOS/Linux 的 Bash 脚本，以及 Windows 的 PowerShell 和批处理入口。
- 批处理文件只负责转发到对应的 PowerShell 脚本，不维护第二套业务逻辑。
- 全局安装生命周期已在隔离目录中完成首次安装、重复安装、状态检查、冲突保护、旧清单升级和卸载验证。
- `v0.1.4` 支持在安装清单内容未被用户修改时安全升级，并可跳过全局规则合并。
- Windows 入口尚未在真实 Windows 主机上执行闭环验证。
- 已使用临时多技术栈示例项目完成 7 类路由验证和 7 条常规测试用例生成。
- 采用 Apache License 2.0，详见 [LICENSE](LICENSE)。
