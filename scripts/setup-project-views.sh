#!/usr/bin/env bash
set -euo pipefail

# GitHub Project View 作成スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/setup-project-views
#
# 環境変数:
#   GH_TOKEN          - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER     - Project の所有者
#   PROJECT_NUMBER    - 対象 Project の Number（数値）

# --- REST API バージョン ---

REST_API_VERSION="2026-03-10"

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_common_project_env

# --- View 定義の読み込み ---

VIEW_DEFINITIONS_FILE="${SCRIPT_DIR}/config/view-definitions.json"
if [[ ! -f "${VIEW_DEFINITIONS_FILE}" ]]; then
  echo "::error::View 定義ファイルが見つかりません: ${VIEW_DEFINITIONS_FILE}"
  exit 1
fi
VIEW_DEFINITIONS=$(cat "${VIEW_DEFINITIONS_FILE}")

# --- REST API パス構築 ---

if [[ "${OWNER_TYPE}" == "Organization" ]]; then
  VIEWS_API_PATH="orgs/${PROJECT_OWNER}/projectsV2/${PROJECT_NUMBER}/views"
elif [[ "${OWNER_TYPE}" == "User" ]]; then
  VIEWS_API_PATH="users/${PROJECT_OWNER}/projectsV2/${PROJECT_NUMBER}/views"
fi

# --- 既存 View 情報の取得（ページネーション対応） ---

echo ""
echo "Project #${PROJECT_NUMBER} の既存 View を取得しています..."

if ! ALL_VIEW_NODES=$(gh api "${VIEWS_API_PATH}" \
  -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
  --paginate \
  --jq '.[].name' 2>&1); then
  SAFE_RESULT=$(sanitize_for_workflow_command "${ALL_VIEW_NODES}")
  echo "::error::既存 View の取得に失敗しました: ${SAFE_RESULT}"
  exit 1
fi

EXISTING_VIEWS="${ALL_VIEW_NODES}"

echo ""
echo "既存の View:"
if [[ -n "${EXISTING_VIEWS}" ]]; then
  echo "${EXISTING_VIEWS}" | while IFS= read -r name; do
    echo "  - ${name}"
  done
else
  echo "  （なし）"
fi

# --- View の作成 ---

echo ""
echo "View を作成します..."

VIEW_COUNT=$(echo "${VIEW_DEFINITIONS}" | jq -r 'length')
CREATED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for i in $(seq 0 $((VIEW_COUNT - 1))); do
  VIEW_NAME=$(echo "${VIEW_DEFINITIONS}" | jq -r ".[$i].name")
  VIEW_LAYOUT=$(echo "${VIEW_DEFINITIONS}" | jq -r ".[$i].layout")
  VIEW_FILTER=$(echo "${VIEW_DEFINITIONS}" | jq -r ".[$i].filter // empty")
  VIEW_VISIBLE_FIELDS=$(echo "${VIEW_DEFINITIONS}" | jq -c ".[$i].visible_fields // empty")
  SAFE_VIEW_NAME=$(sanitize_for_workflow_command "${VIEW_NAME}")

  echo ""
  echo "[$((i + 1))/${VIEW_COUNT}] View: ${SAFE_VIEW_NAME} (${VIEW_LAYOUT})"

  # 既存 View の重複チェック（View 名は固定文字列として比較）
  if echo "${EXISTING_VIEWS}" | grep -Fqx "${VIEW_NAME}"; then
    echo "  ::notice::View '${SAFE_VIEW_NAME}' は既に存在するためスキップします。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # リクエストボディの構築
  REQUEST_BODY=$(jq -n --arg name "${VIEW_NAME}" --arg layout "${VIEW_LAYOUT}" \
    '{name: $name, layout: $layout}')

  if [[ -n "${VIEW_FILTER}" ]]; then
    REQUEST_BODY=$(echo "${REQUEST_BODY}" | jq --arg filter "${VIEW_FILTER}" '. + {filter: $filter}')
  fi

  if [[ -n "${VIEW_VISIBLE_FIELDS}" && "${VIEW_VISIBLE_FIELDS}" != "null" ]]; then
    REQUEST_BODY=$(echo "${REQUEST_BODY}" | jq --argjson visible_fields "${VIEW_VISIBLE_FIELDS}" '. + {visible_fields: $visible_fields}')
  fi

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
done

# --- サマリー出力 ---

print_summary "Owner" "${PROJECT_OWNER}" "Project" "#${PROJECT_NUMBER}" \
  "作成" "${CREATED_COUNT} 件" "スキップ" "${SKIPPED_COUNT} 件（既存）" "失敗" "${FAILED_COUNT} 件"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## View 作成完了"
    echo ""
    echo "| 項目 | 値 |"
    echo "|------|-----|"
    echo "| Project Owner | \`${PROJECT_OWNER}\` |"
    echo "| Project Number | ${PROJECT_NUMBER} |"
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
