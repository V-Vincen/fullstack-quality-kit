#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_ROOT="$REPO_ROOT/.codex/skills/fullstack-review"
WORKFLOW_ROOT="$SKILL_ROOT/workflows"
CHECKLIST_ROOT="$REPO_ROOT/.codex/checklists"
RULES_FILE="$SCRIPT_DIR/validation-rules.conf"
GLOBAL_RULE_BLOCK="$REPO_ROOT/rules/global-agents.block.md"

error_count=0

fail() {
  echo "失败：$*" >&2
  error_count=$((error_count + 1))
}

require_file() {
  if [[ ! -f "$1" ]]; then
    fail "缺少文件：$1"
  fi
}

load_validation_rules() {
  local line key value
  expected_skill_count=""
  expected_workflow_count=""
  expected_root_checklist_count=""
  expected_domain_checklist_count=""

  if [[ ! -f "$RULES_FILE" ]]; then
    fail "缺少文件：$RULES_FILE"
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "${line#\#}" != "$line" ]] && continue
    if [[ ! "$line" =~ ^([A-Z_]+)=([1-9][0-9]*)$ ]]; then
      fail "验证规则格式无效：$line"
      continue
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    case "$key" in
      EXPECTED_SKILL_COUNT)
        if [[ -n "$expected_skill_count" ]]; then
          fail "验证规则重复：$key"
        else
          expected_skill_count="$value"
        fi
        ;;
      EXPECTED_WORKFLOW_COUNT)
        if [[ -n "$expected_workflow_count" ]]; then
          fail "验证规则重复：$key"
        else
          expected_workflow_count="$value"
        fi
        ;;
      EXPECTED_ROOT_CHECKLIST_COUNT)
        if [[ -n "$expected_root_checklist_count" ]]; then
          fail "验证规则重复：$key"
        else
          expected_root_checklist_count="$value"
        fi
        ;;
      EXPECTED_DOMAIN_CHECKLIST_COUNT)
        if [[ -n "$expected_domain_checklist_count" ]]; then
          fail "验证规则重复：$key"
        else
          expected_domain_checklist_count="$value"
        fi
        ;;
      *)
        fail "验证规则包含未知项：$key"
        ;;
    esac
  done < "$RULES_FILE"

  [[ -n "$expected_skill_count" ]] || fail '验证规则缺少：EXPECTED_SKILL_COUNT'
  [[ -n "$expected_workflow_count" ]] || fail '验证规则缺少：EXPECTED_WORKFLOW_COUNT'
  [[ -n "$expected_root_checklist_count" ]] || fail '验证规则缺少：EXPECTED_ROOT_CHECKLIST_COUNT'
  [[ -n "$expected_domain_checklist_count" ]] || fail '验证规则缺少：EXPECTED_DOMAIN_CHECKLIST_COUNT'
}

require_file "$REPO_ROOT/AGENTS.md"
require_file "$REPO_ROOT/README.md"
require_file "$SKILL_ROOT/SKILL.md"
require_file "$RULES_FILE"
require_file "$GLOBAL_RULE_BLOCK"

for document_file in \
  checklist-routing.md \
  installation.md \
  markdown-style-guide.md \
  migration-map.md \
  usage.md; do
  require_file "$REPO_ROOT/docs/$document_file"
done

load_validation_rules

for workflow_name in \
  preflight-grill.md \
  design-context.md \
  tdd-verification.md \
  visualization.md \
  user-journey-acceptance.md; do
  require_file "$WORKFLOW_ROOT/$workflow_name"
  if ! grep -qF "workflows/$workflow_name" "$SKILL_ROOT/SKILL.md"; then
    fail "主 skill 未引用工作流：workflows/$workflow_name"
  fi
done

workflow_count="$(find "$WORKFLOW_ROOT" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
[[ "$workflow_count" -eq "$expected_workflow_count" ]] || fail "工作流数量应为 ${expected_workflow_count}，实际为 ${workflow_count}"

require_file "$CHECKLIST_ROOT/CODE_REVIEW_CHECKLIST.md"
require_file "$CHECKLIST_ROOT/BUSINESS_TEST_CHECKLIST.md"
require_file "$CHECKLIST_ROOT/DB_CHANGE_CHECKLIST.md"
require_file "$CHECKLIST_ROOT/EXTERNAL_API_DOC_CHECKLIST.md"

skill_files=()
while IFS= read -r skill_file; do
  skill_files+=("$skill_file")
done < <(find "$SKILL_ROOT" -type f -name 'SKILL.md' -print | sort)

if [[ "${#skill_files[@]}" -ne "$expected_skill_count" ]]; then
  fail "skill 数量应为 ${expected_skill_count}，实际为 ${#skill_files[@]}"
fi

skill_names_file="$(mktemp)"
trap 'rm -f "$skill_names_file"' EXIT

for skill_file in "${skill_files[@]}"; do
  skill_dir="$(dirname "$skill_file")"
  expected_name="$(basename "$skill_dir")"
  first_line="$(sed -n '1p' "$skill_file")"
  name="$(sed -n 's/^name: *//p' "$skill_file" | head -n 1)"
  description="$(sed -n 's/^description: *//p' "$skill_file" | head -n 1)"

  [[ "$first_line" == '---' ]] || fail "$skill_file 缺少 YAML 起始标记"
  grep -q '^---$' <(sed -n '3,12p' "$skill_file") || fail "$skill_file 缺少 YAML 结束标记"
  [[ -n "$name" ]] || fail "$skill_file 缺少 name"
  [[ "$name" == "$expected_name" ]] || fail "$skill_file 的 name=$name 与目录名=$expected_name 不一致"
  [[ -n "$description" ]] || fail "$skill_file 缺少 description"
  grep -Eq 'TODO|TBD|FIXME' "$skill_file" && fail "$skill_file 含未完成占位内容"

  fence_count="$(awk '/^~~~[[:space:]]*[[:alnum:]_-]*[[:space:]]*$/ { count++ } END { print count + 0 }' "$skill_file")"
  (( fence_count % 2 == 0 )) || fail "$skill_file 的代码围栏不成对"
  printf '%s\n' "$name" >> "$skill_names_file"
done

duplicate_names="$(sort "$skill_names_file" | uniq -d)"
[[ -z "$duplicate_names" ]] || fail "skill 名称重复：$duplicate_names"

total_checklists="$(find "$CHECKLIST_ROOT" -type f -name '*.md' | wc -l | tr -d ' ')"
root_checklists="$(find "$CHECKLIST_ROOT" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
domain_checklists=$((total_checklists - root_checklists))
[[ "$root_checklists" -eq "$expected_root_checklist_count" ]] || fail "总清单数量应为 ${expected_root_checklist_count}，实际为 $root_checklists"
[[ "$domain_checklists" -eq "$expected_domain_checklist_count" ]] || fail "领域子清单数量应为 ${expected_domain_checklist_count}，实际为 $domain_checklists"

user_journey_checklist="$CHECKLIST_ROOT/business-test/user-journey-acceptance.md"
require_file "$user_journey_checklist"
if ! grep -qF 'business-test/user-journey-acceptance.md' "$CHECKLIST_ROOT/BUSINESS_TEST_CHECKLIST.md"; then
  fail '业务测试总清单未路由用户流程验收子清单'
fi

for routed_file in \
  "$SKILL_ROOT/backend/database-review/SKILL.md" \
  "$SKILL_ROOT/backend/data-access-review/SKILL.md" \
  "$CHECKLIST_ROOT/code-review/database-quality.md" \
  "$CHECKLIST_ROOT/code-review/data-access-quality.md" \
  "$CHECKLIST_ROOT/db-change/schema-definition.md" \
  "$CHECKLIST_ROOT/db-change/sql-index-performance.md"; do
  require_file "$routed_file"
done

for unix_script in \
  validate.sh \
  install-project.sh \
  install-global.sh \
  uninstall-global.sh \
  status.sh; do
  require_file "$SCRIPT_DIR/$unix_script"
done

for windows_script in \
  validate.ps1 \
  install-project.ps1 \
  install-global.ps1 \
  uninstall-global.ps1 \
  status.ps1 \
  validate.bat \
  install-project.bat \
  install-global.bat \
  uninstall-global.bat \
  status.bat; do
  require_file "$SCRIPT_DIR/$windows_script"
done

if [[ -f "$GLOBAL_RULE_BLOCK" ]] && grep -q '^# ' "$GLOBAL_RULE_BLOCK"; then
  fail '全局规则片段不能包含一级标题，避免合并后破坏全局 AGENTS.md 结构'
fi

if grep -RInE '/Users/[^/[:space:]]+|[A-Za-z]:\\Users\\' \
  "$REPO_ROOT/README.md" \
  "$REPO_ROOT/AGENTS.md" \
  "$REPO_ROOT/rules" \
  "$REPO_ROOT/docs" >/dev/null 2>&1; then
  fail '公开规则或文档中仍包含个人用户目录'
fi

for batch_script in "$SCRIPT_DIR"/*.bat; do
  [[ -f "$batch_script" ]] || continue
  powershell_script="${batch_script%.bat}.ps1"
  grep -qF -- "$(basename "$powershell_script")" "$batch_script" ||
    fail "$batch_script 未转发到对应的 PowerShell 脚本"
done

if grep -RIn --exclude='*.DS_Store' 'mysql-mybatis-quality.md' "$REPO_ROOT/.codex" >/dev/null 2>&1; then
  fail '活动文件仍引用已拆分的 mysql-mybatis-quality.md'
fi

for script_file in "$SCRIPT_DIR"/*.sh; do
  [[ -f "$script_file" ]] || continue
  bash -n "$script_file" || fail "脚本语法错误：$script_file"
done

if ! command -v pwsh >/dev/null 2>&1 && ! command -v powershell >/dev/null 2>&1; then
  echo '提示：当前环境未找到 pwsh 或 powershell，仅验证 Windows 入口文件和批处理转发关系。' >&2
fi

if [[ "$error_count" -ne 0 ]]; then
  echo "验证失败：$error_count 项。" >&2
  exit 1
fi

echo "验证通过：${expected_skill_count} 个 skill、${expected_workflow_count} 个工作流、${expected_root_checklist_count} 个总清单、${expected_domain_checklist_count} 个领域子清单、工作流引用、活动引用、Unix 入口与语法、Windows 入口文件与批处理转发关系均正常。"
