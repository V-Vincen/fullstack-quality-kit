#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

has_manifest=0
has_block=0
[[ -f "$MANIFEST" ]] && has_manifest=1
if [[ -f "$GLOBAL_AGENTS" ]] && grep -qF "$MARKER_START" "$GLOBAL_AGENTS"; then
  grep -qF "$MARKER_END" "$GLOBAL_AGENTS" || { echo "失败：全局 AGENTS.md 的管理区块不完整。" >&2; exit 1; }
  has_block=1
fi

if [[ "$has_manifest" -eq 0 && "$has_block" -eq 0 ]]; then
  echo "没有找到 fullstack-quality-kit 的全局安装记录。"
  exit 0
fi

if [[ "$yes_flag" -ne 1 ]]; then
  if [[ ! -r /dev/tty ]]; then
    echo "失败：非交互环境必须使用 --yes。" >&2
    exit 2
  fi
  printf '将卸载 %s 中由 fullstack-quality-kit 管理的内容。继续？ [y/N] ' "$codex_home_path" > /dev/tty
  read -r answer < /dev/tty
  [[ "$answer" == 'y' || "$answer" == 'Y' ]] || { echo '已取消。'; exit 0; }
fi

if [[ "$has_block" -eq 1 ]]; then
  backup_dir="$codex_home_path/backups"
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  backup_path="$backup_dir/fullstack-quality-kit--AGENTS.md--$timestamp-before-global-uninstall.bak"
  mkdir -p "$backup_dir"
  [[ ! -e "$backup_path" ]] || { echo "失败：备份文件已存在：$backup_path" >&2; exit 1; }
  cp -p "$GLOBAL_AGENTS" "$backup_path"
  echo "已备份全局规则：$backup_path"
fi

if [[ "$has_manifest" -eq 1 ]]; then
  while IFS= read -r managed_file; do
    [[ -n "$managed_file" && "${managed_file#\#}" == "$managed_file" ]] || continue
    case "$managed_file" in
      "$TARGET_SKILLS"/*|"$TARGET_CHECKLISTS"/*) ;;
      *)
        echo "失败：安装清单包含受保护范围外的路径：$managed_file" >&2
        exit 1
        ;;
    esac
  done < "$MANIFEST"
  while IFS= read -r managed_file; do
    [[ -n "$managed_file" && "${managed_file#\#}" == "$managed_file" ]] || continue
    case "$managed_file" in
      "$TARGET_SKILLS"/*|"$TARGET_CHECKLISTS"/*)
        [[ ! -e "$managed_file" ]] || rm -f -- "$managed_file"
        ;;
      *) : ;;
    esac
  done < "$MANIFEST"
  rm -f -- "$MANIFEST"
fi

if [[ "$has_block" -eq 1 ]]; then
  agents_temp="$(mktemp)"
  awk -v start="$MARKER_START" -v end="$MARKER_END" '
    $0 == start { inside=1; found_start=1; next }
    $0 == end { inside=0; found_end=1; next }
    !inside { print }
    END { if (inside || !found_start || !found_end) exit 1 }
  ' "$GLOBAL_AGENTS" > "$agents_temp"
  mv "$agents_temp" "$GLOBAL_AGENTS"
fi

remove_source_empty_dirs() {
  local source_root="$1"
  local target_root="$2"
  local source_dir relative_path target_dir
  while IFS= read -r source_dir; do
    relative_path="${source_dir#"$source_root"/}"
    if [[ "$source_dir" == "$source_root" ]]; then
      target_dir="$target_root"
    else
      target_dir="$target_root/$relative_path"
    fi
    rmdir "$target_dir" 2>/dev/null || true
  done < <(find "$source_root" -type d -print | sort -r)
}

remove_source_empty_dirs "$REPO_ROOT/.codex/skills" "$TARGET_SKILLS"
remove_source_empty_dirs "$REPO_ROOT/.codex/checklists" "$TARGET_CHECKLISTS"
echo "全局卸载完成：$codex_home_path"
