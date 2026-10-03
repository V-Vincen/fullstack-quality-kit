#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILLS="$REPO_ROOT/.codex/skills"
SOURCE_CHECKLISTS="$REPO_ROOT/.codex/checklists"
RULE_SOURCE="$REPO_ROOT/rules/global-agents.block.md"

yes_flag=0
codex_home_path="${CODEX_HOME:-$HOME/.codex}"

usage() {
  echo "用法：$0 [--yes] [Codex 全局目录]"
  echo "默认目录：${CODEX_HOME:-$HOME/.codex}"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --yes)
      yes_flag=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "失败：未知参数：$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ "$codex_home_path" != "${CODEX_HOME:-$HOME/.codex}" ]]; then
        echo "失败：全局目录只能指定一次。" >&2
        exit 2
      fi
      codex_home_path="$1"
      shift
      ;;
  esac
done

TARGET_SKILLS="$codex_home_path/skills/fullstack-review"
TARGET_CHECKLISTS="$codex_home_path/checklists/fullstack-quality-kit"
GLOBAL_AGENTS="$codex_home_path/AGENTS.md"
MANIFEST="$TARGET_CHECKLISTS/.fullstack-quality-kit.manifest"
MARKER_START='<!-- fullstack-quality-kit:begin -->'
MARKER_END='<!-- fullstack-quality-kit:end -->'

require_source() {
  [[ -d "$SOURCE_SKILLS" ]] || { echo "失败：缺少源 skill 目录。" >&2; exit 1; }
  [[ -d "$SOURCE_CHECKLISTS" ]] || { echo "失败：缺少源清单目录。" >&2; exit 1; }
  [[ -f "$RULE_SOURCE" ]] || { echo "失败：缺少全局规则片段。" >&2; exit 1; }
}

preflight_tree() {
  local source_dir="$1"
  local target_dir="$2"
  local source_file relative_path target_file
  while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$source_dir"/}"
    target_file="$target_dir/$relative_path"
    if [[ -e "$target_file" ]]; then
      if [[ ! -f "$target_file" ]] || ! cmp -s "$source_file" "$target_file"; then
        echo "冲突：目标文件已存在且内容不同：$target_file" >&2
        return 1
      fi
    fi
  done < <(find "$source_dir" -type f ! -name '.DS_Store' -print0)
}

desired_block="$(mktemp)"
created_files="$(mktemp)"
trap 'rm -f "$desired_block" "$created_files"' EXIT
printf '%s\n' "$MARKER_START" > "$desired_block"
cat "$RULE_SOURCE" >> "$desired_block"
printf '%s\n' "$MARKER_END" >> "$desired_block"

require_source
preflight_tree "$SOURCE_SKILLS" "$TARGET_SKILLS"
preflight_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS"

if [[ -e "$MANIFEST" && ! -f "$MANIFEST" ]]; then
  echo "失败：安装清单路径不是普通文件：$MANIFEST" >&2
  exit 1
fi

agents_needs_change=0
if [[ -e "$GLOBAL_AGENTS" ]]; then
  [[ -f "$GLOBAL_AGENTS" ]] || { echo "失败：全局 AGENTS.md 不是普通文件。" >&2; exit 1; }
  if grep -qF "$MARKER_START" "$GLOBAL_AGENTS"; then
    grep -qF "$MARKER_END" "$GLOBAL_AGENTS" || { echo "失败：全局 AGENTS.md 的管理区块不完整。" >&2; exit 1; }
    current_block="$(mktemp)"
    awk -v start="$MARKER_START" -v end="$MARKER_END" '
      $0 == start { inside=1 }
      inside { print }
      $0 == end { inside=0 }
    ' "$GLOBAL_AGENTS" > "$current_block"
    if ! cmp -s "$desired_block" "$current_block"; then
      rm -f "$current_block"
      echo "冲突：全局 AGENTS.md 已有不同的 fullstack-quality-kit 管理区块。" >&2
      exit 1
    fi
    rm -f "$current_block"
  else
    [[ -w "$GLOBAL_AGENTS" ]] || { echo "失败：无法写入全局 AGENTS.md。" >&2; exit 1; }
    agents_needs_change=1
  fi
else
  agents_needs_change=1
fi

if [[ "$yes_flag" -ne 1 ]]; then
  if [[ ! -r /dev/tty ]]; then
    echo "失败：非交互环境必须使用 --yes。" >&2
    exit 2
  fi
  printf '将安装到 %s，并可能更新 %s。继续？ [y/N] ' "$codex_home_path" "$GLOBAL_AGENTS" > /dev/tty
  read -r answer < /dev/tty
  [[ "$answer" == 'y' || "$answer" == 'Y' ]] || { echo '已取消。'; exit 0; }
fi

backup_global_agents() {
  [[ "$agents_needs_change" -eq 1 && -f "$GLOBAL_AGENTS" ]] || return 0
  backup_dir="$codex_home_path/backups"
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  backup_path="$backup_dir/fullstack-quality-kit--AGENTS.md--$timestamp-before-global-install.bak"
  mkdir -p "$backup_dir"
  [[ ! -e "$backup_path" ]] || { echo "失败：备份文件已存在：$backup_path" >&2; exit 1; }
  cp -p "$GLOBAL_AGENTS" "$backup_path"
  echo "已备份全局规则：$backup_path"
}

copy_tree() {
  local source_dir="$1"
  local target_dir="$2"
  local source_file relative_path target_file
  local copied=0
  local skipped=0
  while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$source_dir"/}"
    target_file="$target_dir/$relative_path"
    if [[ -e "$target_file" ]]; then
      skipped=$((skipped + 1))
      continue
    fi
    mkdir -p "$(dirname "$target_file")"
    cp -p "$source_file" "$target_file"
    printf '%s\n' "$target_file" >> "$created_files"
    copied=$((copied + 1))
  done < <(find "$source_dir" -type f ! -name '.DS_Store' -print0)
  echo "已处理 ${source_dir}：新增 $copied 个，已存在且一致 $skipped 个。"
}

backup_global_agents
mkdir -p "$codex_home_path" "$TARGET_SKILLS" "$TARGET_CHECKLISTS"
copy_tree "$SOURCE_SKILLS" "$TARGET_SKILLS"
copy_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS"

if [[ "$agents_needs_change" -eq 1 ]]; then
  if [[ -f "$GLOBAL_AGENTS" ]]; then
    agents_temp="$(mktemp)"
    cp -p "$GLOBAL_AGENTS" "$agents_temp"
    printf '\n' >> "$agents_temp"
    cat "$desired_block" >> "$agents_temp"
    mv "$agents_temp" "$GLOBAL_AGENTS"
  else
    cp -p "$desired_block" "$GLOBAL_AGENTS"
  fi
fi

if [[ -s "$created_files" ]]; then
  if [[ ! -f "$MANIFEST" ]]; then
    printf '# fullstack-quality-kit installed files\n' > "$MANIFEST"
  fi
  while IFS= read -r created_file; do
    grep -Fxq "$created_file" "$MANIFEST" || printf '%s\n' "$created_file" >> "$MANIFEST"
  done < "$created_files"
fi

echo "全局安装完成：$codex_home_path"
