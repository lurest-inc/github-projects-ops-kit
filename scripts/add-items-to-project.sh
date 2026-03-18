#!/usr/bin/env bash
set -euo pipefail

# GitHub Project Item 一括追加スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/add-items-to-project
#
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number
#   TARGET_REPO    - 対象 Repository（owner/repo 形式）
#   ITEM_TYPE      - 対象 Item の種別（all/issues/prs、デフォルト: all）
#   ITEM_STATE     - 取得する Item の状態（open/closed/all、デフォルト: open）
#   ITEM_LABEL     - 絞り込みラベル（指定ラベルの Issue/PR のみ追加、省略可）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_common_project_env
require_env "TARGET_REPO"

if [[ ! "${TARGET_REPO}" =~ ^[^/]+/[^/]+$ ]]; then
  echo "::error::TARGET_REPO は owner/repo 形式で指定してください（例: myorg/myrepo）。"
  exit 1
fi

ITEM_TYPE="${ITEM_TYPE:-all}"
ITEM_STATE="${ITEM_STATE:-open}"
ITEM_LABEL="${ITEM_LABEL:-}"

validate_enum "ITEM_TYPE" "${ITEM_TYPE}" "all" "issues" "prs"
validate_enum "ITEM_STATE" "${ITEM_STATE}" "open" "closed" "all"

# ステータス自動付与ルール: open → Backlog、closed/merged → Done
INITIAL_STATUS="Backlog"

# --- Project ID と Status フィールド情報の取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の Status フィールドを取得しています..."

STATUS_FIELD_QUERY_TEMPLATE=$(cat <<'GRAPHQL'
query($login: String!, $number: Int!) {
  __OWNER_FIELD__(login: $login) {
    projectV2(number: $number) {
      id
      fields(first: 100) {
        nodes {
          ... on ProjectV2SingleSelectField {
            id
            name
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}
GRAPHQL
)
STATUS_FIELD_QUERY=$(apply_owner_field "${STATUS_FIELD_QUERY_TEMPLATE}")

VARIABLES_JSON=$(jq -n \
  --arg login "${PROJECT_OWNER}" \
  --argjson number "${PROJECT_NUMBER}" \
  '{login: $login, number: $number}')

STATUS_FIELD_RESULT=$(run_graphql_json "${STATUS_FIELD_QUERY}" "Status フィールド情報の取得" "${VARIABLES_JSON}")

# Project ID・Status フィールド ID・Option ID を一括抽出
IFS=$'\t' read -r PROJECT_ID STATUS_FIELD_ID INITIAL_STATUS_OPTION_ID DONE_STATUS_OPTION_ID < <(
  echo "${STATUS_FIELD_RESULT}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" --arg initial "${INITIAL_STATUS}" '
    .data.[($owner)].projectV2 as $proj |
    ([$proj.fields.nodes[] | select(.name == "Status")] | first // null) as $status |
    [
      ($proj.id // ""),
      ($status.id // ""),
      ([$status.options[]? | select(.name == $initial) | .id] | first // ""),
      ([$status.options[]? | select(.name == "Done") | .id] | first // "")
    ] | @tsv
  '
)

if [[ -z "${PROJECT_ID}" ]]; then
  echo "::error::Project ID を取得できませんでした。Project #${PROJECT_NUMBER} が存在するか確認してください。"
  exit 1
fi
echo "  Project ID: ${PROJECT_ID}"

if [[ -z "${STATUS_FIELD_ID}" ]]; then
  echo "::error::Status フィールドが見つかりませんでした。"
  exit 1
fi
echo "  Status Field ID: ${STATUS_FIELD_ID}"

if [[ -z "${INITIAL_STATUS_OPTION_ID}" ]]; then
  echo "::error::ステータス「${INITIAL_STATUS}」が Project に存在しません。setup-project-status.sh でステータスカラムを設定してください。"
  exit 1
fi
echo "  初期ステータス: ${INITIAL_STATUS} (${INITIAL_STATUS_OPTION_ID})"

if [[ -z "${DONE_STATUS_OPTION_ID}" ]]; then
  echo "::error::ステータス「Done」が Project に存在しません。setup-project-status.sh でステータスカラムを設定してください。"
  exit 1
fi
echo "  Done ステータス: Done (${DONE_STATUS_OPTION_ID})"

# --- Repository と Project のリンク ---

echo ""
echo "Repository と Project のリンクを確認しています..."

# Repository の node_id を取得
REPO_NODE_ID=$(gh api "repos/${TARGET_REPO}" \
  -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
  --jq '.node_id' 2>&1) || {
  safe_output=$(sanitize_for_workflow_command "${REPO_NODE_ID}")
  echo "::error::Repository 情報の取得に失敗しました: ${safe_output}"
  exit 1
}

if [[ -z "${REPO_NODE_ID}" || "${REPO_NODE_ID}" == "null" ]]; then
  echo "::error::Repository の node_id を取得できませんでした。TARGET_REPO=${TARGET_REPO} が正しいか確認してください。"
  exit 1
fi
echo "  Repository Node ID: ${REPO_NODE_ID}"

# リンクを試行し、既にリンク済みの場合はスキップ扱いにする
# 事前クエリでのリンク状態確認はページネーションの考慮が必要なため、
# 直接 mutation を実行して結果で判定する方式を採用
LINK_MUTATION=$(cat <<'GRAPHQL'
mutation($projectId: ID!, $repositoryId: ID!) {
  linkProjectV2ToRepository(input: {
    projectId: $projectId,
    repositoryId: $repositoryId
  }) {
    repository {
      id
    }
  }
}
GRAPHQL
)

LINK_VARIABLES_JSON=$(jq -n \
  --arg projectId "${PROJECT_ID}" \
  --arg repositoryId "${REPO_NODE_ID}" \
  '{projectId: $projectId, repositoryId: $repositoryId}')

LINK_REQUEST_BODY=$(jq -n \
  --arg query "${LINK_MUTATION}" \
  --argjson variables "${LINK_VARIABLES_JSON}" \
  '{query: $query, variables: $variables}')

LINK_STATUS=""
LINK_RESULT=$(printf '%s' "${LINK_REQUEST_BODY}" | gh api graphql --input - 2>&1) && {
  # mutation 成功（新規リンク作成）
  if echo "${LINK_RESULT}" | jq -e '.errors and (.errors | length > 0)' >/dev/null 2>&1; then
    # レスポンス内に GraphQL エラーがある場合（既にリンク済みなど）
    LINK_ERROR_MSG=$(echo "${LINK_RESULT}" | jq -r '.errors[0].message // empty')
    echo "  Repository は既に Project にリンク済みです。スキップします。"
    LINK_STATUS="スキップ（リンク済み）"
  else
    echo "  リンク完了: ${TARGET_REPO} → Project #${PROJECT_NUMBER}"
    LINK_STATUS="リンク作成"
  fi
} || {
  # gh api コマンド自体が非ゼロで終了した場合
  # 既にリンク済みの場合のエラーはスキップ扱いにする
  if echo "${LINK_RESULT}" | grep -qi "already linked\|already exists"; then
    echo "  Repository は既に Project にリンク済みです。スキップします。"
    LINK_STATUS="スキップ（リンク済み）"
  else
    safe_output=$(sanitize_for_workflow_command "${LINK_RESULT}")
    echo "::error::Repository と Project のリンクに失敗しました: ${safe_output}"
    exit 1
  fi
}

# --- ヘルパー関数 ---

# Item にステータスを設定する
set_item_status() {
  local item_id="$1"
  local option_id="$2"

  local mutation
  mutation=$(cat <<'GRAPHQL'
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId: $itemId
    fieldId: $fieldId
    value: { singleSelectOptionId: $optionId }
  }) {
    projectV2Item {
      id
    }
  }
}
GRAPHQL
  )

  local variables_json
  variables_json=$(jq -n \
    --arg projectId "${PROJECT_ID}" \
    --arg itemId "${item_id}" \
    --arg fieldId "${STATUS_FIELD_ID}" \
    --arg optionId "${option_id}" \
    '{projectId: $projectId, itemId: $itemId, fieldId: $fieldId, optionId: $optionId}')

  run_graphql_json "${mutation}" "ステータスの設定" "${variables_json}" > /dev/null
}

# Project に既に追加済みの Item URL を取得する
get_existing_project_items() {
  local items=""

  _on_existing_items_page() {
    local result="$1"
    local page_items
    page_items=$(echo "${result}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" \
      '.data.[($owner)].projectV2.items.nodes[].content.url // empty' 2>/dev/null || true)
    if [[ -n "${page_items}" ]]; then
      if [[ -n "${items}" ]]; then
        items="${items}"$'\n'"${page_items}"
      else
        items="${page_items}"
      fi
    fi
  }

  local query_template
  query_template=$(cat <<'GRAPHQL'
query($login: String!, $number: Int!, $after: String) {
  __OWNER_FIELD__(login: $login) {
    projectV2(number: $number) {
      items(first: 100, after: $after) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          content {
            ... on Issue {
              url
            }
            ... on PullRequest {
              url
            }
          }
        }
      }
    }
  }
}
GRAPHQL
)
  local query
  query=$(apply_owner_field "${query_template}")

  local variables_json
  variables_json=$(jq -n \
    --arg login "${PROJECT_OWNER}" \
    --argjson number "${PROJECT_NUMBER}" \
    '{login: $login, number: $number}')

  if ! run_graphql_paginated "${query}" "Project の既存 Item 取得" "${variables_json}" \
    '.data.[($owner)].projectV2.items.pageInfo' _on_existing_items_page; then
    echo "::warning::Project の既存 Item 取得に失敗しました。重複チェックをスキップします。" >&2
    echo ""
    return
  fi

  echo "${items}"
}

# --- 既存 Item 取得（重複防止用） ---

echo ""
echo "Project #${PROJECT_NUMBER} の既存 Item を取得しています..."
EXISTING_ITEMS=$(get_existing_project_items)
if [[ -n "${EXISTING_ITEMS}" ]]; then
  EXISTING_COUNT=$(echo "${EXISTING_ITEMS}" | wc -l | tr -d ' ')
  echo "  既存 Item 数: ${EXISTING_COUNT}"
else
  EXISTING_COUNT=0
  echo "  既存 Item 数: 0"
fi

# --- Item 取得・追加（共通関数） ---

# Item（Issue / PR）を取得して Project に追加する
# 引数: $1=種別ラベル（Issue / PR）, $2=gh サブコマンド（issue / pr）, $3=Done 判定用 state パターン
# 出力: ログは stderr、カウント（ADDED SKIPPED FAILED）は stdout に TSV で返す
fetch_and_add_items() {
  local label="$1"
  local gh_command="$2"
  local done_states="$3"
  local added=0 skipped=0 failed=0 safe_output

  echo "" >&2
  echo "${label} を取得しています..." >&2
  if [[ "${label}" == "Issue" ]]; then
    echo "  Repository: ${TARGET_REPO}" >&2
    echo "  状態: ${ITEM_STATE}" >&2
    if [[ -n "${ITEM_LABEL}" ]]; then
      echo "  ラベル: ${ITEM_LABEL}" >&2
    fi
  fi

  # 1 回の取得で処理する Item 数の上限
  local list_args=(--repo "${TARGET_REPO}" --state "${ITEM_STATE}" --limit 100 --json url,state --jq '.[] | [.url, .state] | @tsv')
  if [[ -n "${ITEM_LABEL}" ]]; then
    list_args+=(--label "${ITEM_LABEL}")
  fi

  local items_output
  if ! items_output=$(gh "${gh_command}" list "${list_args[@]}" 2>&1); then
    safe_output=$(sanitize_for_workflow_command "${items_output}")
    echo "::error::${label} の取得に失敗しました: ${safe_output}" >&2
    exit 1
  fi

  if [[ -n "${items_output}" ]]; then
    while IFS=$'\t' read -r url state; do
      [[ -z "${url}" ]] && continue

      if [[ -n "${EXISTING_ITEMS}" ]] && echo "${EXISTING_ITEMS}" | grep -Fxq "${url}"; then
        echo "  スキップ（追加済み）: ${url}" >&2
        skipped=$((skipped + 1))
        continue
      fi

      if add_result=$(gh project item-add "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" --url "${url}" --format json 2>&1); then
        item_id=$(echo "${add_result}" | jq -r '.id // empty')
        echo "  追加: ${url}" >&2
        added=$((added + 1))

        if [[ -n "${item_id}" ]]; then
          if [[ "${done_states}" == *"${state}"* ]]; then
            set_item_status "${item_id}" "${DONE_STATUS_OPTION_ID}"
            echo "    ステータス: Done（${state}）" >&2
          else
            set_item_status "${item_id}" "${INITIAL_STATUS_OPTION_ID}"
            echo "    ステータス: ${INITIAL_STATUS}" >&2
          fi
        fi
      else
        safe_output=$(sanitize_for_workflow_command "${add_result}")
        echo "::warning::追加失敗: ${url} — ${safe_output}" >&2
        failed=$((failed + 1))
      fi

      sleep 1
    done <<< "${items_output}"
  fi

  echo "  ${label} 追加: ${added} 件、スキップ: ${skipped} 件、失敗: ${failed} 件" >&2
  printf '%d\t%d\t%d\n' "${added}" "${skipped}" "${failed}"
}

# --- Issue 取得・追加 ---

ISSUE_ADDED=0
ISSUE_SKIPPED=0
ISSUE_FAILED=0

if should_include_issues; then
  IFS=$'\t' read -r ISSUE_ADDED ISSUE_SKIPPED ISSUE_FAILED < <(fetch_and_add_items "Issue" "issue" "CLOSED")
else
  echo ""
  echo "Issue の追加をスキップします（ITEM_TYPE=${ITEM_TYPE}）"
fi

# --- Pull Request 取得・追加 ---

PR_ADDED=0
PR_SKIPPED=0
PR_FAILED=0

if should_include_prs; then
  IFS=$'\t' read -r PR_ADDED PR_SKIPPED PR_FAILED < <(fetch_and_add_items "PR" "pr" "CLOSED MERGED")
else
  echo ""
  echo "Pull Request の追加をスキップします（ITEM_TYPE=${ITEM_TYPE}）"
fi

# --- サマリー ---

TOTAL_ADDED=$((ISSUE_ADDED + PR_ADDED))
TOTAL_SKIPPED=$((ISSUE_SKIPPED + PR_SKIPPED))
TOTAL_FAILED=$((ISSUE_FAILED + PR_FAILED))

print_summary \
  "Target Repo" "${TARGET_REPO}" \
  "リンク" "${LINK_STATUS}" \
  "Issue" "追加: ${ISSUE_ADDED}, スキップ: ${ISSUE_SKIPPED}, 失敗: ${ISSUE_FAILED}" \
  "PR" "追加: ${PR_ADDED}, スキップ: ${PR_SKIPPED}, 失敗: ${PR_FAILED}" \
  "合計" "追加: ${TOTAL_ADDED}, スキップ: ${TOTAL_SKIPPED}, 失敗: ${TOTAL_FAILED}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Project Item 一括追加 完了"
    echo ""
    echo "| 項目 | 値 |"
    echo "|------|-----|"
    echo "| Target Repo | \`${TARGET_REPO}\` |"
    echo "| Repo Link | ${LINK_STATUS} |"
    echo "| State Filter | ${ITEM_STATE} |"
    echo "| Status | open → Backlog / closed・merged → Done |"
    if [[ -n "${ITEM_LABEL}" ]]; then
      echo "| Label Filter | ${ITEM_LABEL} |"
    fi
    echo "| Issue 追加 | ${ISSUE_ADDED} 件 |"
    echo "| Issue スキップ | ${ISSUE_SKIPPED} 件 |"
    echo "| Issue 失敗 | ${ISSUE_FAILED} 件 |"
    echo "| PR 追加 | ${PR_ADDED} 件 |"
    echo "| PR スキップ | ${PR_SKIPPED} 件 |"
    echo "| PR 失敗 | ${PR_FAILED} 件 |"
    echo "| **合計追加** | **${TOTAL_ADDED} 件** |"
    echo "| **合計失敗** | **${TOTAL_FAILED} 件** |"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

echo ""
if [[ "${TOTAL_FAILED}" -gt 0 ]]; then
  echo "::error::Item の追加に ${TOTAL_FAILED} 件失敗しました（追加: ${TOTAL_ADDED} 件、スキップ: ${TOTAL_SKIPPED} 件）。"
  exit 1
fi

echo "::notice::Item の一括追加が完了しました（追加: ${TOTAL_ADDED} 件、スキップ: ${TOTAL_SKIPPED} 件）。"
