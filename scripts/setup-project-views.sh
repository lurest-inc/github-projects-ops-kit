#!/usr/bin/env bash
set -euo pipefail

# GitHub Project View 作成スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/setup-project-views
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

VIEW_DEFINITIONS_FILE="${SCRIPT_DIR}/config/view-definitions.json"
if [[ ! -f "${VIEW_DEFINITIONS_FILE}" ]]; then
  echo "::error::View 定義ファイルが見つかりません: ${VIEW_DEFINITIONS_FILE}"
  exit 1
fi
VIEW_DEFINITIONS=$(cat "${VIEW_DEFINITIONS_FILE}")

# --- GraphQL で既存 View 情報の取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の既存 View を取得しています..."

VIEW_QUERY=$(cat <<GRAPHQL
query {
  ${OWNER_QUERY_FIELD}(login: "${PROJECT_OWNER}") {
    projectV2(number: ${PROJECT_NUMBER}) {
      id
      views(first: 100) {
        nodes {
          id
          name
          layout
        }
      }
    }
  }
}
GRAPHQL
)

VIEW_RESULT=$(run_graphql "${VIEW_QUERY}" "既存 View の取得")

# Project ID を取得
PROJECT_ID=$(echo "${VIEW_RESULT}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" '.data.[($owner)].projectV2.id // empty')
if [[ -z "${PROJECT_ID}" ]]; then
  echo "::error::Project ID を取得できませんでした。Project #${PROJECT_NUMBER} が存在するか確認してください。"
  exit 1
fi
echo "  Project ID: ${PROJECT_ID}"

EXISTING_VIEWS=$(echo "${VIEW_RESULT}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" '.data.[($owner)].projectV2.views.nodes[].name // empty' 2>/dev/null)

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

# view-definitions.json の layout 値を GraphQL の ProjectV2ViewLayout enum にマッピング
map_layout_to_graphql() {
  local layout="$1"
  case "${layout}" in
    table)       echo "TABLE_LAYOUT" ;;
    board)       echo "BOARD_LAYOUT" ;;
    roadmap)     echo "ROADMAP_LAYOUT" ;;
    *)           echo "${layout}" ;;
  esac
}

VIEW_COUNT=$(echo "${VIEW_DEFINITIONS}" | jq -r 'length')
CREATED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for i in $(seq 0 $((VIEW_COUNT - 1))); do
  IFS=$'\t' read -r VIEW_NAME VIEW_LAYOUT < <(echo "${VIEW_DEFINITIONS}" | jq -r ".[$i] | [.name, .layout] | @tsv")
  SAFE_VIEW_NAME=$(sanitize_for_workflow_command "${VIEW_NAME}")
  GRAPHQL_LAYOUT=$(map_layout_to_graphql "${VIEW_LAYOUT}")

  echo ""
  echo "[$((i + 1))/${VIEW_COUNT}] View: ${SAFE_VIEW_NAME} (${VIEW_LAYOUT} → ${GRAPHQL_LAYOUT})"

  # 既存 View の重複チェック（View 名は固定文字列として比較）
  if echo "${EXISTING_VIEWS}" | grep -Fqx "${VIEW_NAME}"; then
    echo "  ::notice::View '${SAFE_VIEW_NAME}' は既に存在するためスキップします。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # GraphQL mutation で View を作成
  CREATE_MUTATION=$(cat <<'GRAPHQL'
mutation($projectId: ID!, $name: String!, $layout: ProjectV2ViewLayout) {
  createProjectV2View(input: {
    projectId: $projectId
    name: $name
    layout: $layout
  }) {
    projectV2View {
      id
      name
      layout
    }
  }
}
GRAPHQL
  )

  if ! CREATE_RESULT=$(run_graphql "${CREATE_MUTATION}" "View '${SAFE_VIEW_NAME}' の作成" \
    -f "projectId=${PROJECT_ID}" \
    -f "name=${VIEW_NAME}" \
    -f "layout=${GRAPHQL_LAYOUT}" 2>&1); then
    SAFE_RESULT=$(sanitize_for_workflow_command "${CREATE_RESULT}")
    echo "  ::error::View '${SAFE_VIEW_NAME}' の作成に失敗しました: ${SAFE_RESULT}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  CREATED_VIEW_ID=$(echo "${CREATE_RESULT}" | jq -r '.data.createProjectV2View.projectV2View.id // empty')
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
