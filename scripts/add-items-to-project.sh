#!/usr/bin/env bash
set -euo pipefail

# GitHub Project アイテム一括追加スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/add-items-to-project
#
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number
#   TARGET_REPO    - 対象リポジトリ（owner/repo 形式）
#   ITEM_TYPE      - 対象アイテムの種別（all/issues/prs、デフォルト: all）
#   ITEM_STATE     - 取得するアイテムの状態（open/closed/all、デフォルト: open）
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

# ステータス自動付与ルール: open → Backlog、closed/merged → Done
INITIAL_STATUS="Backlog"

INCLUDE_ISSUES=$( [[ "${ITEM_TYPE}" == "all" || "${ITEM_TYPE}" == "issues" ]] && echo "true" || echo "false" )
INCLUDE_PRS=$( [[ "${ITEM_TYPE}" == "all" || "${ITEM_TYPE}" == "prs" ]] && echo "true" || echo "false" )

# --- Project ID と Status フィールド情報の取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の Status フィールドを取得しています..."

STATUS_FIELD_QUERY=$(cat <<GRAPHQL
query {
  ${OWNER_QUERY_FIELD}(login: "${PROJECT_OWNER}") {
    projectV2(number: ${PROJECT_NUMBER}) {
      id
      fields(first: 50) {
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

STATUS_FIELD_RESULT=$(run_graphql "${STATUS_FIELD_QUERY}" "Status フィールド情報の取得")

PROJECT_ID=$(echo "${STATUS_FIELD_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.id // empty")
if [[ -z "${PROJECT_ID}" ]]; then
  echo "::error::Project ID を取得できませんでした。Project #${PROJECT_NUMBER} が存在するか確認してください。"
  exit 1
fi
echo "  Project ID: ${PROJECT_ID}"

STATUS_FIELD_ID=$(echo "${STATUS_FIELD_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.fields.nodes[] | select(.name == \"Status\") | .id // empty")
if [[ -z "${STATUS_FIELD_ID}" ]]; then
  echo "::error::Status フィールドが見つかりませんでした。"
  exit 1
fi
echo "  Status Field ID: ${STATUS_FIELD_ID}"

# ステータス名から Option ID を取得する関数
get_status_option_id() {
  local status_name="$1"
  echo "${STATUS_FIELD_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.fields.nodes[] | select(.name == \"Status\") | .options[] | select(.name == \"${status_name}\") | .id // empty"
}

INITIAL_STATUS_OPTION_ID=$(get_status_option_id "${INITIAL_STATUS}")
if [[ -z "${INITIAL_STATUS_OPTION_ID}" ]]; then
  echo "::error::ステータス「${INITIAL_STATUS}」が Project に存在しません。setup-project-status.sh でステータスカラムを設定してください。"
  exit 1
fi
echo "  初期ステータス: ${INITIAL_STATUS} (${INITIAL_STATUS_OPTION_ID})"

DONE_STATUS_OPTION_ID=$(get_status_option_id "Done")
if [[ -z "${DONE_STATUS_OPTION_ID}" ]]; then
  echo "::error::ステータス「Done」が Project に存在しません。setup-project-status.sh でステータスカラムを設定してください。"
  exit 1
fi
echo "  Done ステータス: Done (${DONE_STATUS_OPTION_ID})"

# --- ヘルパー関数 ---

# アイテムにステータスを設定する
set_item_status() {
  local item_id="$1"
  local option_id="$2"

  local mutation
  mutation=$(cat <<GRAPHQL
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "${PROJECT_ID}"
    itemId: "${item_id}"
    fieldId: "${STATUS_FIELD_ID}"
    value: { singleSelectOptionId: "${option_id}" }
  }) {
    projectV2Item {
      id
    }
  }
}
GRAPHQL
)

  run_graphql "${mutation}" "ステータスの設定" > /dev/null
}

# Project に既に追加済みのアイテム URL を取得する
get_existing_project_items() {
  local items=""
  local cursor=""
  local has_next="true"

  while [[ "${has_next}" == "true" ]]; do
    local after_clause=""
    if [[ -n "${cursor}" ]]; then
      after_clause=", after: \"${cursor}\""
    fi

    local query
    query=$(cat <<GRAPHQL
query {
  ${OWNER_QUERY_FIELD}(login: "${PROJECT_OWNER}") {
    projectV2(number: ${PROJECT_NUMBER}) {
      items(first: 100${after_clause}) {
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

    local result
    if ! result=$(gh api graphql -f query="${query}" 2>&1); then
      echo "::warning::Project の既存アイテム取得に失敗しました。重複チェックをスキップします。" >&2
      echo ""
      return
    fi

    local page_items
    page_items=$(echo "${result}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.items.nodes[].content.url // empty" 2>/dev/null || true)
    if [[ -n "${page_items}" ]]; then
      if [[ -n "${items}" ]]; then
        items="${items}"$'\n'"${page_items}"
      else
        items="${page_items}"
      fi
    fi

    has_next=$(echo "${result}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.items.pageInfo.hasNextPage" 2>/dev/null || echo "false")
    cursor=$(echo "${result}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.items.pageInfo.endCursor // empty" 2>/dev/null || true)
  done

  echo "${items}"
}

# --- 既存アイテム取得（重複防止用） ---

echo ""
echo "Project #${PROJECT_NUMBER} の既存アイテムを取得しています..."
EXISTING_ITEMS=$(get_existing_project_items)
if [[ -n "${EXISTING_ITEMS}" ]]; then
  EXISTING_COUNT=$(echo "${EXISTING_ITEMS}" | wc -l | tr -d ' ')
  echo "  既存アイテム数: ${EXISTING_COUNT}"
else
  EXISTING_COUNT=0
  echo "  既存アイテム数: 0"
fi

# --- Issue 取得・追加 ---

ISSUE_ADDED=0
ISSUE_SKIPPED=0
ISSUE_FAILED=0

if [[ "${INCLUDE_ISSUES}" == "true" ]]; then
  echo ""
  echo "Issue を取得しています..."
  echo "  リポジトリ: ${TARGET_REPO}"
  echo "  状態: ${ITEM_STATE}"
  if [[ -n "${ITEM_LABEL}" ]]; then
    echo "  ラベル: ${ITEM_LABEL}"
  fi

  ISSUE_LIST_ARGS=(--repo "${TARGET_REPO}" --state "${ITEM_STATE}" --limit 500 --json url,state --jq '.[] | [.url, .state] | @tsv')
  if [[ -n "${ITEM_LABEL}" ]]; then
    ISSUE_LIST_ARGS+=(--label "${ITEM_LABEL}")
  fi

  if ! ISSUE_ITEMS=$(gh issue list "${ISSUE_LIST_ARGS[@]}" 2>&1); then
    SAFE_OUTPUT=$(sanitize_for_workflow_command "${ISSUE_ITEMS}")
    echo "::error::Issue の取得に失敗しました: ${SAFE_OUTPUT}"
    exit 1
  fi

  if [[ -n "${ISSUE_ITEMS}" ]]; then
    while IFS=$'\t' read -r url state; do
      [[ -z "${url}" ]] && continue

      if [[ -n "${EXISTING_ITEMS}" ]] && echo "${EXISTING_ITEMS}" | grep -Fxq "${url}"; then
        echo "  スキップ（追加済み）: ${url}"
        ISSUE_SKIPPED=$((ISSUE_SKIPPED + 1))
        continue
      fi

      if add_result=$(gh project item-add "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" --url "${url}" --format json 2>&1); then
        item_id=$(echo "${add_result}" | jq -r '.id // empty')
        echo "  追加: ${url}"
        ISSUE_ADDED=$((ISSUE_ADDED + 1))

        # ステータスを設定
        if [[ -n "${item_id}" ]]; then
          if [[ "${state}" == "CLOSED" ]]; then
            set_item_status "${item_id}" "${DONE_STATUS_OPTION_ID}"
            echo "    ステータス: Done（closed）"
          else
            set_item_status "${item_id}" "${INITIAL_STATUS_OPTION_ID}"
            echo "    ステータス: ${INITIAL_STATUS}"
          fi
        fi
      else
        echo "::warning::追加失敗: ${url}"
        ISSUE_FAILED=$((ISSUE_FAILED + 1))
      fi

      sleep 1
    done <<< "${ISSUE_ITEMS}"
  fi

  echo "  Issue 追加: ${ISSUE_ADDED} 件、スキップ: ${ISSUE_SKIPPED} 件、失敗: ${ISSUE_FAILED} 件"
else
  echo ""
  echo "Issue の追加をスキップします（INCLUDE_ISSUES=false）"
fi

# --- Pull Request 取得・追加 ---

PR_ADDED=0
PR_SKIPPED=0
PR_FAILED=0

if [[ "${INCLUDE_PRS}" == "true" ]]; then
  echo ""
  echo "Pull Request を取得しています..."

  PR_LIST_ARGS=(--repo "${TARGET_REPO}" --state "${ITEM_STATE}" --limit 500 --json url,state --jq '.[] | [.url, .state] | @tsv')
  if [[ -n "${ITEM_LABEL}" ]]; then
    PR_LIST_ARGS+=(--label "${ITEM_LABEL}")
  fi

  if ! PR_ITEMS=$(gh pr list "${PR_LIST_ARGS[@]}" 2>&1); then
    SAFE_OUTPUT=$(sanitize_for_workflow_command "${PR_ITEMS}")
    echo "::error::Pull Request の取得に失敗しました: ${SAFE_OUTPUT}"
    exit 1
  fi

  if [[ -n "${PR_ITEMS}" ]]; then
    while IFS=$'\t' read -r url state; do
      [[ -z "${url}" ]] && continue

      if [[ -n "${EXISTING_ITEMS}" ]] && echo "${EXISTING_ITEMS}" | grep -Fxq "${url}"; then
        echo "  スキップ（追加済み）: ${url}"
        PR_SKIPPED=$((PR_SKIPPED + 1))
        continue
      fi

      if add_result=$(gh project item-add "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" --url "${url}" --format json 2>&1); then
        item_id=$(echo "${add_result}" | jq -r '.id // empty')
        echo "  追加: ${url}"
        PR_ADDED=$((PR_ADDED + 1))

        # ステータスを設定（closed = merged or closed、どちらも Done）
        if [[ -n "${item_id}" ]]; then
          if [[ "${state}" == "CLOSED" || "${state}" == "MERGED" ]]; then
            set_item_status "${item_id}" "${DONE_STATUS_OPTION_ID}"
            echo "    ステータス: Done（${state}）"
          else
            set_item_status "${item_id}" "${INITIAL_STATUS_OPTION_ID}"
            echo "    ステータス: ${INITIAL_STATUS}"
          fi
        fi
      else
        echo "::warning::追加失敗: ${url}"
        PR_FAILED=$((PR_FAILED + 1))
      fi

      sleep 1
    done <<< "${PR_ITEMS}"
  fi

  echo "  PR 追加: ${PR_ADDED} 件、スキップ: ${PR_SKIPPED} 件、失敗: ${PR_FAILED} 件"
else
  echo ""
  echo "Pull Request の追加をスキップします（INCLUDE_PRS=false）"
fi

# --- サマリー ---

TOTAL_ADDED=$((ISSUE_ADDED + PR_ADDED))
TOTAL_SKIPPED=$((ISSUE_SKIPPED + PR_SKIPPED))
TOTAL_FAILED=$((ISSUE_FAILED + PR_FAILED))

print_summary \
  "Issue" "追加: ${ISSUE_ADDED}, スキップ: ${ISSUE_SKIPPED}, 失敗: ${ISSUE_FAILED}" \
  "PR" "追加: ${PR_ADDED}, スキップ: ${PR_SKIPPED}, 失敗: ${PR_FAILED}" \
  "合計" "追加: ${TOTAL_ADDED}, スキップ: ${TOTAL_SKIPPED}, 失敗: ${TOTAL_FAILED}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Project アイテム一括追加 完了"
    echo ""
    echo "| 項目 | 値 |"
    echo "|------|-----|"
    echo "| Project Owner | \`${PROJECT_OWNER}\` |"
    echo "| Project Number | ${PROJECT_NUMBER} |"
    echo "| Target Repo | \`${TARGET_REPO}\` |"
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
  echo "::error::アイテムの追加に ${TOTAL_FAILED} 件失敗しました（追加: ${TOTAL_ADDED} 件、スキップ: ${TOTAL_SKIPPED} 件）。"
  exit 1
fi

echo "::notice::アイテムの一括追加が完了しました（追加: ${TOTAL_ADDED} 件、スキップ: ${TOTAL_SKIPPED} 件）。"
