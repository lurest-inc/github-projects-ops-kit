#!/usr/bin/env bash
set -euo pipefail

# GitHub Project アイテム一括追加スクリプト
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number
#   TARGET_REPO    - 対象リポジトリ（owner/repo 形式）
#   INCLUDE_ISSUES - Issue を追加対象にする（true/false、デフォルト: true）
#   INCLUDE_PRS    - PR を追加対象にする（true/false、デフォルト: true）
#   ITEM_STATE     - 取得するアイテムの状態（open/closed/all、デフォルト: open）
#   ITEM_LABEL     - 絞り込みラベル（指定ラベルの Issue/PR のみ追加、省略可）

# --- バリデーション ---

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "::error::GH_TOKEN が設定されていません。Secrets に PROJECT_PAT を設定してください。"
  exit 1
fi

if [[ -z "${PROJECT_OWNER:-}" ]]; then
  echo "::error::PROJECT_OWNER が指定されていません。"
  exit 1
fi

if [[ -z "${PROJECT_NUMBER:-}" ]]; then
  echo "::error::PROJECT_NUMBER が指定されていません。"
  exit 1
fi

if [[ -z "${TARGET_REPO:-}" ]]; then
  echo "::error::TARGET_REPO が指定されていません（owner/repo 形式）。"
  exit 1
fi

if [[ ! "${TARGET_REPO}" =~ ^[^/]+/[^/]+$ ]]; then
  echo "::error::TARGET_REPO は owner/repo 形式で指定してください（例: myorg/myrepo）。"
  exit 1
fi

INCLUDE_ISSUES="${INCLUDE_ISSUES:-true}"
INCLUDE_PRS="${INCLUDE_PRS:-true}"
ITEM_STATE="${ITEM_STATE:-open}"
ITEM_LABEL="${ITEM_LABEL:-}"

if [[ "${INCLUDE_ISSUES}" != "true" && "${INCLUDE_PRS}" != "true" ]]; then
  echo "::error::INCLUDE_ISSUES と INCLUDE_PRS の少なくとも一方を true にしてください。"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "::error::jq がインストールされていません。重複チェックに必要です。"
  exit 1
fi

# --- ヘルパー関数 ---

sanitize_for_workflow_command() {
  local value="$1"
  value="${value//'%'/'%25'}"
  value="${value//$'\n'/'%0A'}"
  value="${value//$'\r'/'%0D'}"
  echo "${value}"
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

# --- オーナータイプ判定 ---

echo "オーナータイプを判定しています..."

if ! OWNER_INFO=$(gh api "users/${PROJECT_OWNER}" --jq '.type' 2>&1); then
  SAFE_OWNER_INFO=$(sanitize_for_workflow_command "${OWNER_INFO}")
  SAFE_PROJECT_OWNER=$(sanitize_for_workflow_command "${PROJECT_OWNER}")
  echo "::error::オーナー情報の取得に失敗しました: ${SAFE_OWNER_INFO}"
  echo "::error::PROJECT_OWNER=${SAFE_PROJECT_OWNER} が正しいか確認してください。"
  exit 1
fi

OWNER_TYPE="${OWNER_INFO}"
echo "  オーナータイプ: ${OWNER_TYPE}"

if [[ "${OWNER_TYPE}" == "User" ]]; then
  OWNER_QUERY_FIELD="user"
elif [[ "${OWNER_TYPE}" == "Organization" ]]; then
  OWNER_QUERY_FIELD="organization"
else
  SAFE_OWNER_TYPE=$(sanitize_for_workflow_command "${OWNER_TYPE}")
  echo "::error::不明なオーナータイプ: ${SAFE_OWNER_TYPE}"
  exit 1
fi

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

  ISSUE_LIST_ARGS=(--repo "${TARGET_REPO}" --state "${ITEM_STATE}" --limit 500 --json url --jq '.[].url')
  if [[ -n "${ITEM_LABEL}" ]]; then
    ISSUE_LIST_ARGS+=(--label "${ITEM_LABEL}")
  fi

  if ! ISSUE_URLS=$(gh issue list "${ISSUE_LIST_ARGS[@]}" 2>&1); then
    SAFE_OUTPUT=$(sanitize_for_workflow_command "${ISSUE_URLS}")
    echo "::error::Issue の取得に失敗しました: ${SAFE_OUTPUT}"
    exit 1
  fi

  if [[ -n "${ISSUE_URLS}" ]]; then
    while IFS= read -r url; do
      [[ -z "${url}" ]] && continue

      if [[ -n "${EXISTING_ITEMS}" ]] && echo "${EXISTING_ITEMS}" | grep -Fxq "${url}"; then
        echo "  スキップ（追加済み）: ${url}"
        ISSUE_SKIPPED=$((ISSUE_SKIPPED + 1))
        continue
      fi

      if gh project item-add "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" --url "${url}" > /dev/null 2>&1; then
        echo "  追加: ${url}"
        ISSUE_ADDED=$((ISSUE_ADDED + 1))
      else
        echo "::warning::追加失敗: ${url}"
        ISSUE_FAILED=$((ISSUE_FAILED + 1))
      fi

      sleep 1
    done <<< "${ISSUE_URLS}"
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

  PR_LIST_ARGS=(--repo "${TARGET_REPO}" --state "${ITEM_STATE}" --limit 500 --json url --jq '.[].url')
  if [[ -n "${ITEM_LABEL}" ]]; then
    PR_LIST_ARGS+=(--label "${ITEM_LABEL}")
  fi

  if ! PR_URLS=$(gh pr list "${PR_LIST_ARGS[@]}" 2>&1); then
    SAFE_OUTPUT=$(sanitize_for_workflow_command "${PR_URLS}")
    echo "::error::Pull Request の取得に失敗しました: ${SAFE_OUTPUT}"
    exit 1
  fi

  if [[ -n "${PR_URLS}" ]]; then
    while IFS= read -r url; do
      [[ -z "${url}" ]] && continue

      if [[ -n "${EXISTING_ITEMS}" ]] && echo "${EXISTING_ITEMS}" | grep -Fxq "${url}"; then
        echo "  スキップ（追加済み）: ${url}"
        PR_SKIPPED=$((PR_SKIPPED + 1))
        continue
      fi

      if gh project item-add "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" --url "${url}" > /dev/null 2>&1; then
        echo "  追加: ${url}"
        PR_ADDED=$((PR_ADDED + 1))
      else
        echo "::warning::追加失敗: ${url}"
        PR_FAILED=$((PR_FAILED + 1))
      fi

      sleep 1
    done <<< "${PR_URLS}"
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

echo ""
echo "========================================="
echo "  完了サマリー"
echo "========================================="
echo "  Issue  - 追加: ${ISSUE_ADDED}, スキップ: ${ISSUE_SKIPPED}, 失敗: ${ISSUE_FAILED}"
echo "  PR     - 追加: ${PR_ADDED}, スキップ: ${PR_SKIPPED}, 失敗: ${PR_FAILED}"
echo "  合計   - 追加: ${TOTAL_ADDED}, スキップ: ${TOTAL_SKIPPED}, 失敗: ${TOTAL_FAILED}"
echo "========================================="

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
