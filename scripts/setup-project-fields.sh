#!/usr/bin/env bash
set -euo pipefail

# GitHub Project カスタムフィールド作成スクリプト
# 環境変数:
#   GH_TOKEN          - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER     - Project の所有者
#   PROJECT_NUMBER    - 対象 Project の Number（数値）
#   FIELD_DEFINITIONS - フィールド定義（JSON配列）
#                       例: [{"name":"Priority","dataType":"SINGLE_SELECT","options":["P0","P1","P2","P3"]}]
#                       対応データ型: TEXT, SINGLE_SELECT, DATE, NUMBER

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

if [[ -z "${FIELD_DEFINITIONS:-}" ]]; then
  echo "::error::FIELD_DEFINITIONS が指定されていません。JSON 配列で指定してください。"
  echo "::error::例: [{\"name\":\"Priority\",\"dataType\":\"SINGLE_SELECT\",\"options\":[\"P0\",\"P1\",\"P2\",\"P3\"]}]"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "::error::jq がインストールされていません。JSON の解析に必要です。"
  exit 1
fi

# FIELD_DEFINITIONS の JSON バリデーション
if ! echo "${FIELD_DEFINITIONS}" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
  echo "::error::FIELD_DEFINITIONS が有効な JSON 配列ではありません。"
  exit 1
fi

# 各要素に必須フィールド（name, dataType）が存在し、name が非空の文字列であるか確認
if ! echo "${FIELD_DEFINITIONS}" | jq -e 'all(has("name") and has("dataType") and (.name | type == "string" and length > 0) and (.dataType | type == "string"))' >/dev/null 2>&1; then
  echo "::error::FIELD_DEFINITIONS の各要素には name（非空の文字列）と dataType が必須です。"
  exit 1
fi

# dataType の値を検証
VALID_TYPES='["TEXT","SINGLE_SELECT","DATE","NUMBER"]'
if ! echo "${FIELD_DEFINITIONS}" | jq -e --argjson valid "${VALID_TYPES}" 'all(.dataType as $t | $valid | index($t) != null)' >/dev/null 2>&1; then
  echo "::error::dataType には TEXT, SINGLE_SELECT, DATE, NUMBER のいずれかを指定してください。"
  exit 1
fi

# SINGLE_SELECT の場合は options が必須（各要素が非空の文字列であること）
if ! echo "${FIELD_DEFINITIONS}" | jq -e 'all(if .dataType == "SINGLE_SELECT" then (.options | type == "array" and length > 0 and all(type == "string" and length > 0)) else true end)' >/dev/null 2>&1; then
  echo "::error::dataType が SINGLE_SELECT のフィールドには options（配列）が必須です。"
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
