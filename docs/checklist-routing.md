# 清单路由说明

## 路径解析

CHECKLIST_ROOT 是清单根目录的逻辑标识，不是需要设置的环境变量。

解析顺序固定为：

~~~text
当前项目/.codex/checklists/
    ↓ 当前项目不存在对应文件时
~/.codex/checklists/fullstack-quality-kit/
    ↓ 两个位置都不存在时
报告清单缺失
~~~

不得回退到其他项目目录，也不得读取没有被当前任务触发的领域清单。

## 触发链路

~~~text
任务变更
    ↓
全局 AGENTS.md 授权和触发规则
    ↓
总清单
    ↓
领域子清单
    ↓
fullstack-review
    ↓
专业子 skill
~~~

## 总清单映射

| 触发条件 | 总清单 | 领域子清单目录 |
|---|---|---|
| 代码、配置或脚本写入 | CODE_REVIEW_CHECKLIST.md | code-review/ |
| 业务行为、接口结果或页面交互变化 | BUSINESS_TEST_CHECKLIST.md | business-test/ |
| 数据库写入或结构变更 | DB_CHANGE_CHECKLIST.md | db-change/ |
| 用户明确要求整理外部接口文档 | EXTERNAL_API_DOC_CHECKLIST.md | external-api-doc/ |

## 使用约束

- 总清单负责共同门禁，领域子清单负责专项检查。
- 子 skill 不替代总清单，也不绕过用户授权、备份和验证。
- 只读取当前任务实际涉及的总清单和领域子清单。
- 两个路径都找不到清单时，必须报告缺失，不得假设检查已完成。
