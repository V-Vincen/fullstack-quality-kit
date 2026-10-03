#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILLS="$REPO_ROOT/.codex/skills"
SOURCE_CHECKLISTS="$REPO_ROOT/.codex/checklists"

usage() {
  echo "用法：$0 <业务项目目录>"
}

if [[ "$#" -ne 1 || "$1" == '-h' || "$1" == '--help' ]]; then
  usage
  [[ "$#" -eq 1 ]] && exit 0
  exit 2
fi

PROJECT_ROOT="$1"
if [[ ! -d "$PROJECT_ROOT" ]]; then
  echo "失败：业务项目目录不存在：$PROJECT_ROOT" >&2
  exit 1
fi

TARGET_SKILLS="$PROJECT_ROOT/.codex/skills"
TARGET_CHECKLISTS="$PROJECT_ROOT/.codex/checklists"

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
    copied=$((copied + 1))
  done < <(find "$source_dir" -type f ! -name '.DS_Store' -print0)
  echo "已处理 ${source_dir}：新增 $copied 个，已存在且一致 $skipped 个。"
}

preflight_tree "$SOURCE_SKILLS" "$TARGET_SKILLS"
preflight_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS"

mkdir -p "$TARGET_SKILLS" "$TARGET_CHECKLISTS"
copy_tree "$SOURCE_SKILLS" "$TARGET_SKILLS"
copy_tree "$SOURCE_CHECKLISTS" "$TARGET_CHECKLISTS"
echo "项目级安装完成：$PROJECT_ROOT"
