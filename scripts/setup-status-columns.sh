#!/usr/bin/env bash
set -euo pipefail

# GitHub Project ステータスカラム設定スクリプト
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number（数値）

# --- ステータスカラム定義 ---

STATUS_OPTIONS='[
  {"name": "Todo", "color": "BLUE", "description": "未着手"},
  {"name": "In Progress", "color": "YELLOW", "description": "作業中"},
  {"name": "Done", "color": "GREEN", "description": "完了"}
]'

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
require_env "PROJECT_OWNER"
require_env "PROJECT_NUMBER"
validate_project_number
require_command "gh" "GitHub CLI (gh) が必要です。"
require_command "jq" "JSON の解析に必要です。"

# --- オーナータイプ判定 ---

detect_owner_type

# --- Project ID と Status フィールド情報の取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の Status フィールドを取得しています..."

FIELD_QUERY=$(cat <<GRAPHQL
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
              color
              description
            }
          }
        }
      }
    }
  }
}
GRAPHQL
)

if ! FIELD_RESULT=$(gh api graphql -f query="${FIELD_QUERY}" 2>&1); then
  SAFE_RESULT=$(sanitize_for_workflow_command "${FIELD_RESULT}")
  echo "::error::Project 情報の取得に失敗しました: ${SAFE_RESULT}"
  echo ""
  echo "考えられる原因:"
  echo "  - PROJECT_NUMBER が正しくない"
  echo "  - PAT に Projects > Read and write 権限が付与されていない"
  echo "  - ネットワークエラー"
  exit 1
fi

# GraphQL 応答内の errors チェック
if echo "${FIELD_RESULT}" | jq -e '.errors and (.errors | length > 0)' >/dev/null 2>&1; then
  SAFE_RESULT=$(sanitize_for_workflow_command "${FIELD_RESULT}")
  echo "::error::Project 情報の取得中に GraphQL エラーが発生しました: ${SAFE_RESULT}"
  echo ""
  echo "GraphQL errors:"
  echo "${FIELD_RESULT}" | jq '.errors' || true
  exit 1
fi

# Project ID の取得
PROJECT_ID=$(echo "${FIELD_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.id // empty")
if [[ -z "${PROJECT_ID}" ]]; then
  echo "::error::Project ID を取得できませんでした。Project #${PROJECT_NUMBER} が存在するか確認してください。"
  exit 1
fi
echo "  Project ID: ${PROJECT_ID}"

# Status フィールドの検索
STATUS_FIELD_ID=$(echo "${FIELD_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.fields.nodes[] | select(.name == \"Status\") | .id // empty")
if [[ -z "${STATUS_FIELD_ID}" ]]; then
  echo "::error::Status フィールドが見つかりませんでした。"
  echo "::error::Project にビルトインの Status フィールドが存在するか確認してください。"
  exit 1
fi
echo "  Status Field ID: ${STATUS_FIELD_ID}"

# 現在のステータスカラムを表示
echo ""
echo "現在のステータスカラム:"
echo "${FIELD_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.fields.nodes[] | select(.name == \"Status\") | .options[] | \"  - \(.name) (\(.color))\"" 2>/dev/null || echo "  （取得できませんでした）"

# --- ステータスカラムの更新 ---

echo ""
echo "ステータスカラムを更新します..."

# カラム名を表示
echo ""
echo "設定するステータスカラム:"
echo "${STATUS_OPTIONS}" | jq -r '.[] | "  - \(.name) (\(.color))\(if .description then ": \(.description)" else "" end)"'

# GraphQL mutation 用の singleSelectOptions を構築
SINGLE_SELECT_OPTIONS=$(echo "${STATUS_OPTIONS}" | jq -c '[.[] | {name: .name, color: .color, description: (.description // "")}]')

UPDATE_MUTATION=$(cat <<GRAPHQL
mutation {
  updateProjectV2Field(input: {
    projectId: "${PROJECT_ID}"
    fieldId: "${STATUS_FIELD_ID}"
    singleSelectOptions: ${SINGLE_SELECT_OPTIONS}
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        id
        name
        options {
          id
          name
          color
          description
        }
      }
    }
  }
}
GRAPHQL
)

if ! UPDATE_RESULT=$(gh api graphql -f query="${UPDATE_MUTATION}" 2>&1); then
  SAFE_RESULT=$(sanitize_for_workflow_command "${UPDATE_RESULT}")
  echo "::error::ステータスカラムの更新に失敗しました: ${SAFE_RESULT}"
  echo ""
  echo "考えられる原因:"
  echo "  - PAT に Projects > Read and write 権限が付与されていない"
  echo "  - GraphQL API のレート制限に達した"
  echo "  - ネットワークエラー"
  exit 1
fi

# エラーチェック
if echo "${UPDATE_RESULT}" | jq -e '.errors and (.errors | length > 0)' >/dev/null 2>&1; then
  SAFE_ERRORS=$(sanitize_for_workflow_command "$(echo "${UPDATE_RESULT}" | jq -c '.errors')")
  echo "::error::GraphQL エラーが発生しました: ${SAFE_ERRORS}"
  exit 1
fi

echo ""
echo "::notice::ステータスカラムの更新に成功しました。"

# 更新後のステータスカラムを表示
echo ""
echo "更新後のステータスカラム:"
echo "${UPDATE_RESULT}" | jq -r '.data.updateProjectV2Field.projectV2Field.options[] | "  - \(.name) (\(.color)): \(.description)"' 2>/dev/null || echo "  （取得できませんでした）"

# --- サマリー出力 ---

COLUMN_NAMES=$(echo "${STATUS_OPTIONS}" | jq -r '[.[].name] | join(" → ")')

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## ステータスカラム設定完了"
    echo ""
    echo "| 項目 | 値 |"
    echo "|------|-----|"
    echo "| Project Owner | \`${PROJECT_OWNER}\` |"
    echo "| Project Number | ${PROJECT_NUMBER} |"
    echo "| カラム構成 | ${COLUMN_NAMES} |"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

echo ""
echo "========================================="
echo "  完了サマリー"
echo "========================================="
echo "  Owner:  ${PROJECT_OWNER}"
echo "  Project: #${PROJECT_NUMBER}"
echo "  カラム: ${COLUMN_NAMES}"
echo "========================================="
echo ""
echo "セットアップが完了しました。"
