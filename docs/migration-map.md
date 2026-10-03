# 迁移映射

## 本次迁移

| 源位置 | 目标位置 | 数量 | 状态 |
|---|---|---:|---|
| /Users/vincent/Projects/AiCode/Codex/skills/fullstack-review/ | .codex/skills/fullstack-review/ | 8 | 已迁移并完成拆分 |
| /Users/vincent/.codex/checklists/ 根目录 | .codex/checklists/ 根目录 | 4 | 已迁移 |
| /Users/vincent/.codex/checklists/ 子目录 | .codex/checklists/ 对应子目录 | 26 | 已迁移并完成拆分 |
| /Users/vincent/.codex/AGENTS.md 的联动区块 | rules/global-agents.block.md | 1 | 已提取 |

## 未迁移内容

- /Users/vincent/.codex/AGENTS.md 的其他个人全局规则。
- 具体业务项目中的 AGENTS.md。
- /Users/vincent/.agents/skills/codex-hud-setup/。
- 当前全局 skills 目录中的系统文件。

## 第 4 步：路径和联动调整

- 将 skill 和总清单中的直接全局路径替换为 CHECKLIST_ROOT。
- 统一项目级优先、全局兜底的清单解析顺序。
- 补充主 skill 和子 skill 的清单路径说明。
- 补充仓库规则和全局规则片段的路径解析约束。
- 除原 mysql-mybatis-quality.md 外，其余 24 个领域子清单正文保持不变。
- 将原 backend/mysql-review 拆分为 backend/database-review 和 backend/data-access-review。
- 本地源 skill 与仓库内 skill 保持同步。
- 将原 code-review/mysql-mybatis-quality.md 拆分为 code-review/database-quality.md 和 code-review/data-access-quality.md。

## 后续未处理

- 未创建安装、卸载、验证和状态脚本。
- 未安装到用户全局目录。
- 未提交或推送 GitHub。

以上内容分别由第 5 步和第 9 步处理。
