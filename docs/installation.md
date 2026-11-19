# 安装说明

当前仓库提供项目级安装和全局安装两种方式。安装前应先执行验证脚本。项目级安装不覆盖内容不同的已有文件；全局安装只会安全升级安装清单记录且未被用户修改的内容。验证数量统一由 `scripts/validation-rules.conf` 维护，新增或删除 skill、工作流或清单时应同步调整该文件。

## 验证仓库

### macOS/Linux

~~~bash
./scripts/validate.sh
~~~

## 项目级安装

将 skill 和清单安装到业务项目，不修改业务项目的 AGENTS.md：

### macOS/Linux

~~~bash
./scripts/install-project.sh /绝对路径/业务项目
~~~

## 全局安装

默认安装到 `~/.codex/`，包括：

- `~/.codex/skills/fullstack-review/`
- `~/.codex/checklists/fullstack-quality-kit/`
- 未使用跳过规则参数时，全局 `AGENTS.md` 中受标记管理的联动规则区块

`~/.codex/skills/fullstack-review/` 直接包含主 `SKILL.md`、子 skill 和工作流，不会额外嵌套一层 `fullstack-review/` 目录。

安装脚本会在清单命名空间中自动生成 `~/.codex/checklists/fullstack-quality-kit/.fullstack-quality-kit.manifest`。该文件不是独立安装目录，用于记录受管理文件及其内容哈希。

### macOS/Linux

交互式执行：

~~~bash
./scripts/install-global.sh
~~~

非交互执行必须明确使用：

~~~bash
./scripts/install-global.sh --yes
~~~

如果用户完整的全局 `AGENTS.md` 已经包含等效的 skill 与清单联动规则，可以跳过规则区块合并：

~~~bash
./scripts/install-global.sh --skip-agents
~~~

非交互安装时可以组合参数：

~~~bash
./scripts/install-global.sh --yes --skip-agents
~~~

也可以指定其他全局目录：

~~~bash
./scripts/install-global.sh --yes /绝对路径/Codex目录
~~~

### 安装到 Claude Code

安装、查看状态和卸载脚本都支持 `--target codex|claude`，不加参数时目标是 `codex`，行为与以前一致。`--target claude` 的差异如下：

- 全局目录默认是 `~/.claude/`，可用环境变量 `CLAUDE_CONFIG_DIR` 或位置参数覆盖。
- 受管理的规则区块合并进 `CLAUDE.md`，不是 `AGENTS.md`。
- 项目级安装到业务项目的 `.claude/skills/` 和 `.claude/checklists/`。

~~~bash
./scripts/install-global.sh --target claude
./scripts/install-global.sh --yes --target claude --skip-agents
./scripts/install-project.sh --target claude /绝对路径/业务项目
./scripts/status.sh --target claude /绝对路径/业务项目
./scripts/uninstall-global.sh --yes --target claude
~~~

清单路径按「当前项目 `.claude/` → 当前项目 `.codex/` → 全局 `~/.claude/` → 全局 `~/.codex/`」的顺序解析，同一台机器同时装了两个目标时，Claude Code 优先使用 `.claude/` 下的副本。

### 已有根目录清单的迁移

如果 `~/.codex/checklists/` 已经直接包含 4 个总清单和领域目录，不要把这些文件移动或复制到新的命名空间，也不要在安装后立即删除。推荐顺序如下：

1. 比较原始清单与仓库当前清单，确认是否存在本机独有内容。
2. 备份原始清单和全局 `AGENTS.md`。
3. 将全局规则中的固定清单路径改为 `CHECKLIST_ROOT`，并补充项目级优先、全局命名空间兜底的解析规则。
4. 全局规则已经具备等效联动内容时，使用 `--skip-agents` 安装 skill 和命名空间清单。
5. 验证项目级优先路径、全局兜底路径、重复安装和安装清单状态。
6. 保留原始根目录清单，完成一次安装后的真实项目审查；再次确认后才逐个清理旧副本。

原始根目录清单不会被全局安装清单记录，全局卸载脚本也不会处理它们。清理时必须保留 `~/.codex/checklists/fullstack-quality-kit/`。

脚本只合并 `rules/global-agents.block.md` 管理的规则区块，不覆盖用户完整的全局 `AGENTS.md`。`--skip-agents` 只跳过规则区块，不影响 skill 和清单安装。

全局安装会在 `~/.codex/checklists/fullstack-quality-kit/.fullstack-quality-kit.manifest` 写入安装清单 v2。清单只记录由本工具创建或安全升级的文件和规则区块，并保存内容哈希；安装前已存在且内容一致、但不属于本工具的文件不会被纳入卸载范围。

再次安装新版本时，脚本按安装清单判断内容归属：当前内容仍与清单记录一致时，可以替换为新版本并更新记录；当前内容已被用户修改、没有安装记录或无法核验时，脚本会停止并报告冲突。检测到旧版路径清单时，只有原文件和规则区块仍与当前源一致才会升级为 v2。

## 查看状态

### macOS/Linux

~~~bash
./scripts/status.sh /绝对路径/业务项目
~~~

第二个参数可以指定全局目录：

~~~bash
./scripts/status.sh /绝对路径/业务项目 /绝对路径/Codex目录
~~~

## 全局卸载

全局卸载只处理安装清单 v2 记录的文件和受标记管理的规则区块，不删除用户原有的同名文件：

### macOS/Linux

~~~bash
./scripts/uninstall-global.sh
~~~

非交互执行：

~~~bash
./scripts/uninstall-global.sh --yes
~~~

## 验证限制

- 当前只提供 macOS/Linux 的 Bash 入口，暂不支持 Windows；Windows 的 PowerShell 和批处理入口已移除。
- Bash 入口已在隔离的临时目录中验证首次安装、重复安装、状态检查和卸载；`--target claude` 尚未在真实的 `~/.claude` 上安装，也未验证 Claude Code 对嵌套子 skill 的加载行为。
