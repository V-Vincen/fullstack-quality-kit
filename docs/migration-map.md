# 迁移映射

## 初始迁移基线

| 源位置 | 目标位置 | 数量 | 状态 |
|---|---|---:|---|
| 原 fullstack-review 目录 | `skills/fullstack-review/` | 8 | 已迁移并完成拆分 |
| 原全局清单根目录 | `checklists/` 根目录 | 4 | 已迁移 |
| 原全局清单子目录 | `checklists/` 对应子目录 | 26 | 已迁移并完成拆分 |
| 原全局 `AGENTS.md` 联动区块 | `rules/global-agents.block.md` | 1 | 已提取 |

## 未迁移内容

- 用户完整全局 `AGENTS.md` 中的其他个人规则。
- 具体业务项目中的 `AGENTS.md`。
- 与 fullstack-quality-kit 无关的其他 skill。
- 当前全局 skills 目录中的系统文件。

## 第 4 步：路径和联动调整

- 将 skill 和总清单中的直接全局路径替换为 `CHECKLIST_ROOT`。
- 统一当前宿主项目级优先、另一宿主项目级兜底，再按相同宿主顺序回退到全局清单的解析规则。
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
| 工作流 | 3 个用户工作流，已接入主 skill；2 个维护工作流的约束已迁入 AGENTS.md |
| 总清单 | 4 个，已完成路由 |
| 领域子清单 | 27 个，已完成数据库、数据访问和用户流程验收扩展 |
| 脚本 | 已提供项目级和全局安装与安全升级、状态、验证、生命周期测试和全局卸载入口 |
| 发布 | 最新正式版本标签为 `v0.2.0`，当前源码在该版本上继续维护 |

## 待完成验收

- 在真实 `~/.claude` 完成 `--target claude` 安装，并验证 Claude Code 对主 skill、嵌套子 skill 和清单路径的加载。
- 验证 Codex 与 Claude Code 同时存在不同宿主目录时，交互式调用会按当前宿主选择清单。
