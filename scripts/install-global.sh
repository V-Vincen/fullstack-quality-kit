#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILLS="$REPO_ROOT/.codex/skills"
SOURCE_SKILL_ROOT="$SOURCE_SKILLS/fullstack-review"
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
MANIFEST_HEADER='# fullstack-quality-kit manifest v2'
MARKER_START='<!-- fullstack-quality-kit:begin -->'
MARKER_END='<!-- fullstack-quality-kit:end -->'

require_source() {
  [[ -d "$SOURCE_SKILL_ROOT" ]] || { echo "失败：缺少 fullstack-review 源 skill 目录。" >&2; exit 1; }
  [[ -d "$SOURCE_CHECKLISTS" ]] || { echo "失败：缺少源清单目录。" >&2; exit 1; }
  [[ -f "$RULE_SOURCE" ]] || { echo "失败：缺少全局规则片段。" >&2; exit 1; }
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{ print $1 }'
  else
    echo '失败：未找到 shasum 或 sha256sum，无法生成安装记录。' >&2
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
    echo '失败：未找到 shasum 或 sha256sum，无法生成安装记录。' >&2
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

source_for_managed_path() {
  local managed_file="$1"
  local relative_path
  case "$managed_file" in
    "$TARGET_SKILLS/fullstack-review"/*)
      relative_path="${managed_file#"$TARGET_SKILLS/fullstack-review"/}"
      is_safe_relative_path "$relative_path" || return 1
      printf '%s\n' "$SOURCE_SKILL_ROOT/$relative_path"
      ;;
    "$TARGET_SKILLS"/*)
      relative_path="${managed_file#"$TARGET_SKILLS"/}"
      is_safe_relative_path "$relative_path" || return 1
      printf '%s\n' "$SOURCE_SKILL_ROOT/$relative_path"
      ;;
    "$TARGET_CHECKLISTS"/*)
      relative_path="${managed_file#"$TARGET_CHECKLISTS"/}"
      is_safe_relative_path "$relative_path" || return 1
      printf '%s\n' "$SOURCE_CHECKLISTS/$relative_path"
      ;;
    *)
      return 1
      ;;
  esac
}

validate_v2_manifest() {
  local manifest_file="$1"
  local first_line line kind managed_path expected_hash extra block_count=0
  first_line="$(sed -n '1p' "$manifest_file")"
  [[ "$first_line" == "$MANIFEST_HEADER" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$MANIFEST_HEADER" || -z "$line" || "${line#\#}" != "$line" ]] && continue
    IFS=$'\t' read -r kind managed_path expected_hash extra <<< "$line"
    if [[ -z "$kind" || -z "$managed_path" || -z "$expected_hash" || -n "$extra" || ! "$expected_hash" =~ ^[[:xdigit:]]{64}$ ]]; then
      echo "失败：安装清单格式无效：$manifest_file" >&2
      return 1
    fi
    case "$kind" in
      file)
        source_for_managed_path "$managed_path" >/dev/null || {
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
          echo "失败：安装清单包含多个全局规则记录。" >&2
          return 1
        fi
        ;;
      *)
        echo "失败：安装清单包含未知记录类型：$kind" >&2
        return 1
        ;;
    esac
  done < "$manifest_file"
}

upgrade_legacy_manifest() {
  local upgraded_manifest="$1"
  local managed_file source_file current_block current_hash desired_hash
  local invalid=0
  printf '%s\n' "$MANIFEST_HEADER" > "$upgraded_manifest"

  while IFS= read -r managed_file || [[ -n "$managed_file" ]]; do
    [[ -n "$managed_file" && "${managed_file#\#}" == "$managed_file" ]] || continue
    source_file="$(source_for_managed_path "$managed_file")" || {
      echo "失败：旧版安装清单包含受保护范围外的路径：$managed_file" >&2
      invalid=1
      continue
    }
    if [[ ! -f "$managed_file" || ! -f "$source_file" ]] || ! cmp -s "$managed_file" "$source_file"; then
      echo "失败：旧版安装清单无法安全升级，文件已缺失或与当前源文件不同：$managed_file" >&2
      invalid=1
      continue
    fi
    printf 'file\t%s\t%s\n' "$managed_file" "$(file_sha256 "$managed_file")" >> "$upgraded_manifest"
  done < "$MANIFEST"

  if [[ -f "$GLOBAL_AGENTS" ]] && grep -qF "$MARKER_START" "$GLOBAL_AGENTS"; then
    current_block="$(mktemp)"
    if ! extract_managed_block "$GLOBAL_AGENTS" "$current_block"; then
      rm -f "$current_block"
      echo '失败：旧版全局规则管理区块不完整，无法安全升级。' >&2
      return 1
    fi
    current_hash="$(block_sha256 "$current_block")"
    desired_hash="$(block_sha256 "$desired_block")"
    rm -f "$current_block"
    if [[ "$current_hash" != "$desired_hash" ]]; then
      echo '失败：旧版全局规则管理区块已修改，无法安全升级。' >&2
      return 1
    fi
    printf 'agents-block\t%s\t%s\n' "$GLOBAL_AGENTS" "$current_hash" >> "$upgraded_manifest"
  fi

  if [[ "$invalid" -ne 0 ]]; then
    echo '请先恢复冲突文件，或保留现有内容并手动处理旧版安装记录。' >&2
    return 1
  fi
}

ensure_v2_manifest() {
  if [[ ! -f "$MANIFEST" ]]; then
    printf '%s\n' "$MANIFEST_HEADER" > "$MANIFEST"
  fi
  validate_v2_manifest "$MANIFEST"
}

upsert_manifest_record() {
  local kind="$1"
  local managed_path="$2"
  local content_hash="$3"
  local manifest_temp
  manifest_temp="$(mktemp)"
  awk -F '\t' -v kind="$kind" -v path="$managed_path" '
    NR == 1 { print; next }
    $1 == kind && $2 == path { next }
    { print }
  ' "$MANIFEST" > "$manifest_temp"
  printf '%s\t%s\t%s\n' "$kind" "$managed_path" "$content_hash" >> "$manifest_temp"
  mv "$manifest_temp" "$MANIFEST"
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

require_source

desired_block="$(mktemp)"
created_files="$(mktemp)"
legacy_upgrade_manifest=''
legacy_manifest_upgrade=0
trap 'rm -f "$desired_block" "$created_files" "$legacy_upgrade_manifest"' EXIT
printf '%s\n' "$MARKER_START" > "$desired_block"
cat "$RULE_SOURCE" >> "$desired_block"
if [[ -s "$RULE_SOURCE" && "$(tail -c 1 "$RULE_SOURCE" 2>/dev/null || true)" != $'\n' ]]; then
  printf '\n' >> "$desired_block"
fi
printf '%s\n' "$MARKER_END" >> "$desired_block"

if [[ -e "$MANIFEST" && ! -f "$MANIFEST" ]]; then
  echo "失败：安装清单路径不是普通文件：$MANIFEST" >&2
  exit 1
fi
if [[ -f "$MANIFEST" ]]; then
  if [[ "$(sed -n '1p' "$MANIFEST")" == "$MANIFEST_HEADER" ]]; then
    validate_v2_manifest "$MANIFEST"
  else
    legacy_upgrade_manifest="$(mktemp)"
    upgrade_legacy_manifest "$legacy_upgrade_manifest"
    legacy_manifest_upgrade=1
  fi
fi

preflight_tree "$SOURCE_SKILL_ROOT" "$TARGET_SKILLS"
preflight_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS"

agents_needs_change=0
if [[ -e "$GLOBAL_AGENTS" ]]; then
  [[ -f "$GLOBAL_AGENTS" ]] || { echo "失败：全局 AGENTS.md 不是普通文件。" >&2; exit 1; }
  if grep -qF "$MARKER_START" "$GLOBAL_AGENTS"; then
    current_block="$(mktemp)"
    if ! extract_managed_block "$GLOBAL_AGENTS" "$current_block"; then
      rm -f "$current_block"
      echo "失败：全局 AGENTS.md 的管理区块不完整。" >&2
      exit 1
    fi
    if [[ "$(block_sha256 "$desired_block")" != "$(block_sha256 "$current_block")" ]]; then
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
  if [[ ! -t 0 ]]; then
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
  local source_name="$3"
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
    printf '%s\t%s\n' "$source_name" "$relative_path" >> "$created_files"
    copied=$((copied + 1))
  done < <(find "$source_dir" -type f ! -name '.DS_Store' -print0)
  echo "已处理 ${source_dir}：新增 $copied 个，已存在且一致 $skipped 个。"
}

backup_global_agents
if [[ "$legacy_manifest_upgrade" -eq 1 ]]; then
  mv "$legacy_upgrade_manifest" "$MANIFEST"
  legacy_upgrade_manifest=''
  echo '已将旧版全局安装清单升级为 v2。'
fi
mkdir -p "$codex_home_path" "$TARGET_SKILLS" "$TARGET_CHECKLISTS"
copy_tree "$SOURCE_SKILL_ROOT" "$TARGET_SKILLS" skills
copy_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS" checklists

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

if [[ -s "$created_files" || "$agents_needs_change" -eq 1 ]]; then
  ensure_v2_manifest
  while IFS=$'\t' read -r source_name relative_path; do
    case "$source_name" in
      skills) target_file="$TARGET_SKILLS/$relative_path" ;;
      checklists) target_file="$TARGET_CHECKLISTS/$relative_path" ;;
      *)
        echo "失败：内部安装记录包含未知目录：$source_name" >&2
        exit 1
        ;;
    esac
    upsert_manifest_record file "$target_file" "$(file_sha256 "$target_file")"
  done < "$created_files"
  if [[ "$agents_needs_change" -eq 1 ]]; then
    upsert_manifest_record agents-block "$GLOBAL_AGENTS" "$(block_sha256 "$desired_block")"
  fi
fi

echo "全局安装完成：$codex_home_path"
