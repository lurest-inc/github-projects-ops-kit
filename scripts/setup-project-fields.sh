#!/usr/bin/env bash
set -euo pipefail

# GitHub Project カスタムフィールド作成スクリプト
# 環境変数:
#   GH_TOKEN          - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER     - Project の所有者
#   PROJECT_NUMBER    - 対象 Project の Number（数値）

# --- フィールド定義 ---

FIELD_DEFINITIONS='[
  {"name": "Priority", "dataType": "SINGLE_SELECT", "options": ["P0", "P1", "P2", "P3"]},
  {"name": "Estimate", "dataType": "SINGLE_SELECT", "options": ["XS", "S", "M", "L", "XL"]},
  {"name": "Category", "dataType": "SINGLE_SELECT", "options": ["Bug", "Feature", "Chore", "Spike"]},
  {"name": "Due Date", "dataType": "DATE"}
]'

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
require_env "PROJECT_OWNER"
require_env "PROJECT_NUMBER"
validate_project_number
require_command "gh" "GitHub CLI (gh) が必要です。PATH を確認してください。"
require_command "jq" "JSON の解析に必要です。"

# --- オーナータイプ判定 ---

detect_owner_type

# --- 既存フィールド情報の取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の既存フィールドを取得しています..."

FIELD_QUERY=$(cat <<GRAPHQL
query {
  ${OWNER_QUERY_FIELD}(login: "${PROJECT_OWNER}") {
    projectV2(number: ${PROJECT_NUMBER}) {
      id
      fields(first: 250) {
        nodes {
          ... on ProjectV2Field {
            id
            name
            dataType
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            dataType
            options {
              id
              name
            }
          }
          ... on ProjectV2IterationField {
            id
            name
            dataType
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

# 既存フィールド名のリストを取得
EXISTING_FIELDS=$(echo "${FIELD_RESULT}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.fields.nodes[].name // empty" 2>/dev/null)

echo ""
echo "既存のフィールド:"
echo "${EXISTING_FIELDS}" | while IFS= read -r name; do
  [[ -n "${name}" ]] && echo "  - ${name}"
done

# --- フィールドの作成 ---

echo ""
echo "カスタムフィールドを作成します..."

FIELD_COUNT=$(echo "${FIELD_DEFINITIONS}" | jq -r 'length')
CREATED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for i in $(seq 0 $((FIELD_COUNT - 1))); do
  FIELD_NAME=$(echo "${FIELD_DEFINITIONS}" | jq -r ".[$i].name")
  FIELD_DATA_TYPE=$(echo "${FIELD_DEFINITIONS}" | jq -r ".[$i].dataType")
  SAFE_FIELD_NAME=$(sanitize_for_workflow_command "${FIELD_NAME}")

  echo ""
  echo "[$((i + 1))/${FIELD_COUNT}] フィールド: ${SAFE_FIELD_NAME} (${FIELD_DATA_TYPE})"

  # 既存フィールドの重複チェック（フィールド名は固定文字列として比較）
  if echo "${EXISTING_FIELDS}" | grep -Fqx "${FIELD_NAME}"; then
    echo "  ::notice::フィールド '${SAFE_FIELD_NAME}' は既に存在するためスキップします。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # gh project field-create コマンドの構築
  CREATE_ARGS=("project" "field-create" "${PROJECT_NUMBER}" "--owner" "${PROJECT_OWNER}" "--name" "${FIELD_NAME}" "--data-type" "${FIELD_DATA_TYPE}")

  # SINGLE_SELECT の場合は選択肢を追加
  if [[ "${FIELD_DATA_TYPE}" == "SINGLE_SELECT" ]]; then
    OPTIONS=$(echo "${FIELD_DEFINITIONS}" | jq -r ".[$i].options[]")
    while IFS= read -r option; do
      CREATE_ARGS+=("--single-select-options" "${option}")
    done <<< "${OPTIONS}"
  fi

  if ! CREATE_OUTPUT=$(gh "${CREATE_ARGS[@]}" 2>&1); then
    SAFE_OUTPUT=$(sanitize_for_workflow_command "${CREATE_OUTPUT}")
    echo "  ::error::フィールド '${SAFE_FIELD_NAME}' の作成に失敗しました: ${SAFE_OUTPUT}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  echo "  ::notice::フィールド '${SAFE_FIELD_NAME}' を作成しました。"
  CREATED_COUNT=$((CREATED_COUNT + 1))
done

# --- サマリー出力 ---

echo ""
echo "========================================="
echo "  完了サマリー"
echo "========================================="
echo "  Owner:    ${PROJECT_OWNER}"
echo "  Project:  #${PROJECT_NUMBER}"
echo "  作成:     ${CREATED_COUNT} 件"
echo "  スキップ: ${SKIPPED_COUNT} 件（既存）"
echo "  失敗:     ${FAILED_COUNT} 件"
echo "========================================="

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## カスタムフィールド設定完了"
    echo ""
    echo "| 項目 | 値 |"
    echo "|------|-----|"
    echo "| Project Owner | \`${PROJECT_OWNER}\` |"
    echo "| Project Number | ${PROJECT_NUMBER} |"
    echo "| 作成 | ${CREATED_COUNT} 件 |"
    echo "| スキップ | ${SKIPPED_COUNT} 件（既存） |"
    echo "| 失敗 | ${FAILED_COUNT} 件 |"
    echo ""
    echo "### フィールド一覧"
    echo ""
    echo "| フィールド名 | データ型 | 選択肢 |"
    echo "|-------------|---------|--------|"
    echo "${FIELD_DEFINITIONS}" | jq -r '.[] | "| \(.name) | \(.dataType) | \(if .options then (.options | join(", ")) else "-" end) |"'
  } >> "${GITHUB_STEP_SUMMARY}"
fi

if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  echo ""
  echo "::error::${FAILED_COUNT} 件のフィールド作成に失敗しました。上記のエラーを確認してください。"
  exit 1
fi

echo ""
echo "セットアップが完了しました。"
