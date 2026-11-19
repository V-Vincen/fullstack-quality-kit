#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILLS="$REPO_ROOT/skills"
SOURCE_CHECKLISTS="$REPO_ROOT/checklists"

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

TARGET_SKILLS="$PROJECT_ROOT/$TARGET_DIR_NAME/skills"
TARGET_CHECKLISTS="$PROJECT_ROOT/$TARGET_DIR_NAME/checklists"

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
