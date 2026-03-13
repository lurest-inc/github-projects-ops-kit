#!/usr/bin/env bash
set -euo pipefail

# GitHub Project ステータスカラム設定スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/setup-project-status
#
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number（数値）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_common_project_env

# --- ステータスカラム定義の読み込み ---

STATUS_OPTIONS_FILE="${SCRIPT_DIR}/config/status-options.json"
if [[ ! -f "${STATUS_OPTIONS_FILE}" ]]; then
  echo "::error::ステータスカラム定義ファイルが見つかりません: ${STATUS_OPTIONS_FILE}"
  exit 1
fi
STATUS_OPTIONS=$(cat "${STATUS_OPTIONS_FILE}")

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

FIELD_RESULT=$(run_graphql "${FIELD_QUERY}" "Project 情報の取得")

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

UPDATE_RESULT=$(run_graphql "${UPDATE_MUTATION}" "ステータスカラムの更新")

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

print_summary "Owner" "${PROJECT_OWNER}" "Project" "#${PROJECT_NUMBER}" "カラム" "${COLUMN_NAMES}"

echo ""
echo "セットアップが完了しました。"
