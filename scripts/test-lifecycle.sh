#!/usr/bin/env bash
# 安装生命周期测试：在隔离的临时目录中验证 --target codex|claude 的全局安装、重复安装、
# 状态、项目级安装和卸载。不读写真实的 ~/.codex、~/.claude 和任何业务项目。
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out.txt"
pass_count=0
fail_count=0

check() {
  local desc="$1"
  shift
  if "$@" >"$OUT" 2>&1; then
    echo "通过：$desc"
    pass_count=$((pass_count + 1))
  else
    echo "失败：$desc"
    sed 's/^/    /' "$OUT" | head -8
    fail_count=$((fail_count + 1))
  fi
}

# 期望命令以非零状态结束，用于验证非法参数被拒绝。
check_rejected() {
  local desc="$1"
  shift
  if "$@" >"$OUT" 2>&1; then
    echo "失败：$desc（应被拒绝，实际退出码为 0）"
    fail_count=$((fail_count + 1))
  else
    echo "通过：$desc"
    pass_count=$((pass_count + 1))
  fi
}

# 去掉文件末尾的空行后再比较。安装追加规则区块前会补一个空行，卸载只移除区块，
# 所以卸载后文件末尾会多一个空行；这是既有行为，不属于本测试要拦截的问题。
strip_trailing_blank() {
  awk '{ a[NR] = $0 } END { n = NR; while (n > 0 && a[n] == "") n--; for (i = 1; i <= n; i++) print a[i] }' "$1"
}
same_ignoring_trailing_blank() {
  diff <(strip_trailing_blank "$1") <(strip_trailing_blank "$2")
}

installed_matches_source() {
  local home="$1"
  diff -r "$REPO_ROOT/skills/fullstack-review" "$home/skills/fullstack-review" -x .DS_Store &&
    diff -r "$REPO_ROOT/checklists" "$home/checklists/fullstack-quality-kit" -x .DS_Store -x .fullstack-quality-kit.manifest
}

# ---------- claude 目标 ----------
CH="$TMP/claude-home"
CP="$TMP/claude-proj"
mkdir -p "$CH" "$CP"
printf '# 我的全局规则\n\n- 保留这一行\n' > "$CH/CLAUDE.md"
cp "$CH/CLAUDE.md" "$TMP/CLAUDE.orig"

check "claude 全局安装" "$SCRIPT_DIR/install-global.sh" --yes --target claude "$CH"
check "CLAUDE.md 写入管理区块" grep -q 'fullstack-quality-kit:begin' "$CH/CLAUDE.md"
check "用户原有内容保留" grep -q '保留这一行' "$CH/CLAUDE.md"
check "没有生成 AGENTS.md" test ! -e "$CH/AGENTS.md"
check "安装内容与仓库源一致" installed_matches_source "$CH"
check "备份文件名带 CLAUDE.md" bash -c "ls '$CH/backups' | grep -q -- '--CLAUDE.md--'"
check "重复安装保持幂等" "$SCRIPT_DIR/install-global.sh" --yes --target claude "$CH"
check "status 显示安装清单一致" bash -c "'$SCRIPT_DIR/status.sh' --target claude '$CP' '$CH' | grep -q '一致 [1-9]'"
check "claude 项目级安装" "$SCRIPT_DIR/install-project.sh" --target claude "$CP"
check "项目级装在 .claude/ 且没有 .codex/" test -f "$CP/.claude/skills/fullstack-review/SKILL.md" -a ! -e "$CP/.codex"
check "claude 卸载" "$SCRIPT_DIR/uninstall-global.sh" --yes --target claude "$CH"
check "卸载后 CLAUDE.md 与原文一致（忽略末尾空行）" same_ignoring_trailing_blank "$TMP/CLAUDE.orig" "$CH/CLAUDE.md"
check "卸载后清单文件已移除" test ! -e "$CH/checklists/fullstack-quality-kit/CODE_REVIEW_CHECKLIST.md"

# ---------- codex 目标（默认目标） ----------
XH="$TMP/codex-home"
XP="$TMP/codex-proj"
mkdir -p "$XH" "$XP"
check "codex 全局安装（默认目标）" "$SCRIPT_DIR/install-global.sh" --yes "$XH"
check "codex 写入 AGENTS.md 且不生成 CLAUDE.md" test -f "$XH/AGENTS.md" -a ! -e "$XH/CLAUDE.md"
check "codex 安装内容与仓库源一致" installed_matches_source "$XH"
check "codex 项目级安装（默认目标）" "$SCRIPT_DIR/install-project.sh" "$XP"
check "项目级装在 .codex/ 且没有 .claude/" test -f "$XP/.codex/skills/fullstack-review/SKILL.md" -a ! -e "$XP/.claude"

# ---------- 升级时清理源中已删除的受管文件 ----------
SH="$TMP/stale-home"
mkdir -p "$SH"
"$SCRIPT_DIR/install-global.sh" --yes --skip-agents --target claude "$SH" >/dev/null 2>&1
SM="$SH/checklists/fullstack-quality-kit/.fullstack-quality-kit.manifest"
# 构造两个"源中已不存在"的受管文件：一个未改动，一个安装后被用户改过。
mkdir -p "$SH/skills/fullstack-review/old-skill"
printf 'stale\n' > "$SH/skills/fullstack-review/old-skill/SKILL.md"
printf 'stale-user\n' > "$SH/skills/fullstack-review/old-skill/NOTES.md"
h1="$(shasum -a 256 "$SH/skills/fullstack-review/old-skill/SKILL.md" | awk '{print $1}')"
h2="$(shasum -a 256 "$SH/skills/fullstack-review/old-skill/NOTES.md" | awk '{print $1}')"
printf 'file\t%s\t%s\nfile\t%s\t%s\n' \
  "$SH/skills/fullstack-review/old-skill/SKILL.md" "$h1" \
  "$SH/skills/fullstack-review/old-skill/NOTES.md" "$h2" >> "$SM"
printf 'user edit\n' >> "$SH/skills/fullstack-review/old-skill/NOTES.md"
check "升级安装成功" "$SCRIPT_DIR/install-global.sh" --yes --skip-agents --target claude "$SH"
check "未改动的过期文件被移除" test ! -e "$SH/skills/fullstack-review/old-skill/SKILL.md"
check "被用户修改的过期文件保留" test -f "$SH/skills/fullstack-review/old-skill/NOTES.md"
check "已移除文件的清单记录同步删除" bash -c "! grep -q 'old-skill/SKILL.md' '$SM' && grep -q 'old-skill/NOTES.md' '$SM'"
check "清单表头保持完整" bash -c "[[ \"\$(sed -n 1p '$SM')\" == '# fullstack-quality-kit manifest v2' ]]"
rm -f "$SH/skills/fullstack-review/old-skill/NOTES.md"
check "卸载后不残留空目录" bash -c "'$SCRIPT_DIR/uninstall-global.sh' --yes --target claude '$SH' && test -z \"\$(find '$SH/skills' '$SH/checklists' -mindepth 1 2>/dev/null)\""

# ---------- 非法参数 ----------
check_rejected "install-global 拒绝非法 --target" "$SCRIPT_DIR/install-global.sh" --yes --target bogus "$TMP/x"
check_rejected "install-project 拒绝非法 --target" "$SCRIPT_DIR/install-project.sh" --target bogus "$XP"
check_rejected "status 拒绝非法 --target" "$SCRIPT_DIR/status.sh" --target bogus "$XP" "$XH"
check_rejected "uninstall-global 拒绝非法 --target" "$SCRIPT_DIR/uninstall-global.sh" --yes --target bogus "$XH"

echo "生命周期测试：通过 $pass_count 项，失败 $fail_count 项。"
[[ "$fail_count" -eq 0 ]]
