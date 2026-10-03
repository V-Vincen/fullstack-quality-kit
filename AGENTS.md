# fullstack-quality-kit 仓库维护规则

## 快速索引

- .codex/skills/：项目级 skill ¹。
- .codex/checklists/：项目级清单 ²。
- rules/：可合并到用户全局规则的规则片段。
- scripts/：安装、验证、升级和回滚脚本。
- docs/：仓库结构、安装方式、使用说明和 Markdown 排版规范。

## 仓库目标

本仓库用于统一维护全栈代码审查、常规测试用例生成、安全审查和相关清单。

## 源文件职责

- .codex/skills/ 是项目级 skill 的唯一维护入口。
- .codex/checklists/ 是项目级清单的唯一维护入口。
- rules/global-agents.block.md 只保存可复用的全局规则管理区块。
- 不把个人完整的全局 AGENTS.md 复制进本仓库。
- 不把具体业务项目的 AGENTS.md、配置、账号或数据复制进本仓库。

## 清单路径解析

- CHECKLIST_ROOT 先解析为当前项目/.codex/checklists/。
- 当前项目不存在对应清单时，再解析为 ~/.codex/checklists/fullstack-quality-kit/。
- CHECKLIST_ROOT 仅是逻辑标识，不要求设置环境变量。
- 两个位置都不存在时，必须报告清单缺失，不得回退到其他项目目录。

## 修改规则

- 修改 skill、清单或脚本前，先确认修改范围、影响和回滚方式。
- 修改完成后，必须执行与修改范围匹配的验证。
- skill、清单和脚本之间的引用必须真实存在。
- 修改 Markdown 文档时，遵循 docs/markdown-style-guide.md；排版调整不得改变规则含义和执行行为。
- 不得通过 skill 绕过用户授权、备份、安全和验证要求。
- 不得在没有明确授权的情况下推送 GitHub、安装全局文件或删除旧文件。

## 版本和交付

- 每个阶段完成后更新 CHANGELOG.md。
- 每次发布前检查敏感信息、临时文件和个人路径。
- README.md 必须与当前安装方式和目录结构一致。
- 未完成验证前，不标记为可发布版本。

## 术语注解

skill¹：Codex 可调用的专业能力说明目录。

清单²：触发某类任务后必须执行的检查项集合。
