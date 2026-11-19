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

check_output_contains() {
  local desc="$1"
  local expected="$2"
  shift 2
  if "$@" >"$OUT" 2>&1 && grep -qF "$expected" "$OUT"; then
    echo "通过：$desc"
    pass_count=$((pass_count + 1))
  else
    echo "失败：$desc"
    sed 's/^/    /' "$OUT" | head -8
    fail_count=$((fail_count + 1))
  fi
}

file_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$1" | awk '{print $1}'
  else
    sha256sum -- "$1" | awk '{print $1}'
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
check "claude 项目安装清单已生成" grep -qF '# fullstack-quality-kit project manifest v1' "$CP/.claude/checklists/.fullstack-quality-kit.manifest"
check "claude 项目级重复安装保持幂等" "$SCRIPT_DIR/install-project.sh" --target claude "$CP"
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
check "codex 项目安装清单已生成" grep -qF '# fullstack-quality-kit project manifest v1' "$XP/.codex/checklists/.fullstack-quality-kit.manifest"
check "status 显示项目安装清单一致" bash -c "'$SCRIPT_DIR/status.sh' '$XP' '$XH' | grep -q '项目安装清单 v1：一致 [1-9]'"
printf '\n用户修改\n' >> "$XP/.codex/skills/fullstack-review/SKILL.md"
check_rejected "项目安装清单保护用户后续修改" "$SCRIPT_DIR/install-project.sh" "$XP"
check_output_contains "status 识别项目文件已修改" '已修改 1 个' "$SCRIPT_DIR/status.sh" "$XP" "$XH"

# ---------- v0.1.5 项目级安全升级 ----------
LP="$TMP/legacy-project"
mkdir -p "$LP"
git -C "$REPO_ROOT" archive --format=tar v0.1.5 .codex/skills .codex/checklists | tar -xf - -C "$LP"
check "v0.1.5 项目级安装安全升级" "$SCRIPT_DIR/install-project.sh" "$LP"
check "旧 security-review 已替换为 appsec-review" test -f "$LP/.codex/skills/fullstack-review/appsec-review/SKILL.md" -a ! -e "$LP/.codex/skills/fullstack-review/security-review"
check "已删除的维护工作流已清理" test ! -e "$LP/.codex/skills/fullstack-review/workflows/design-context.md" -a ! -e "$LP/.codex/skills/fullstack-review/workflows/tdd-verification.md"
check "升级后项目安装清单已生成" grep -qF '# fullstack-quality-kit project manifest v1' "$LP/.codex/checklists/.fullstack-quality-kit.manifest"

L20_SOURCE="$TMP/v0.2.0-source"
L20_PROJECT="$TMP/v0.2.0-project"
mkdir -p "$L20_SOURCE" "$L20_PROJECT/.codex"
git -C "$REPO_ROOT" archive --format=tar v0.2.0 skills checklists | tar -xf - -C "$L20_SOURCE"
cp -R "$L20_SOURCE/skills" "$L20_PROJECT/.codex/skills"
cp -R "$L20_SOURCE/checklists" "$L20_PROJECT/.codex/checklists"
check "v0.2.0 项目级安装安全升级" "$SCRIPT_DIR/install-project.sh" "$L20_PROJECT"
check "v0.2.0 升级后与当前源一致" bash -c "diff -r '$REPO_ROOT/skills' '$L20_PROJECT/.codex/skills' -x .DS_Store && diff -r '$REPO_ROOT/checklists' '$L20_PROJECT/.codex/checklists' -x .DS_Store -x .fullstack-quality-kit.manifest"

LPM="$TMP/legacy-project-modified"
mkdir -p "$LPM"
git -C "$REPO_ROOT" archive --format=tar v0.1.5 .codex/skills .codex/checklists | tar -xf - -C "$LPM"
printf '\n用户修改\n' >> "$LPM/.codex/skills/fullstack-review/SKILL.md"
check_rejected "v0.1.5 用户修改阻止项目升级" "$SCRIPT_DIR/install-project.sh" "$LPM"
check "升级冲突发生在写入前" test ! -e "$LPM/.codex/skills/fullstack-review/appsec-review"

MP="$TMP/malicious-project-manifest"
mkdir -p "$MP"
"$SCRIPT_DIR/install-project.sh" "$MP" >/dev/null 2>&1
printf '# fullstack-quality-kit project manifest v1\nskills\t../../outside.txt\t%s\n' '0000000000000000000000000000000000000000000000000000000000000000' > "$MP/.codex/checklists/.fullstack-quality-kit.manifest"
check_rejected "项目安装拒绝越界清单路径" "$SCRIPT_DIR/install-project.sh" "$MP"
check "越界清单未写入项目外部" test ! -e "$MP/outside.txt"

SP="$TMP/symlink-project"
SO="$TMP/symlink-outside"
mkdir -p "$SP" "$SO"
ln -s "$SO" "$SP/.codex"
check_rejected "项目安装拒绝符号链接目标目录" "$SCRIPT_DIR/install-project.sh" "$SP"
check "符号链接外部目录未被写入" test -z "$(find "$SO" -mindepth 1 -print -quit)"

# ---------- 升级时清理源中已删除的受管文件 ----------
SH="$TMP/stale-home"
mkdir -p "$SH"
"$SCRIPT_DIR/install-global.sh" --yes --skip-agents --target claude "$SH" >/dev/null 2>&1
SM="$SH/checklists/fullstack-quality-kit/.fullstack-quality-kit.manifest"
# 构造两个"源中已不存在"的受管文件：一个未改动，一个安装后被用户改过。
mkdir -p "$SH/skills/fullstack-review/old-skill"
printf 'stale\n' > "$SH/skills/fullstack-review/old-skill/SKILL.md"
printf 'stale-user\n' > "$SH/skills/fullstack-review/old-skill/NOTES.md"
h1="$(file_sha256 "$SH/skills/fullstack-review/old-skill/SKILL.md")"
h2="$(file_sha256 "$SH/skills/fullstack-review/old-skill/NOTES.md")"
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
check_rejected "install-project 拒绝缺失项目目录" "$SCRIPT_DIR/install-project.sh"

# ---------- 验证脚本负向场景 ----------
VR="$TMP/validate-routing"
mkdir -p "$VR"
tar --exclude .git -cf - -C "$REPO_ROOT" . | tar -xf - -C "$VR"
perl -0pi -e 's{code-review/java-quality\.md}{code-review/not-found-quality.md}' "$VR/skills/fullstack-review/backend/java-review/SKILL.md"
check_rejected "validate 拒绝不存在的清单路由" "$VR/scripts/validate.sh"

VT="$TMP/validate-total-checklist"
mkdir -p "$VT"
tar --exclude .git -cf - -C "$REPO_ROOT" . | tar -xf - -C "$VT"
perl -0pi -e 's{code-review/java-quality\.md}{code-review/not-found-quality.md}' "$VT/checklists/CODE_REVIEW_CHECKLIST.md"
check_rejected "validate 拒绝总清单中的错误领域路由" "$VT/scripts/validate.sh"

VW="$TMP/validate-workflow"
mkdir -p "$VW"
tar --exclude .git -cf - -C "$REPO_ROOT" . | tar -xf - -C "$VW"
mv "$VW/skills/fullstack-review/workflows/visualization.md" "$VW/skills/fullstack-review/workflows/visualization.missing"
check_rejected "validate 拒绝缺失的工作流文件" "$VW/scripts/validate.sh"

VS="$TMP/validate-subskill"
mkdir -p "$VS"
tar --exclude .git -cf - -C "$REPO_ROOT" . | tar -xf - -C "$VS"
perl -0pi -e 's{appsec-review/SKILL\.md}{appsec-missing/SKILL.md}' "$VS/skills/fullstack-review/SKILL.md"
check_rejected "validate 拒绝错误的专业子 skill 路由" "$VS/scripts/validate.sh"

VC="$TMP/validate-conflict"
mkdir -p "$VC"
tar --exclude .git -cf - -C "$REPO_ROOT" . | tar -xf - -C "$VC"
mkdir -p "$VC/.claude/checklists" "$VC/.codex/checklists"
printf '# 测试\n' > "$VC/.claude/checklists/CODE_REVIEW_CHECKLIST.md"
printf '# 测试\n' > "$VC/.codex/checklists/CODE_REVIEW_CHECKLIST.md"
check_output_contains "validate 识别多个清单候选目录" '检测到多个清单候选目录' "$VC/scripts/validate.sh"

VG="$TMP/validate-shallow-git"
mkdir -p "$VG"
tar --exclude .git -cf - -C "$REPO_ROOT" . | tar -xf - -C "$VG"
git -C "$VG" init -q
check_output_contains "validate 在缺少历史标签的浅仓库中降级验证" '未包含 v0.1.5 标签' "$VG/scripts/validate.sh"

echo "生命周期测试：通过 $pass_count 项，失败 $fail_count 项。"
[[ "$fail_count" -eq 0 ]]
