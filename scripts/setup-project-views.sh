#!/usr/bin/env bash
set -euo pipefail

# GitHub Project View 作成スクリプト
# https://lurest-inc.github.io/github-projects-ops-kit/scripts/setup-project-views
#
# 環境変数:
#   GH_TOKEN          - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER     - Project の所有者
#   PROJECT_NUMBER    - 対象 Project の Number（数値）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_common_project_env

# --- View 定義の読み込み ---

VIEW_DEFINITIONS_FILE="${SCRIPT_DIR}/config/project-view-definitions.json"
if [[ ! -f "${VIEW_DEFINITIONS_FILE}" ]]; then
  echo "::error::View 定義ファイルが見つかりません: ${VIEW_DEFINITIONS_FILE}"
  exit 1
fi
VIEW_DEFINITIONS=$(cat "${VIEW_DEFINITIONS_FILE}")

# --- GraphQL で既存 View 情報の取得（ページネーション対応） ---

echo ""
echo "Project #${PROJECT_NUMBER} の既存 View を取得しています..."

PROJECT_ID=""
EXISTING_VIEWS=""

VIEW_QUERY_TEMPLATE=$(cat <<'GRAPHQL'
query($login: String!, $number: Int!, $after: String) {
  __OWNER_FIELD__(login: $login) {
    projectV2(number: $number) {
      id
      views(first: 100, after: $after) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          name
        }
      }
    }
  }
}
GRAPHQL
)
VIEW_QUERY=$(apply_owner_field "${VIEW_QUERY_TEMPLATE}")

_on_view_page() {
  local result="$1"

  if [[ -z "${PROJECT_ID}" ]]; then
    PROJECT_ID=$(echo "${result}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" '.data.[($owner)].projectV2.id // empty')
    if [[ -z "${PROJECT_ID}" ]]; then
      echo "::error::Project ID を取得できませんでした。Project #${PROJECT_NUMBER} が存在するか確認してください。"
      exit 1
    fi
    echo "  Project ID: ${PROJECT_ID}"
  fi

  local page_views
  page_views=$(echo "${result}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" '.data.[($owner)].projectV2.views.nodes[].name // empty' 2>/dev/null)
  if [[ -n "${page_views}" ]]; then
    if [[ -n "${EXISTING_VIEWS}" ]]; then
      EXISTING_VIEWS+=$'\n'"${page_views}"
    else
      EXISTING_VIEWS="${page_views}"
    fi
  fi
}

VARIABLES_JSON=$(jq -n --arg login "${PROJECT_OWNER}" --argjson number "${PROJECT_NUMBER}" '{login: $login, number: $number}')
run_graphql_paginated "${VIEW_QUERY}" "既存 View の取得" "${VARIABLES_JSON}" \
  '.data.[($owner)].projectV2.views.pageInfo' _on_view_page

echo ""
echo "既存の View:"
if [[ -n "${EXISTING_VIEWS}" ]]; then
  echo "${EXISTING_VIEWS}" | while IFS= read -r name; do
    echo "  - ${name}"
  done
else
  echo "  （なし）"
fi

# --- REST API パス構築 ---

if [[ "${OWNER_TYPE}" == "Organization" ]]; then
  VIEWS_API_PATH="orgs/${PROJECT_OWNER}/projectsV2/${PROJECT_NUMBER}/views"
elif [[ "${OWNER_TYPE}" == "User" ]]; then
  VIEWS_API_PATH="users/${PROJECT_OWNER}/projectsV2/${PROJECT_NUMBER}/views"
fi

# --- View の作成 ---

echo ""
echo "View を作成します..."

# ループ前に View 定義を 1 回の jq で事前解析する
# 各行: name\tlayout\tfilter\tvisible_fields(JSON)
VIEW_COUNT=$(echo "${VIEW_DEFINITIONS}" | jq -r 'length')
if [[ "${VIEW_COUNT}" -eq 0 ]]; then
  echo "  View 定義が空のため、処理をスキップします。"
  print_summary "作成" "0 件" "スキップ" "0 件（既存）" "失敗" "0 件"
  exit 0
fi
PARSED_VIEWS=$(echo "${VIEW_DEFINITIONS}" | jq -r '.[] | [.name, .layout, (.filter // ""), (if .visible_fields then (.visible_fields | tojson) else "" end)] | @tsv')
CREATED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

VIEW_INDEX=0
while IFS=$'\t' read -r VIEW_NAME VIEW_LAYOUT VIEW_FILTER VIEW_VISIBLE_FIELDS; do
  VIEW_INDEX=$((VIEW_INDEX + 1))
  SAFE_VIEW_NAME=$(sanitize_for_workflow_command "${VIEW_NAME}")

  echo ""
  echo "[${VIEW_INDEX}/${VIEW_COUNT}] View: ${SAFE_VIEW_NAME} (${VIEW_LAYOUT})"

  # 既存 View の重複チェック（View 名は固定文字列として比較）
  if echo "${EXISTING_VIEWS}" | grep -Fqx "${VIEW_NAME}"; then
    echo "  ::notice::View '${SAFE_VIEW_NAME}' は既に存在するためスキップします。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # リクエストボディの構築（単一 jq 呼び出し）
  vf_arg="${VIEW_VISIBLE_FIELDS:-null}"
  if [[ "${vf_arg}" == "" ]]; then
    vf_arg="null"
  fi
  REQUEST_BODY=$(jq -n \
    --arg name "${VIEW_NAME}" \
    --arg layout "${VIEW_LAYOUT}" \
    --arg filter "${VIEW_FILTER}" \
    --argjson visible_fields "${vf_arg}" \
    '{name: $name, layout: $layout}
     + (if $filter != "" then {filter: $filter} else {} end)
     + (if $visible_fields != null then {visible_fields: $visible_fields} else {} end)'
  )

  # REST API で View を作成
  if ! CREATE_RESULT=$(gh api "${VIEWS_API_PATH}" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --method POST \
    --input - <<< "${REQUEST_BODY}" 2>&1); then
    SAFE_RESULT=$(sanitize_for_workflow_command "${CREATE_RESULT}")
    echo "  ::error::View '${SAFE_VIEW_NAME}' の作成に失敗しました: ${SAFE_RESULT}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  CREATED_VIEW_ID=$(echo "${CREATE_RESULT}" | jq -r '.id // empty')
  echo "  ::notice::View '${SAFE_VIEW_NAME}' を作成しました。(ID: ${CREATED_VIEW_ID})"
  CREATED_COUNT=$((CREATED_COUNT + 1))

  # 作成した View 名を既存リストに追加（後続の重複チェック用）
  EXISTING_VIEWS+=$'\n'"${VIEW_NAME}"
done <<< "${PARSED_VIEWS}"

# --- サマリー出力 ---

print_summary "作成" "${CREATED_COUNT} 件" "スキップ" "${SKIPPED_COUNT} 件（既存）" "失敗" "${FAILED_COUNT} 件"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## View 作成完了"
    echo ""
    echo "| 項目 | 値 |"
    echo "|------|-----|"
    echo "| 作成 | ${CREATED_COUNT} 件 |"
    echo "| スキップ | ${SKIPPED_COUNT} 件（既存） |"
    echo "| 失敗 | ${FAILED_COUNT} 件 |"
    echo ""
    echo "### View 一覧"
    echo ""
    echo "| View 名 | レイアウト | フィルタ |"
    echo "|---------|-----------|---------|"
    echo "${VIEW_DEFINITIONS}" | jq -r '.[] | "| \(.name) | \(.layout) | \(.filter // "-") |"'
  } >> "${GITHUB_STEP_SUMMARY}"
fi

if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  echo ""
  echo "::error::${FAILED_COUNT} 件の View 作成に失敗しました。上記のエラーを確認してください。"
  exit 1
fi

echo ""
echo "セットアップが完了しました。"
