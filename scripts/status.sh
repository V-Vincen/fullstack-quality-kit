#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_SKILLS="$REPO_ROOT/.codex/skills"
SOURCE_CHECKLISTS="$REPO_ROOT/.codex/checklists"

project_root="${1:-$PWD}"
codex_home_path="${2:-${CODEX_HOME:-$HOME/.codex}}"

if [[ "$project_root" == '-h' || "$project_root" == '--help' ]]; then
  echo "用法：$0 [业务项目目录] [Codex 全局目录]"
  exit 0
fi

count_files() {
  find "$1" -type f -name "$2" 2>/dev/null | wc -l | tr -d ' '
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
    echo "  已安装且一致：$target_dir"
  else
    echo "  状态异常：${target_dir}；缺失 $missing 个，冲突 $conflict 个"
  fi
}

echo "fullstack-quality-kit 状态"
echo "仓库：$REPO_ROOT"
echo "源 skill：$(count_files "$SOURCE_SKILLS" 'SKILL.md') 个"
echo "源清单：$(count_files "$SOURCE_CHECKLISTS" '*.md') 个"
echo "项目级安装：$project_root"
if [[ -d "$project_root" ]]; then
  report_tree "$SOURCE_SKILLS" "$project_root/.codex/skills"
  report_tree "$SOURCE_CHECKLISTS" "$project_root/.codex/checklists"
else
  echo "  业务项目目录不存在"
fi

echo "全局安装：$codex_home_path"
report_tree "$SOURCE_SKILLS" "$codex_home_path/skills/fullstack-review"
report_tree "$SOURCE_CHECKLISTS" "$codex_home_path/checklists/fullstack-quality-kit"
if [[ -f "$codex_home_path/checklists/fullstack-quality-kit/.fullstack-quality-kit.manifest" ]]; then
  echo "  存在全局安装清单"
else
  echo "  未发现全局安装清单"
fi
if [[ -f "$codex_home_path/AGENTS.md" ]] && grep -qF '<!-- fullstack-quality-kit:begin -->' "$codex_home_path/AGENTS.md"; then
  echo "  已合并全局规则管理区块"
else
  echo "  未合并全局规则管理区块"
fi
