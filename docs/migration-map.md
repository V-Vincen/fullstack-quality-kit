# 迁移映射

## 初始迁移基线

| 源位置 | 目标位置 | 数量 | 状态 |
|---|---|---:|---|
| 原 fullstack-review 目录 | `.codex/skills/fullstack-review/` | 8 | 已迁移并完成拆分 |
| 原全局清单根目录 | `.codex/checklists/` 根目录 | 4 | 已迁移 |
| 原全局清单子目录 | `.codex/checklists/` 对应子目录 | 26 | 已迁移并完成拆分 |
| 原全局 `AGENTS.md` 联动区块 | `rules/global-agents.block.md` | 1 | 已提取 |

## 未迁移内容

- 用户完整全局 `AGENTS.md` 中的其他个人规则。
- 具体业务项目中的 `AGENTS.md`。
- 与 fullstack-quality-kit 无关的其他 skill。
- 当前全局 skills 目录中的系统文件。

## 第 4 步：路径和联动调整

- 将 skill 和总清单中的直接全局路径替换为 `CHECKLIST_ROOT`。
- 统一项目级优先、全局兜底的清单解析顺序。
- 补充主 skill 和子 skill 的清单路径说明。
- 补充仓库规则和全局规则片段的路径解析约束。
- 除原 `mysql-mybatis-quality.md` 外，其余 24 个领域子清单正文保持不变。
- 将原 `backend/mysql-review` 拆分为 `backend/database-review` 和 `backend/data-access-review`。
- 本地源 skill 与仓库内 skill 保持同步。
- 将原 `code-review/mysql-mybatis-quality.md` 拆分为 `code-review/database-quality.md` 和 `code-review/data-access-quality.md`。

## 当前状态

| 项目 | 当前状态 |
|---|---|
| skill | 8 个，已完成迁移和路由 |
| 工作流 | 5 个，已接入主 skill |
| 总清单 | 4 个，已完成路由 |
| 领域子清单 | 27 个，已完成数据库、数据访问和用户流程验收扩展 |
| 脚本 | 已提供项目级安装、全局安装与安全升级、状态、验证和全局卸载入口 |
| 发布 | 最新正式版本为 `v0.1.4` |

## 待完成验收

- 在真实用户全局目录完成安装、切换和旧目录清理。
- 在真实 Windows 主机完成 PowerShell 与批处理入口闭环验证。
- 完成 fullstack-quality-kit 在实际业务项目中的最终工具调用验收。
