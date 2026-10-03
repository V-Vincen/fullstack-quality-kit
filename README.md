# fullstack-quality-kit

全栈质量审查、清单和常规测试用例生成工具集。

## 当前状态

当前仓库处于第 8 步：规则、清单和 skills 已迁移，路径和联动关系已统一，数据库审查和代码审查清单已完成拆分，Unix 和 Windows 安装、卸载、验证和状态脚本已完成，静态验证、示例项目路由验证和 GitHub 推送已完成，许可证已采用 Apache License 2.0，尚未完成全局安装验证。

第 9 步全局安装、切换和旧目录清理仍待执行；正式版本标签尚未创建。

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

计划支持两种方式：

1. 项目级安装：将本仓库内容安装到业务项目。
2. 全局安装：将主 skill 和命名空间清单安装到用户全局目录。

详细安装命令见 [安装说明](docs/installation.md)，使用方式见 [使用说明](docs/usage.md)，Markdown 排版规则见 [Markdown 排版规范](docs/markdown-style-guide.md)。

## 执行计划

完整执行计划位于：

~~~text
/Users/vincent/Projects/AiCode/FULLSTACK-QUALITY-KIT-EXECUTION-PLAN.md
~~~

执行顺序：

~~~text
设计 → 迁移 → 验证 → 发布
~~~

## 当前限制

- 已迁移 1 个主 skill 和 7 个专业子 skill。
- 已迁移 4 个总清单和 26 个领域子清单。
- 已提取全局规则中的联动区块。
- 已统一项目级优先、全局兜底的清单路径。
- 已补充清单路由说明。
- 已将原 mysql-review 拆分为 database-review 和 data-access-review，并同步本地源 skill。
- 已新增 macOS/Linux 的 Bash 脚本，以及 Windows 的 PowerShell 和批处理入口。
- 批处理文件只负责转发到对应的 PowerShell 脚本，不维护第二套业务逻辑。
- Windows 入口尚未在真实 Windows 主机上执行闭环验证。
- 已使用临时多技术栈示例项目完成 7 类路由验证和 7 条常规测试用例生成。
- 采用 Apache License 2.0，详见 [LICENSE](LICENSE)。
