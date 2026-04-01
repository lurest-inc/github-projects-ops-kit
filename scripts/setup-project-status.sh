#!/usr/bin/env bash
set -euo pipefail

# GitHub Project ステータスカラム設定スクリプト
# https://lurest-inc.github.io/github-projects-ops-kit/scripts/setup-project-status
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

STATUS_OPTIONS=$(load_config_file "${SCRIPT_DIR}/config/project-status-options.json" "ステータスカラム定義ファイル")

# --- Project ID と Status フィールド情報の取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の Status フィールドを取得しています..."

FIELD_QUERY_TEMPLATE=$(cat <<'GRAPHQL'
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
FIELD_QUERY=$(apply_owner_field "${FIELD_QUERY_TEMPLATE}")

VARIABLES_JSON=$(jq -n \
  --arg login "${PROJECT_OWNER}" \
  --argjson number "${PROJECT_NUMBER}" \
  '{login: $login, number: $number}')

FIELD_RESULT=$(run_graphql_json "${FIELD_QUERY}" "Project 情報の取得" "${VARIABLES_JSON}")

# Project ID と Status フィールド ID を一括取得
IFS=$'\t' read -r PROJECT_ID STATUS_FIELD_ID < <(
  echo "${FIELD_RESULT}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" '
    .data.[($owner)].projectV2 as $proj |
    [($proj.id // ""), ([$proj.fields.nodes[] | select(.name == "Status") | .id] | first // "")] | @tsv
  '
)
if [[ -z "${PROJECT_ID}" ]]; then
  echo "::error::Project ID を取得できませんでした。Project #${PROJECT_NUMBER} が存在するか確認してください。"
  exit 1
fi
echo "  Project ID: ${PROJECT_ID}"
if [[ -z "${STATUS_FIELD_ID}" ]]; then
  echo "::error::Status フィールドが見つかりませんでした。"
  echo "::error::Project にビルトインの Status フィールドが存在するか確認してください。"
  exit 1
fi
echo "  Status Field ID: ${STATUS_FIELD_ID}"

# 現在のステータスカラムを表示
echo ""
echo "現在のステータスカラム:"
echo "${FIELD_RESULT}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" '.data.[($owner)].projectV2.fields.nodes[] | select(.name == "Status") | .options[] | "  - \(.name) (\(.color))"' 2>/dev/null || echo "  （取得できませんでした）"

# --- ステータスカラムの更新 ---

echo ""
echo "ステータスカラムを更新します..."

# カラム名を表示
echo ""
echo "設定するステータスカラム:"
echo "${STATUS_OPTIONS}" | jq -r '.[] | "  - \(.name) (\(.color))\(if .description then ": \(.description)" else "" end)"'

# GraphQL mutation 用の singleSelectOptions を構築
SINGLE_SELECT_OPTIONS=$(echo "${STATUS_OPTIONS}" | jq -c '[.[] | {name: .name, color: .color, description: (.description // "")}]')

UPDATE_MUTATION=$(cat <<'GRAPHQL'
mutation($fieldId: ID!, $singleSelectOptions: [ProjectV2SingleSelectFieldOptionInput!]!) {
  updateProjectV2Field(input: {
    fieldId: $fieldId
    singleSelectOptions: $singleSelectOptions
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

# 変数を JSON オブジェクトとして構築（-F フラグでは JSON 配列を正しく渡せないため: Issue #127）
VARIABLES_JSON=$(jq -n \
  --arg fieldId "${STATUS_FIELD_ID}" \
  --argjson singleSelectOptions "${SINGLE_SELECT_OPTIONS}" \
  '{fieldId: $fieldId, singleSelectOptions: $singleSelectOptions}')

UPDATE_RESULT=$(run_graphql_json "${UPDATE_MUTATION}" "ステータスカラムの更新" "${VARIABLES_JSON}")

echo ""
echo "::notice::ステータスカラムの更新に成功しました。"

# 更新後のステータスカラムを表示
echo ""
echo "更新後のステータスカラム:"
echo "${UPDATE_RESULT}" | jq -r '.data.updateProjectV2Field.projectV2Field.options[] | "  - \(.name) (\(.color)): \(.description)"' 2>/dev/null || echo "  （取得できませんでした）"

# --- サマリー出力 ---

COLUMN_NAMES=$(echo "${STATUS_OPTIONS}" | jq -r '[.[].name] | join(" → ")')

write_workflow_summary <<MD
## ステータスカラム設定完了

| 項目 | 値 |
|------|-----|
| カラム構成 | ${COLUMN_NAMES} |
MD

print_summary "カラム" "${COLUMN_NAMES}"

echo ""
echo "セットアップが完了しました。"
