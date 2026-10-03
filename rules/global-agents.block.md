# 全局规则可复用联动区块

来源：/Users/vincent/.codex/AGENTS.md 中的 Skill 与清单联动部分。

本文件只保存可复用的联动规则，不替代用户完整的全局 AGENTS.md。

## Skill 与清单联动

- AGENTS.md 负责全局授权、范围、工具、备份、验证和交付约束；skill 不得降低或绕过这些约束。
- 触发全局清单后，先读取对应总清单，再按总清单路由读取相关领域子清单；只读取与当前任务相关的子清单。
- fullstack-review 负责识别技术领域、选择子 skill、组合领域检查和生成测试；子 skill 负责专业分析，不替代全局清单。
- 代码、配置或脚本写入时，执行 CODE_REVIEW_CHECKLIST.md 及相关代码审查子清单。
- 业务行为、接口结果或页面交互变化时，执行 BUSINESS_TEST_CHECKLIST.md 及相关业务测试子清单。
- 数据库写入或结构变更时，执行 DB_CHANGE_CHECKLIST.md 及相关数据库变更子清单。
- 用户明确要求扫描、整理或生成外部接口文档时，执行 EXTERNAL_API_DOC_CHECKLIST.md 及相关外部接口文档子清单。
- 最终交付必须报告使用的 skill、执行的总清单、执行的领域子清单、验证结果、未覆盖项和已知风险。

## 清单路径解析

- CHECKLIST_ROOT 先解析为当前项目/.codex/checklists/。
- 当前项目不存在对应清单时，再解析为 ~/.codex/checklists/fullstack-quality-kit/。
- CHECKLIST_ROOT 仅是逻辑标识，不要求设置环境变量。
- 两个位置都不存在时，必须报告清单缺失，不得回退到其他项目目录。

## 安装约束

- 安装脚本只能合并本文件管理的规则区块。
- 不得覆盖用户完整的全局 AGENTS.md。
- 安装、升级和卸载前必须确认目标路径、备份和回滚方式。
