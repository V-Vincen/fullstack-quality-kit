#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILLS="$REPO_ROOT/.codex/skills"
SOURCE_SKILL_ROOT="$SOURCE_SKILLS/fullstack-review"
SOURCE_CHECKLISTS="$REPO_ROOT/.codex/checklists"

project_root="${1:-$PWD}"
codex_home_path="${2:-${CODEX_HOME:-$HOME/.codex}}"

if [[ "$project_root" == '-h' || "$project_root" == '--help' ]]; then
  echo "用法：$0 [业务项目目录] [Codex 全局目录]"
  exit 0
fi

TARGET_SKILLS="$codex_home_path/skills/fullstack-review"
TARGET_CHECKLISTS="$codex_home_path/checklists/fullstack-quality-kit"
GLOBAL_AGENTS="$codex_home_path/AGENTS.md"
MANIFEST="$TARGET_CHECKLISTS/.fullstack-quality-kit.manifest"
MANIFEST_HEADER='# fullstack-quality-kit manifest v2'
MARKER_START='<!-- fullstack-quality-kit:begin -->'
MARKER_END='<!-- fullstack-quality-kit:end -->'

count_files() {
  find "$1" -type f -name "$2" 2>/dev/null | wc -l | tr -d ' '
}

file_sha256() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$file" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$file" | awk '{ print $1 }'
  else
    return 1
  fi
}

block_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    awk '{ sub(/\r$/, ""); print }' "$1" | shasum -a 256 | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    awk '{ sub(/\r$/, ""); print }' "$1" | sha256sum | awk '{ print $1 }'
  else
    return 1
  fi
}

extract_managed_block() {
  local source_file="$1"
  local output_file="$2"
  awk -v start="$MARKER_START" -v end="$MARKER_END" '
    { sub(/\r$/, "") }
    $0 == start {
      start_count++
      if (inside || start_count > 1) invalid=1
      inside=1
    }
    inside { print }
    $0 == end {
      if (!inside || end_count > 0) invalid=1
      end_count++
      inside=0
    }
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

report_tree() {
  local source_dir="$1"
  local target_dir="$2"
  local source_file relative_path target_file
  local missing=0
  local conflict=0
  if [[ ! -d "$target_dir" ]]; then
    echo "  未安装：$target_dir"
    return 0
  fi
  while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$source_dir"/}"
    target_file="$target_dir/$relative_path"
    if [[ ! -f "$target_file" ]]; then
      missing=$((missing + 1))
    elif ! cmp -s "$source_file" "$target_file"; then
      conflict=$((conflict + 1))
    fi
  done < <(find "$source_dir" -type f ! -name '.DS_Store' -print0)
  if [[ "$missing" -eq 0 && "$conflict" -eq 0 ]]; then
    echo "  已安装且与当前源一致：$target_dir"
  else
    echo "  与当前源存在差异：${target_dir}；缺失 $missing 个，差异 $conflict 个"
  fi
}

report_manifest_status() {
  local line kind managed_path expected_hash extra current_block
  local consistent=0
  local modified=0
  local missing=0
  local invalid=0
  local block_record_seen=0

  if [[ ! -f "$MANIFEST" ]]; then
    echo '  未发现全局安装清单'
    return 0
  fi
  if [[ "$(sed -n '1p' "$MANIFEST")" != "$MANIFEST_HEADER" ]]; then
    echo '  全局安装清单：旧版，无法验证内容是否被修改'
    return 0
  fi

  current_block="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$MANIFEST_HEADER" || -z "$line" || "${line#\#}" != "$line" ]] && continue
    IFS=$'\t' read -r kind managed_path expected_hash extra <<< "$line"
    if [[ -z "$kind" || -z "$managed_path" || -z "$expected_hash" || -n "$extra" || ! "$expected_hash" =~ ^[[:xdigit:]]{64}$ ]]; then
      invalid=$((invalid + 1))
      continue
    fi
    expected_hash="$(printf '%s' "$expected_hash" | tr '[:upper:]' '[:lower:]')"
    case "$kind" in
      file)
        if ! is_managed_file_path "$managed_path"; then
          invalid=$((invalid + 1))
        elif [[ ! -e "$managed_path" ]]; then
          missing=$((missing + 1))
        elif [[ ! -f "$managed_path" ]]; then
          modified=$((modified + 1))
        elif [[ "$(file_sha256 "$managed_path" 2>/dev/null || true)" == "$expected_hash" ]]; then
          consistent=$((consistent + 1))
        else
          modified=$((modified + 1))
        fi
        ;;
      agents-block)
        block_record_seen=1
        if [[ "$managed_path" != "$GLOBAL_AGENTS" ]]; then
          invalid=$((invalid + 1))
        elif [[ ! -f "$GLOBAL_AGENTS" ]] || ! grep -qF "$MARKER_START" "$GLOBAL_AGENTS"; then
          missing=$((missing + 1))
        elif ! extract_managed_block "$GLOBAL_AGENTS" "$current_block"; then
          modified=$((modified + 1))
        elif [[ "$(block_sha256 "$current_block" 2>/dev/null || true)" == "$expected_hash" ]]; then
          consistent=$((consistent + 1))
        else
          modified=$((modified + 1))
        fi
        ;;
      *)
        invalid=$((invalid + 1))
        ;;
    esac
  done < "$MANIFEST"
  rm -f "$current_block"

  echo "  全局安装清单 v2：一致 $consistent 个，已修改 $modified 个，缺失 $missing 个，格式异常 $invalid 个"
  if [[ -f "$GLOBAL_AGENTS" ]] && grep -qF "$MARKER_START" "$GLOBAL_AGENTS"; then
    if [[ "$block_record_seen" -eq 1 ]]; then
      echo '  全局规则管理区块：已纳入安装清单'
    else
      echo '  全局规则管理区块：存在但未纳入安装清单'
    fi
  else
    echo '  未合并全局规则管理区块'
  fi
}

echo 'fullstack-quality-kit 状态'
echo "仓库：$REPO_ROOT"
echo "源 skill：$(count_files "$SOURCE_SKILL_ROOT" 'SKILL.md') 个"
echo "源清单：$(count_files "$SOURCE_CHECKLISTS" '*.md') 个"
echo "项目级安装：$project_root"
if [[ -d "$project_root" ]]; then
  report_tree "$SOURCE_SKILLS" "$project_root/.codex/skills"
  report_tree "$SOURCE_CHECKLISTS" "$project_root/.codex/checklists"
else
  echo '  业务项目目录不存在'
fi

echo "全局安装：$codex_home_path"
report_tree "$SOURCE_SKILL_ROOT" "$TARGET_SKILLS"
report_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS"
report_manifest_status
