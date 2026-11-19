#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILLS="$REPO_ROOT/skills"
SOURCE_SKILL_ROOT="$SOURCE_SKILLS/fullstack-review"
SOURCE_CHECKLISTS="$REPO_ROOT/checklists"

usage() {
  echo "用法：$0 [--target codex|claude] [业务项目目录] [全局目录]"
  echo "默认目标：codex（项目 .codex/，全局 ${CODEX_HOME:-$HOME/.codex}，规则文件 AGENTS.md）"
  echo "--target claude：项目 .claude/，全局 ${CLAUDE_CONFIG_DIR:-$HOME/.claude}，规则文件 CLAUDE.md"
}

target_tool='codex'
positional=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --target)
      [[ "$#" -ge 2 ]] || { echo "失败：--target 需要参数 codex 或 claude。" >&2; exit 2; }
      target_tool="$2"
      shift 2
      ;;
    --target=*)
      target_tool="${1#--target=}"
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
      positional+=("$1")
      shift
      ;;
  esac
done
if [[ "${#positional[@]}" -gt 2 ]]; then
  echo "失败：最多只接受 业务项目目录 和 全局目录 两个位置参数。" >&2
  usage >&2
  exit 2
fi

case "$target_tool" in
  codex)
    TARGET_DIR_NAME='.codex'
    RULES_FILE_NAME='AGENTS.md'
    default_home="${CODEX_HOME:-$HOME/.codex}"
    ;;
  claude)
    TARGET_DIR_NAME='.claude'
    RULES_FILE_NAME='CLAUDE.md'
    default_home="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    ;;
  *)
    echo "失败：--target 只支持 codex 或 claude：$target_tool" >&2
    exit 2
    ;;
esac

project_root="${positional[0]:-$PWD}"
codex_home_path="${positional[1]:-$default_home}"

TARGET_SKILLS="$codex_home_path/skills/fullstack-review"
TARGET_CHECKLISTS="$codex_home_path/checklists/fullstack-quality-kit"
GLOBAL_AGENTS="$codex_home_path/$RULES_FILE_NAME"
MANIFEST="$TARGET_CHECKLISTS/.fullstack-quality-kit.manifest"
MANIFEST_HEADER='# fullstack-quality-kit manifest v2'
PROJECT_TARGET_SKILLS="$project_root/$TARGET_DIR_NAME/skills"
PROJECT_TARGET_CHECKLISTS="$project_root/$TARGET_DIR_NAME/checklists"
PROJECT_MANIFEST="$PROJECT_TARGET_CHECKLISTS/.fullstack-quality-kit.manifest"
PROJECT_MANIFEST_HEADER='# fullstack-quality-kit project manifest v1'
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

report_project_manifest_status() {
  local line kind relative_path expected_hash extra target_file
  local consistent=0
  local modified=0
  local missing=0
  local invalid=0

  if [[ ! -f "$PROJECT_MANIFEST" ]]; then
    echo '  未发现项目安装清单；旧版项目安装需重新执行 install-project.sh 完成安全升级'
    return 0
  fi
  if [[ "$(sed -n '1p' "$PROJECT_MANIFEST")" != "$PROJECT_MANIFEST_HEADER" ]]; then
    echo '  项目安装清单：版本或格式无法识别'
    return 0
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$PROJECT_MANIFEST_HEADER" || -z "$line" || "${line#\#}" != "$line" ]] && continue
    IFS=$'\t' read -r kind relative_path expected_hash extra <<< "$line"
    if [[ -z "$kind" || -z "$relative_path" || -z "$expected_hash" || -n "$extra" || ! "$expected_hash" =~ ^[[:xdigit:]]{64}$ ]] || ! is_safe_relative_path "$relative_path"; then
      invalid=$((invalid + 1))
      continue
    fi
    case "$kind" in
      skills) target_file="$PROJECT_TARGET_SKILLS/$relative_path" ;;
      checklists) target_file="$PROJECT_TARGET_CHECKLISTS/$relative_path" ;;
      *)
        invalid=$((invalid + 1))
        continue
        ;;
    esac
    expected_hash="$(printf '%s' "$expected_hash" | tr '[:upper:]' '[:lower:]')"
    if [[ ! -e "$target_file" ]]; then
      missing=$((missing + 1))
    elif [[ ! -f "$target_file" ]]; then
      modified=$((modified + 1))
    elif [[ "$(file_sha256 "$target_file" 2>/dev/null || true)" == "$expected_hash" ]]; then
      consistent=$((consistent + 1))
    else
      modified=$((modified + 1))
    fi
  done < "$PROJECT_MANIFEST"
  echo "  项目安装清单 v1：一致 $consistent 个，已修改 $modified 个，缺失 $missing 个，格式异常 $invalid 个"
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
  report_tree "$SOURCE_SKILLS" "$PROJECT_TARGET_SKILLS"
  report_tree "$SOURCE_CHECKLISTS" "$PROJECT_TARGET_CHECKLISTS"
  report_project_manifest_status
else
  echo '  业务项目目录不存在'
fi

echo "全局安装：$codex_home_path"
report_tree "$SOURCE_SKILL_ROOT" "$TARGET_SKILLS"
report_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS"
report_manifest_status
