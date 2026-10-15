#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILLS="$REPO_ROOT/.codex/skills"
SOURCE_SKILL_ROOT="$SOURCE_SKILLS/fullstack-review"
SOURCE_CHECKLISTS="$REPO_ROOT/.codex/checklists"

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
MANIFEST_HEADER='# fullstack-quality-kit manifest v2'
MARKER_START='<!-- fullstack-quality-kit:begin -->'
MARKER_END='<!-- fullstack-quality-kit:end -->'

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{ print $1 }'
  else
    echo '失败：未找到 shasum 或 sha256sum，无法校验安装记录。' >&2
    return 1
  fi
}

file_sha256() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$file" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$file" | awk '{ print $1 }'
  else
    echo '失败：未找到 shasum 或 sha256sum，无法校验安装记录。' >&2
    return 1
  fi
}

block_sha256() {
  awk '{ sub(/\r$/, ""); print }' "$1" | sha256_stdin
}

extract_managed_block() {
  local source_file="$1"
  local output_file="$2"
  awk -v start="$MARKER_START" -v end="$MARKER_END" '
    { comparable=$0; sub(/\r$/, "", comparable) }
    comparable == start {
      start_count++
      if (inside || start_count > 1) invalid=1
      inside=1
    }
    inside { print comparable }
    comparable == end {
      if (!inside || end_count > 0) invalid=1
      end_count++
      inside=0
    }
    END {
      if (invalid || inside || start_count != 1 || end_count != 1) exit 1
    }
  ' "$source_file" > "$output_file"
}

remove_managed_block() {
  local source_file="$1"
  local output_file="$2"
  awk -v start="$MARKER_START" -v end="$MARKER_END" '
    { comparable=$0; sub(/\r$/, "", comparable) }
    comparable == start {
      start_count++
      if (inside || start_count > 1) invalid=1
      inside=1
      next
    }
    comparable == end {
      if (!inside || end_count > 0) invalid=1
      end_count++
      inside=0
      next
    }
    !inside { print }
    END {
      if (invalid || inside || start_count != 1 || end_count != 1) exit 1
    }
  ' "$source_file" > "$output_file"
}

is_safe_relative_path() {
  local relative_path="$1"
  case "$relative_path" in
    ''|/*|.|..|../*|*/..|*/../*|*'//'*) return 1 ;;
  esac
  [[ "$relative_path" != *$'\t'* && "$relative_path" != *$'\n'* ]]
}

is_managed_file_path() {
  local managed_file="$1"
  local relative_path
  case "$managed_file" in
    "$TARGET_SKILLS"/*)
      relative_path="${managed_file#"$TARGET_SKILLS"/}"
      is_safe_relative_path "$relative_path"
      ;;
    "$TARGET_CHECKLISTS"/*)
      relative_path="${managed_file#"$TARGET_CHECKLISTS"/}"
      is_safe_relative_path "$relative_path"
      ;;
    *)
      return 1
      ;;
  esac
}

validate_v2_manifest() {
  local line kind managed_path expected_hash extra block_count=0
  [[ "$(sed -n '1p' "$MANIFEST")" == "$MANIFEST_HEADER" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$MANIFEST_HEADER" || -z "$line" || "${line#\#}" != "$line" ]] && continue
    IFS=$'\t' read -r kind managed_path expected_hash extra <<< "$line"
    if [[ -z "$kind" || -z "$managed_path" || -z "$expected_hash" || -n "$extra" || ! "$expected_hash" =~ ^[[:xdigit:]]{64}$ ]]; then
      echo "失败：安装清单格式无效：$MANIFEST" >&2
      return 1
    fi
    case "$kind" in
      file)
        is_managed_file_path "$managed_path" || {
          echo "失败：安装清单包含受保护范围外的路径：$managed_path" >&2
          return 1
        }
        ;;
      agents-block)
        if [[ "$managed_path" != "$GLOBAL_AGENTS" ]]; then
          echo "失败：安装清单包含无效的全局规则路径：$managed_path" >&2
          return 1
        fi
        block_count=$((block_count + 1))
        if [[ "$block_count" -gt 1 ]]; then
          echo '失败：安装清单包含多个全局规则记录。' >&2
          return 1
        fi
        ;;
      *)
        echo "失败：安装清单包含未知记录类型：$kind" >&2
        return 1
        ;;
    esac
  done < "$MANIFEST"
}

backup_global_agents() {
  backup_dir="$codex_home_path/backups"
  timestamp="$(date '+%Y%m%d-%H%M%S')"
  backup_path="$backup_dir/fullstack-quality-kit--AGENTS.md--$timestamp-before-global-uninstall.bak"
  mkdir -p "$backup_dir"
  [[ ! -e "$backup_path" ]] || { echo "失败：备份文件已存在：$backup_path" >&2; exit 1; }
  cp -p "$GLOBAL_AGENTS" "$backup_path"
  echo "已备份全局规则：$backup_path"
}

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

has_manifest=0
has_marker=0
[[ -e "$MANIFEST" && ! -f "$MANIFEST" ]] && {
  echo "失败：安装清单路径不是普通文件：$MANIFEST" >&2
  exit 1
}
[[ -f "$MANIFEST" ]] && has_manifest=1
if [[ -f "$GLOBAL_AGENTS" ]] && grep -qF "$MARKER_START" "$GLOBAL_AGENTS"; then
  has_marker=1
fi

if [[ "$has_manifest" -eq 0 && "$has_marker" -eq 0 ]]; then
  echo '没有找到 fullstack-quality-kit 的全局安装记录。'
  exit 0
fi
if [[ "$has_manifest" -eq 0 ]]; then
  echo '失败：检测到未验证的旧版全局规则管理区块；为保护用户内容，未执行卸载。' >&2
  exit 1
fi
if [[ "$(sed -n '1p' "$MANIFEST")" != "$MANIFEST_HEADER" ]]; then
  echo '失败：检测到旧版安装清单；请先重新执行 install-global 升级清单，再执行卸载。' >&2
  exit 1
fi
validate_v2_manifest

records_to_keep="$(mktemp)"
files_to_remove="$(mktemp)"
current_block="$(mktemp)"
trap 'rm -f "$records_to_keep" "$files_to_remove" "$current_block"' EXIT
removed_count=0
retained_count=0
missing_count=0
remove_block=0
block_record_seen=0

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == "$MANIFEST_HEADER" || -z "$line" || "${line#\#}" != "$line" ]] && continue
  IFS=$'\t' read -r kind managed_path expected_hash <<< "$line"
  expected_hash="$(printf '%s' "$expected_hash" | tr '[:upper:]' '[:lower:]')"
  case "$kind" in
    file)
      if [[ ! -e "$managed_path" ]]; then
        missing_count=$((missing_count + 1))
      elif [[ ! -f "$managed_path" ]]; then
        printf '%s\n' "$line" >> "$records_to_keep"
        retained_count=$((retained_count + 1))
      elif [[ "$(file_sha256 "$managed_path")" == "$expected_hash" ]]; then
        printf '%s\n' "$managed_path" >> "$files_to_remove"
        removed_count=$((removed_count + 1))
      else
        printf '%s\n' "$line" >> "$records_to_keep"
        retained_count=$((retained_count + 1))
      fi
      ;;
    agents-block)
      block_record_seen=1
      if [[ ! -f "$GLOBAL_AGENTS" ]] || ! grep -qF "$MARKER_START" "$GLOBAL_AGENTS"; then
        missing_count=$((missing_count + 1))
      elif ! extract_managed_block "$GLOBAL_AGENTS" "$current_block"; then
        echo '失败：全局 AGENTS.md 的管理区块不完整，未执行卸载。' >&2
        exit 1
      elif [[ "$(block_sha256 "$current_block")" == "$expected_hash" ]]; then
        remove_block=1
        removed_count=$((removed_count + 1))
      else
        printf '%s\n' "$line" >> "$records_to_keep"
        retained_count=$((retained_count + 1))
      fi
      ;;
  esac
done < "$MANIFEST"

if [[ "$yes_flag" -ne 1 ]]; then
  if [[ ! -t 0 ]]; then
    echo '失败：非交互环境必须使用 --yes。' >&2
    exit 2
  fi
  printf '将卸载 %s 中由 fullstack-quality-kit 管理的内容。继续？ [y/N] ' "$codex_home_path" > /dev/tty
  read -r answer < /dev/tty
  [[ "$answer" == 'y' || "$answer" == 'Y' ]] || { echo '已取消。'; exit 0; }
fi

if [[ "$remove_block" -eq 1 ]]; then
  backup_global_agents
fi

while IFS= read -r managed_file || [[ -n "$managed_file" ]]; do
  [[ -n "$managed_file" ]] || continue
  rm -f -- "$managed_file"
done < "$files_to_remove"

if [[ "$remove_block" -eq 1 ]]; then
  agents_temp="$(mktemp)"
  remove_managed_block "$GLOBAL_AGENTS" "$agents_temp" || {
    rm -f "$agents_temp"
    echo '失败：全局 AGENTS.md 的管理区块不完整，未完成卸载。' >&2
    exit 1
  }
  mv "$agents_temp" "$GLOBAL_AGENTS"
fi

if [[ -s "$records_to_keep" ]]; then
  manifest_temp="$(mktemp)"
  printf '%s\n' "$MANIFEST_HEADER" > "$manifest_temp"
  cat "$records_to_keep" >> "$manifest_temp"
  mv "$manifest_temp" "$MANIFEST"
else
  rm -f -- "$MANIFEST"
fi

remove_source_empty_dirs "$SOURCE_SKILL_ROOT" "$TARGET_SKILLS"
remove_source_empty_dirs "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS"
if [[ "$has_marker" -eq 1 && "$block_record_seen" -eq 0 ]]; then
  echo '提示：发现未纳入 v2 安装清单的全局规则管理区块，已保留。' >&2
fi
echo "全局卸载完成：${codex_home_path}；已移除 $removed_count 个，保留已修改 $retained_count 个，缺失 $missing_count 个。"
if [[ "$retained_count" -ne 0 ]]; then
  echo '提示：存在已修改内容，卸载未完全完成；对应记录已保留。' >&2
  exit 1
fi
