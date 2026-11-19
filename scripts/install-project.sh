#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILLS="$REPO_ROOT/skills"
SOURCE_CHECKLISTS="$REPO_ROOT/checklists"
LEGACY_MANIFEST_V015="$SCRIPT_DIR/project-legacy-v0.1.5.manifest"
LEGACY_MANIFEST_V020="$SCRIPT_DIR/project-legacy-v0.2.0.manifest"
MANIFEST_HEADER='# fullstack-quality-kit project manifest v1'
LEGACY_MANIFEST_HEADER_V015='# fullstack-quality-kit legacy project manifest v0.1.5'
LEGACY_MANIFEST_HEADER_V020='# fullstack-quality-kit legacy project manifest v0.2.0'

usage() {
  echo "用法：$0 [--target codex|claude] <业务项目目录>"
  echo "默认目标：codex，安装到 <业务项目目录>/.codex/；claude 安装到 <业务项目目录>/.claude/"
}

target_tool='codex'
PROJECT_ROOT=''
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
      if [[ -n "$PROJECT_ROOT" ]]; then
        echo "失败：业务项目目录只能指定一次。" >&2
        exit 2
      fi
      PROJECT_ROOT="$1"
      shift
      ;;
  esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
  usage >&2
  exit 2
fi
case "$target_tool" in
  codex) TARGET_DIR_NAME='.codex' ;;
  claude) TARGET_DIR_NAME='.claude' ;;
  *)
    echo "失败：--target 只支持 codex 或 claude：$target_tool" >&2
    exit 2
    ;;
esac
if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "失败：业务项目目录不存在：$PROJECT_ROOT" >&2
  exit 1
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"

TARGET_SKILLS="$PROJECT_ROOT/$TARGET_DIR_NAME/skills"
TARGET_CHECKLISTS="$PROJECT_ROOT/$TARGET_DIR_NAME/checklists"
MANIFEST="$TARGET_CHECKLISTS/.fullstack-quality-kit.manifest"

file_sha256() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$file" | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$file" | awk '{ print $1 }'
  else
    echo '失败：未找到 shasum 或 sha256sum，无法生成项目安装记录。' >&2
    return 1
  fi
}

is_safe_relative_path() {
  local relative_path="$1"
  case "$relative_path" in
    ''|/*|.|..|../*|*/..|*/../*|*'//'*) return 1 ;;
  esac
  [[ "$relative_path" != *$'\t'* && "$relative_path" != *$'\n'* ]]
}

ensure_target_path_safe() {
  local target_path="$1"
  local current="$target_path"
  while [[ "$current" != "$PROJECT_ROOT" && "$current" == "$PROJECT_ROOT"/* ]]; do
    if [[ -L "$current" ]]; then
      echo "冲突：项目安装目标包含符号链接：$current" >&2
      return 1
    fi
    current="$(dirname "$current")"
  done
  [[ "$current" == "$PROJECT_ROOT" ]] || {
    echo "失败：项目安装目标超出业务项目目录：$target_path" >&2
    return 1
  }
}

target_for_record() {
  local kind="$1"
  local relative_path="$2"
  is_safe_relative_path "$relative_path" || return 1
  case "$kind" in
    skills) printf '%s\n' "$TARGET_SKILLS/$relative_path" ;;
    checklists) printf '%s\n' "$TARGET_CHECKLISTS/$relative_path" ;;
    *) return 1 ;;
  esac
}

source_for_record() {
  local kind="$1"
  local relative_path="$2"
  is_safe_relative_path "$relative_path" || return 1
  case "$kind" in
    skills) printf '%s\n' "$SOURCE_SKILLS/$relative_path" ;;
    checklists) printf '%s\n' "$SOURCE_CHECKLISTS/$relative_path" ;;
    *) return 1 ;;
  esac
}

validate_manifest() {
  local manifest_file="$1"
  local expected_header="$2"
  local line kind relative_path expected_hash extra
  [[ -f "$manifest_file" ]] || { echo "失败：缺少安装清单：$manifest_file" >&2; return 1; }
  [[ "$(sed -n '1p' "$manifest_file")" == "$expected_header" ]] || {
    echo "失败：安装清单版本无效：$manifest_file" >&2
    return 1
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$expected_header" || -z "$line" || "${line#\#}" != "$line" ]] && continue
    IFS=$'\t' read -r kind relative_path expected_hash extra <<< "$line"
    if [[ -z "$kind" || -z "$relative_path" || -z "$expected_hash" || -n "$extra" || ! "$expected_hash" =~ ^[[:xdigit:]]{64}$ ]]; then
      echo "失败：安装清单格式无效：$manifest_file" >&2
      return 1
    fi
    target_for_record "$kind" "$relative_path" >/dev/null || {
      echo "失败：安装清单包含受保护范围外的路径：$kind/$relative_path" >&2
      return 1
    }
  done < "$manifest_file"
}

manifest_record_hash() {
  local manifest_file="$1"
  local kind="$2"
  local relative_path="$3"
  awk -F '\t' -v kind="$kind" -v relative_path="$relative_path" '
    $1 == kind && $2 == relative_path {
      print tolower($3)
      found=1
      exit
    }
    END { if (!found) exit 1 }
  ' "$manifest_file"
}

ensure_target_path_safe "$MANIFEST"
active_manifests=()
active_manifest_headers=()
if [[ -e "$MANIFEST" ]]; then
  [[ -f "$MANIFEST" ]] || { echo "失败：项目安装清单路径不是普通文件：$MANIFEST" >&2; exit 1; }
  active_manifests+=("$MANIFEST")
  active_manifest_headers+=("$MANIFEST_HEADER")
else
  active_manifests+=("$LEGACY_MANIFEST_V015" "$LEGACY_MANIFEST_V020")
  active_manifest_headers+=("$LEGACY_MANIFEST_HEADER_V015" "$LEGACY_MANIFEST_HEADER_V020")
fi
validate_manifest "$LEGACY_MANIFEST_V015" "$LEGACY_MANIFEST_HEADER_V015"
validate_manifest "$LEGACY_MANIFEST_V020" "$LEGACY_MANIFEST_HEADER_V020"
if [[ "${active_manifests[0]}" == "$MANIFEST" ]]; then
  validate_manifest "$MANIFEST" "$MANIFEST_HEADER"
fi

is_recorded_hash() {
  local kind="$1"
  local relative_path="$2"
  local current_hash="$3"
  local manifest_file recorded_hash
  for manifest_file in "${active_manifests[@]}"; do
    recorded_hash="$(manifest_record_hash "$manifest_file" "$kind" "$relative_path" 2>/dev/null || true)"
    if [[ -n "$recorded_hash" && "$current_hash" == "$recorded_hash" ]]; then
      return 0
    fi
  done
  return 1
}

preflight_tree() {
  local source_dir="$1"
  local target_dir="$2"
  local kind="$3"
  local source_file relative_path target_file current_hash
  while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$source_dir"/}"
    target_file="$target_dir/$relative_path"
    ensure_target_path_safe "$target_file" || return 1
    if [[ -e "$target_file" ]]; then
      if [[ ! -f "$target_file" ]]; then
        echo "冲突：目标路径不是普通文件：$target_file" >&2
        return 1
      fi
      if cmp -s "$source_file" "$target_file"; then
        continue
      fi
      current_hash="$(file_sha256 "$target_file")"
      if ! is_recorded_hash "$kind" "$relative_path" "$current_hash"; then
        echo "冲突：目标文件已存在且不属于可安全升级的受管版本：$target_file" >&2
        return 1
      fi
    fi
  done < <(find "$source_dir" -type f ! -name '.DS_Store' -print0)
}

preflight_stale_files() {
  local manifest_file="$1"
  local manifest_header="$2"
  local line kind relative_path expected_hash source_file target_file current_hash
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$manifest_header" || -z "$line" || "${line#\#}" != "$line" ]] && continue
    IFS=$'\t' read -r kind relative_path expected_hash <<< "$line"
    source_file="$(source_for_record "$kind" "$relative_path")"
    target_file="$(target_for_record "$kind" "$relative_path")"
    ensure_target_path_safe "$target_file" || return 1
    if [[ ! -e "$source_file" && -e "$target_file" ]]; then
      if [[ ! -f "$target_file" ]]; then
        echo "冲突：源中已删除的受管路径不是普通文件：$target_file" >&2
        return 1
      fi
      current_hash="$(file_sha256 "$target_file")"
      if [[ "$current_hash" != "$(printf '%s' "$expected_hash" | tr '[:upper:]' '[:lower:]')" ]]; then
        echo "冲突：源中已删除的受管文件已被用户修改：$target_file" >&2
        return 1
      fi
    fi
  done < "$manifest_file"
}

copy_tree() {
  local source_dir="$1"
  local target_dir="$2"
  local kind="$3"
  local source_file relative_path target_file current_hash
  local copied=0
  local updated=0
  local skipped=0
  while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$source_dir"/}"
    target_file="$target_dir/$relative_path"
    ensure_target_path_safe "$target_file" || exit 1
    if [[ -e "$target_file" ]]; then
      if [[ ! -f "$target_file" ]]; then
        echo "失败：目标路径在预检后变为非普通文件：$target_file" >&2
        exit 1
      fi
      if cmp -s "$source_file" "$target_file"; then
        skipped=$((skipped + 1))
      else
        current_hash="$(file_sha256 "$target_file")"
        if ! is_recorded_hash "$kind" "$relative_path" "$current_hash"; then
          echo "失败：目标文件在预检后发生变化：$target_file" >&2
          exit 1
        fi
        cp -p "$source_file" "$target_file"
        updated=$((updated + 1))
      fi
      continue
    fi
    mkdir -p "$(dirname "$target_file")"
    cp -p "$source_file" "$target_file"
    copied=$((copied + 1))
  done < <(find "$source_dir" -type f ! -name '.DS_Store' -print0)
  echo "已处理 ${source_dir}：新增 $copied 个，安全升级 $updated 个，已存在且一致 $skipped 个。"
}

prune_stale_files() {
  local manifest_file="$1"
  local manifest_header="$2"
  local line kind relative_path expected_hash source_file target_file root dir
  local pruned=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$manifest_header" || -z "$line" || "${line#\#}" != "$line" ]] && continue
    IFS=$'\t' read -r kind relative_path expected_hash <<< "$line"
    source_file="$(source_for_record "$kind" "$relative_path")"
    target_file="$(target_for_record "$kind" "$relative_path")"
    ensure_target_path_safe "$target_file" || exit 1
    if [[ ! -e "$source_file" && -f "$target_file" ]]; then
      if [[ "$(file_sha256 "$target_file")" != "$(printf '%s' "$expected_hash" | tr '[:upper:]' '[:lower:]')" ]]; then
        echo "失败：源中已删除的受管文件在预检后发生变化：$target_file" >&2
        exit 1
      fi
      rm -f -- "$target_file"
      pruned=$((pruned + 1))
      case "$kind" in
        skills) root="$TARGET_SKILLS" ;;
        checklists) root="$TARGET_CHECKLISTS" ;;
      esac
      dir="$(dirname "$target_file")"
      while [[ "$dir" == "$root"/* ]]; do
        rmdir "$dir" 2>/dev/null || break
        dir="$(dirname "$dir")"
      done
    fi
  done < "$manifest_file"
  if [[ "$pruned" -gt 0 ]]; then
    echo "已清理源中删除且未被用户修改的项目级受管文件：$pruned 个。"
  fi
}

ensure_target_path_safe "$TARGET_SKILLS"
ensure_target_path_safe "$TARGET_CHECKLISTS"
preflight_tree "$SOURCE_SKILLS" "$TARGET_SKILLS" skills
preflight_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS" checklists
for index in "${!active_manifests[@]}"; do
  preflight_stale_files "${active_manifests[$index]}" "${active_manifest_headers[$index]}"
done

mkdir -p "$TARGET_SKILLS" "$TARGET_CHECKLISTS"
copy_tree "$SOURCE_SKILLS" "$TARGET_SKILLS" skills
copy_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS" checklists
for index in "${!active_manifests[@]}"; do
  prune_stale_files "${active_manifests[$index]}" "${active_manifest_headers[$index]}"
done

manifest_temp="$(mktemp)"
trap 'rm -f "$manifest_temp"' EXIT
printf '%s\n' "$MANIFEST_HEADER" > "$manifest_temp"
while IFS= read -r source_file; do
  relative_path="${source_file#"$SOURCE_SKILLS"/}"
  printf 'skills\t%s\t%s\n' "$relative_path" "$(file_sha256 "$TARGET_SKILLS/$relative_path")" >> "$manifest_temp"
done < <(find "$SOURCE_SKILLS" -type f ! -name '.DS_Store' -print | LC_ALL=C sort)
while IFS= read -r source_file; do
  relative_path="${source_file#"$SOURCE_CHECKLISTS"/}"
  printf 'checklists\t%s\t%s\n' "$relative_path" "$(file_sha256 "$TARGET_CHECKLISTS/$relative_path")" >> "$manifest_temp"
done < <(find "$SOURCE_CHECKLISTS" -type f ! -name '.DS_Store' -print | LC_ALL=C sort)
mv "$manifest_temp" "$MANIFEST"
manifest_temp=''

echo "项目级安装完成：$PROJECT_ROOT"
