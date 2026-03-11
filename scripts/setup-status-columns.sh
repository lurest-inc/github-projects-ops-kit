#!/usr/bin/env bash
set -euo pipefail

# GitHub Project ステータスカラム設定スクリプト
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number（数値）
#   STATUS_OPTIONS - ステータスカラム定義（JSON配列）
#                    例: [{"name":"Todo","color":"BLUE","description":"未着手"}]
#                    対応カラー: GRAY, BLUE, GREEN, YELLOW, ORANGE, RED, PINK, PURPLE

# --- ヘルパー関数 ---

# GitHub Actions ワークフローコマンドインジェクションを防ぐためのサニタイズ関数
sanitize_for_workflow_command() {
  local value="$1"
  value="${value//'%'/'%25'}"
  value="${value//$'\n'/'%0A'}"
  value="${value//$'\r'/'%0D'}"
  echo "${value}"
}

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

if ! [[ "${PROJECT_NUMBER}" =~ ^[0-9]+$ ]]; then
  SAFE_PROJECT_NUMBER=$(sanitize_for_workflow_command "${PROJECT_NUMBER}")
  echo "::error::PROJECT_NUMBER の値が不正です: ${SAFE_PROJECT_NUMBER}（数値のみを指定してください）"
  exit 1
fi

if [[ -z "${STATUS_OPTIONS:-}" ]]; then
  echo "::error::STATUS_OPTIONS が指定されていません。JSON 配列で指定してください。"
  echo "::error::例: [{\"name\":\"Todo\",\"color\":\"BLUE\",\"description\":\"未着手\"}]"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "::error::jq がインストールされていません。JSON の解析に必要です。"
  exit 1
fi

# STATUS_OPTIONS の JSON バリデーション
if ! echo "${STATUS_OPTIONS}" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
  echo "::error::STATUS_OPTIONS が有効な JSON 配列ではありません。"
  exit 1
fi

# 各要素に必須フィールド（name, color）が存在するか確認
if ! echo "${STATUS_OPTIONS}" | jq -e 'all(has("name") and has("color"))' >/dev/null 2>&1; then
  echo "::error::STATUS_OPTIONS の各要素には name と color が必須です。"
  exit 1
fi

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
