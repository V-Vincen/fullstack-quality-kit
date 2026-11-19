#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_ROOT="$REPO_ROOT/skills/fullstack-review"
WORKFLOW_ROOT="$SKILL_ROOT/workflows"
CHECKLIST_ROOT="$REPO_ROOT/checklists"
RULES_FILE="$SCRIPT_DIR/validation-rules.conf"
GLOBAL_RULE_BLOCK="$REPO_ROOT/rules/global-agents.block.md"
LEGACY_PROJECT_MANIFEST_V015="$SCRIPT_DIR/project-legacy-v0.1.5.manifest"
LEGACY_PROJECT_MANIFEST_V020="$SCRIPT_DIR/project-legacy-v0.2.0.manifest"
LEGACY_PROJECT_MANIFEST_HEADER_V015='# fullstack-quality-kit legacy project manifest v0.1.5'
LEGACY_PROJECT_MANIFEST_HEADER_V020='# fullstack-quality-kit legacy project manifest v0.2.0'

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
  expected_legacy_project_old_record_count=""
  expected_legacy_project_release_record_count=""

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
      EXPECTED_LEGACY_PROJECT_OLD_RECORD_COUNT)
        if [[ -n "$expected_legacy_project_old_record_count" ]]; then
          fail "验证规则重复：$key"
        else
          expected_legacy_project_old_record_count="$value"
        fi
        ;;
      EXPECTED_LEGACY_PROJECT_RELEASE_RECORD_COUNT)
        if [[ -n "$expected_legacy_project_release_record_count" ]]; then
          fail "验证规则重复：$key"
        else
          expected_legacy_project_release_record_count="$value"
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
  [[ -n "$expected_legacy_project_old_record_count" ]] || fail '验证规则缺少：EXPECTED_LEGACY_PROJECT_OLD_RECORD_COUNT'
  [[ -n "$expected_legacy_project_release_record_count" ]] || fail '验证规则缺少：EXPECTED_LEGACY_PROJECT_RELEASE_RECORD_COUNT'
}

check_checklist_path_conflicts() {
  local candidate
  local -a candidates=(
    "$REPO_ROOT/.claude/checklists"
    "$REPO_ROOT/.codex/checklists"
    "${HOME}/.claude/checklists/fullstack-quality-kit"
    "${HOME}/.codex/checklists/fullstack-quality-kit"
  )
  local -a available=()

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate/CODE_REVIEW_CHECKLIST.md" ]]; then
      available+=("$candidate")
    fi
  done
  if [[ "${#available[@]}" -gt 1 ]]; then
    echo "警告：检测到多个清单候选目录；运行时必须按当前宿主优先级选择且不得混用：${available[*]}" >&2
  fi
}

check_workflow_content_quality() {
  local workflow_file
  for workflow_file in "$WORKFLOW_ROOT"/*.md; do
    [[ -f "$workflow_file" ]] || continue
    if grep -Eq 'TODO|TBD|FIXME' "$workflow_file"; then
      echo "警告：工作流文件包含未完成占位符（TODO/TBD/FIXME）：$(basename "$workflow_file")" >&2
    fi
  done
}

check_checklist_content_quality() {
  local checklist_file line_count
  for checklist_file in "$CHECKLIST_ROOT"/*.md "$CHECKLIST_ROOT"/*/*.md; do
    [[ -f "$checklist_file" ]] || continue
    line_count="$(wc -l < "$checklist_file")"
    if [[ $line_count -lt 5 ]]; then
      echo "警告：清单文件内容过短（$line_count 行）：$(basename "$checklist_file")" >&2
    fi
  done
}

check_skill_routing_references() {
  local skill_file referenced_path
  while IFS= read -r skill_file; do
    while IFS= read -r referenced_path; do
      if [[ ! -f "$CHECKLIST_ROOT/$referenced_path" ]]; then
        fail "$skill_file 引用了不存在的清单：$referenced_path"
      fi
    done < <(grep -Eo 'business-test/[a-z-]+\.md|code-review/[a-z-]+\.md|db-change/[a-z-]+\.md|external-api-doc/[a-z-]+\.md' "$skill_file" 2>/dev/null | sort -u)
  done < <(find "$SKILL_ROOT" -type f -name 'SKILL.md' -print | sort)
}

check_total_checklist_routing_references() {
  local checklist_file referenced_path
  for checklist_file in "$CHECKLIST_ROOT"/*.md; do
    [[ -f "$checklist_file" ]] || continue
    while IFS= read -r referenced_path; do
      if [[ ! -f "$CHECKLIST_ROOT/$referenced_path" ]]; then
        fail "$checklist_file 引用了不存在的领域子清单：$referenced_path"
      fi
    done < <(grep -Eo 'business-test/[a-z-]+\.md|code-review/[a-z-]+\.md|db-change/[a-z-]+\.md|external-api-doc/[a-z-]+\.md' "$checklist_file" 2>/dev/null | sort -u)
  done
}

check_workflow_routing_references() {
  local workflow_name
  for workflow_name in preflight-grill.md visualization.md user-journey-acceptance.md; do
    if ! grep -qF "workflows/$workflow_name" "$SKILL_ROOT/SKILL.md"; then
      fail "主 skill 未引用工作流：workflows/$workflow_name"
    fi
  done
}

check_subskill_routing_references() {
  local subskill_path
  for subskill_path in \
    backend/java-review/SKILL.md \
    backend/springboot-review/SKILL.md \
    backend/database-review/SKILL.md \
    backend/data-access-review/SKILL.md \
    frontend-review/SKILL.md \
    appsec-review/SKILL.md \
    test-generation/SKILL.md; do
    if ! grep -qF "$subskill_path" "$SKILL_ROOT/SKILL.md"; then
      fail "主 skill 未路由专业子 skill：$subskill_path"
    fi
  done
  if ! grep -F '一次任务可以组合多个子 skill' "$SKILL_ROOT/SKILL.md" | grep -qF 'appsec-review'; then
    fail '主 skill 缺少多个专业子 skill 的组合路由示例'
  fi
}

check_host_specific_path_order() {
  if ! grep -qF '在 Codex 中' "$SKILL_ROOT/SKILL.md" || ! grep -qF '在 Claude Code 中' "$SKILL_ROOT/SKILL.md"; then
    fail '主 skill 未分别定义 Codex 与 Claude Code 的清单路径优先级'
  fi
  if ! grep -qF '在 Codex 中' "$GLOBAL_RULE_BLOCK" || ! grep -qF '在 Claude Code 中' "$GLOBAL_RULE_BLOCK"; then
    fail '全局规则片段未分别定义 Codex 与 Claude Code 的清单路径优先级'
  fi
}

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{ print $1 }'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{ print $1 }'
  else
    return 1
  fi
}

check_legacy_project_manifest() {
  local manifest_file="$1"
  local manifest_header="$2"
  local tag_name="$3"
  local source_layout="$4"
  local expected_record_count="$5"
  local line kind relative_path expected_hash extra tag_path actual_hash
  local record_count=0
  local duplicate_records
  local tag_available=0

  require_file "$manifest_file"
  [[ -f "$manifest_file" ]] || return
  if [[ "$(sed -n '1p' "$manifest_file")" != "$manifest_header" ]]; then
    fail "$tag_name 项目升级清单表头无效"
    return
  fi
  if git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$tag_name^{commit}" >/dev/null 2>&1; then
    tag_available=1
  elif git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "警告：当前 Git 仓库未包含 $tag_name 标签，只验证项目升级清单的格式、数量和重复记录。" >&2
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$manifest_header" || -z "$line" || "${line#\#}" != "$line" ]] && continue
    IFS=$'\t' read -r kind relative_path expected_hash extra <<< "$line"
    if [[ -z "$kind" || -z "$relative_path" || -z "$expected_hash" || -n "$extra" || ! "$expected_hash" =~ ^[[:xdigit:]]{64}$ ]]; then
      fail "$tag_name 项目升级清单记录无效：$line"
      continue
    fi
    case "$kind" in
      skills|checklists)
        if [[ "$source_layout" == 'codex' ]]; then
          tag_path=".codex/$kind/$relative_path"
        else
          tag_path="$kind/$relative_path"
        fi
        ;;
      *)
        fail "$tag_name 项目升级清单包含未知类型：$kind"
        continue
        ;;
    esac
    record_count=$((record_count + 1))
    if [[ "$tag_available" -eq 1 ]]; then
      if git -C "$REPO_ROOT" cat-file -e "$tag_name:$tag_path" 2>/dev/null; then
        actual_hash="$(git -C "$REPO_ROOT" show "$tag_name:$tag_path" | sha256_stdin)"
        [[ "$actual_hash" == "$expected_hash" ]] || fail "$tag_name 项目升级清单哈希不一致：$kind/$relative_path"
      else
        fail "$tag_name 标签缺少升级清单对应文件：$tag_path"
      fi
    fi
  done < "$manifest_file"
  [[ "$record_count" -eq "$expected_record_count" ]] || fail "$tag_name 项目升级清单应为 ${expected_record_count} 条，实际为 $record_count"
  duplicate_records="$(awk -F '\t' 'NF == 3 && $1 !~ /^#/ { print $1 "\t" $2 }' "$manifest_file" | sort | uniq -d)"
  [[ -z "$duplicate_records" ]] || fail "$tag_name 项目升级清单存在重复记录：$duplicate_records"
}

require_file "$REPO_ROOT/AGENTS.md"
require_file "$REPO_ROOT/README.md"
require_file "$SKILL_ROOT/SKILL.md"
require_file "$RULES_FILE"
require_file "$GLOBAL_RULE_BLOCK"
require_file "$LEGACY_PROJECT_MANIFEST_V015"
require_file "$LEGACY_PROJECT_MANIFEST_V020"

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
  visualization.md \
  user-journey-acceptance.md; do
  require_file "$WORKFLOW_ROOT/$workflow_name"
done

workflow_count="$(find "$WORKFLOW_ROOT" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
[[ "$workflow_count" -eq "$expected_workflow_count" ]] || fail "工作流数量应为 ${expected_workflow_count}，实际为 ${workflow_count}"

# 增强内容检查
check_checklist_path_conflicts
check_workflow_content_quality
check_checklist_content_quality
check_skill_routing_references
check_total_checklist_routing_references
check_workflow_routing_references
check_subskill_routing_references
check_host_specific_path_order
check_legacy_project_manifest "$LEGACY_PROJECT_MANIFEST_V015" "$LEGACY_PROJECT_MANIFEST_HEADER_V015" v0.1.5 codex "$expected_legacy_project_old_record_count"
check_legacy_project_manifest "$LEGACY_PROJECT_MANIFEST_V020" "$LEGACY_PROJECT_MANIFEST_HEADER_V020" v0.2.0 root "$expected_legacy_project_release_record_count"

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
  status.sh \
  test-lifecycle.sh; do
  require_file "$SCRIPT_DIR/$unix_script"
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

if grep -RIn --exclude='*.DS_Store' 'mysql-mybatis-quality.md' "$REPO_ROOT/skills" "$REPO_ROOT/checklists" >/dev/null 2>&1; then
  fail '活动文件仍引用已拆分的 mysql-mybatis-quality.md'
fi

for script_file in "$SCRIPT_DIR"/*.sh; do
  [[ -f "$script_file" ]] || continue
  bash -n "$script_file" || fail "脚本语法错误：$script_file"
done

if [[ "$error_count" -ne 0 ]]; then
  echo "验证失败：$error_count 项。" >&2
  exit 1
fi

echo "验证通过：${expected_skill_count} 个 skill、${expected_workflow_count} 个工作流、${expected_root_checklist_count} 个总清单、${expected_domain_checklist_count} 个领域子清单、项目升级清单、宿主路径顺序、工作流引用、活动引用、Unix 入口与语法均正常。"
