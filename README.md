# fullstack-quality-kit

全栈质量审查、清单和常规测试用例生成工具集。

## 当前状态

最新正式版本标签为 `v0.2.0`，当前源码基于该版本继续维护。规则、清单和 skill 已完成 Codex 与 Claude Code 双宿主适配；项目级和全局安装均具备受管文件记录、安全升级及用户修改保护，路径解析会优先使用当前宿主的目录。

初始建设的 9 个计划步骤已全部完成；历史过程见 [历史执行计划](docs/execution-plan.md)。当前维护重点是双宿主真实交互验收和版本兼容回归。

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
skills/fullstack-review/
checklists/
rules/
scripts/
docs/
├── checklist-routing.md
├── execution-plan.md
├── installation.md
├── migration-map.md
├── markdown-style-guide.md
└── usage.md
~~~

## 使用方式

支持两种方式：

1. 项目级安装：将本仓库内容安装到业务项目。
2. 全局安装：将主 skill 和命名空间清单安装到用户全局目录。

历史建设与验收记录见 [历史执行计划](docs/execution-plan.md)，详细安装命令见 [安装说明](docs/installation.md)，使用方式见 [使用说明](docs/usage.md)，Markdown 排版规则见 [Markdown 排版规范](docs/markdown-style-guide.md)。

## 维护流程

仓库按以下顺序维护和验收：

~~~text
设计 → 迁移 → 验证 → 发布
~~~

## 不适用范围

本工具集未覆盖以下领域：

- **DevOps、基础设施代码（IaC）**：不审查 Dockerfile、Kubernetes 配置、Terraform、Ansible 等基础设施即代码。
- **文档和注释质量**：仅通过代码建议改进，不覆盖技术文档、API 文档、代码注释的完整性和准确性评审。
- **页面 UI/UX 设计**：仅检查可用性和浏览器兼容，不评审视觉设计、设计规范、设计系统的遵循情况。
- **网络层配置和跨域问题**：不审查网络拓扑、防火墙规则、DNS 配置、CDN 策略和跨域相关的基础设施问题。
- **数据科学和 ML 相关逻辑**：不审查算法正确性、模型训练、数据预处理和机器学习流程。
- **本地化和国际化（i18n）**：仅涉及代码集成方式，不评审翻译内容、国际化规范和多语言支持的完整性。

## 当前限制

- 已迁移 1 个主 skill 和 7 个专业子 skill。
- 当前工作区包含 4 个总清单和 27 个领域子清单。
- 当前正式版本包含 3 个用户路由工作流（需求澄清、用户流程验收、可视化）；维护规则（设计上下文、TDD 验证）已迁移到 AGENTS.md。
- 已提取全局规则中的联动区块。
- 已统一“当前宿主项目级优先、另一宿主项目级兜底、当前宿主全局优先、另一宿主全局兜底”的清单路径。
- 已补充清单路由说明。
- 已将原 mysql-review 拆分为 database-review 和 data-access-review，并同步本地源 skill。
- 已提供 macOS/Linux 的 Bash 脚本；安装、状态和卸载脚本支持 `--target codex|claude`，默认目标为 codex。
- 项目级和全局安装生命周期已在隔离目录中完成首次安装、重复安装、状态检查、冲突保护、旧版升级和卸载验证。
- 全局安装延续 `v0.1.4` 引入的安全升级能力；项目级安装支持未修改的 `v0.1.5` 和 `v0.2.0` 内容升级，并为后续版本生成项目安装清单。
- 原始根目录 30 个清单已在备份后移至可恢复的废纸篓目录；全局命名空间清单保持完整，重复安装不会重建旧目录。
- 暂不支持 Windows，PowerShell 和批处理入口已移除。
- `--target claude` 已在隔离的临时目录中验证安装、状态和卸载，尚未在真实的 `~/.claude` 上安装，也未验证 Claude Code 对嵌套子 skill 的加载行为。
- 已使用临时多技术栈示例项目完成 7 类路由验证和 7 条常规测试用例生成。
- 采用 Apache License 2.0，详见 [LICENSE](LICENSE)。
