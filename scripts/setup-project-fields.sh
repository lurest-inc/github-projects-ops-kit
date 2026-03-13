#!/usr/bin/env bash
set -euo pipefail

# GitHub Project カスタムフィールド作成スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/setup-project-fields
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

# --- フィールド定義の読み込み ---

FIELD_DEFINITIONS_FILE="${SCRIPT_DIR}/config/field-definitions.json"
if [[ ! -f "${FIELD_DEFINITIONS_FILE}" ]]; then
  echo "::error::フィールド定義ファイルが見つかりません: ${FIELD_DEFINITIONS_FILE}"
  exit 1
fi
FIELD_DEFINITIONS=$(cat "${FIELD_DEFINITIONS_FILE}")

# --- 既存フィールド情報の取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の既存フィールドを取得しています..."

FIELD_QUERY=$(cat <<GRAPHQL
query {
  ${OWNER_QUERY_FIELD}(login: "${PROJECT_OWNER}") {
    projectV2(number: ${PROJECT_NUMBER}) {
      id
      fields(first: 100) {
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

FIELD_RESULT=$(run_graphql "${FIELD_QUERY}" "Project 情報の取得")

# Project ID と既存フィールド名を一括取得
PROJECT_ID=$(echo "${FIELD_RESULT}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" '.data.[($owner)].projectV2.id // empty')
if [[ -z "${PROJECT_ID}" ]]; then
  echo "::error::Project ID を取得できませんでした。Project #${PROJECT_NUMBER} が存在するか確認してください。"
  exit 1
fi
echo "  Project ID: ${PROJECT_ID}"

EXISTING_FIELDS=$(echo "${FIELD_RESULT}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" '.data.[($owner)].projectV2.fields.nodes[].name // empty' 2>/dev/null)

echo ""
echo "既存のフィールド:"
echo "${EXISTING_FIELDS}" | while IFS= read -r name; do
  [[ -n "${name}" ]] && echo "  - ${name}"
done

# --- フィールドの作成 ---

echo ""
echo "カスタムフィールドを作成します..."

# ループ前にフィールド定義を1回の jq で事前解析する（Issue #122）
# 各行: name\tdataType\tsingleSelectOptions(JSON)
PARSED_FIELDS=$(echo "${FIELD_DEFINITIONS}" | jq -r '.[] | [.name, .dataType, (if .options then ([.options[] | {name: ., color: "GRAY", description: ""}] | tojson) else "" end)] | @tsv')
FIELD_COUNT=$(echo "${PARSED_FIELDS}" | wc -l | tr -d ' ')
CREATED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

FIELD_INDEX=0
while IFS=$'\t' read -r FIELD_NAME FIELD_DATA_TYPE SINGLE_SELECT_OPTIONS; do
  FIELD_INDEX=$((FIELD_INDEX + 1))
  SAFE_FIELD_NAME=$(sanitize_for_workflow_command "${FIELD_NAME}")

  echo ""
  echo "[${FIELD_INDEX}/${FIELD_COUNT}] フィールド: ${SAFE_FIELD_NAME} (${FIELD_DATA_TYPE})"

  # 既存フィールドの重複チェック（フィールド名は固定文字列として比較）
  if echo "${EXISTING_FIELDS}" | grep -Fqx "${FIELD_NAME}"; then
    echo "  ::notice::フィールド '${SAFE_FIELD_NAME}' は既に存在するためスキップします。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # GraphQL mutation によるフィールド作成
  # gh project field-create は gh CLI v2.88.1 で User オーナーに対して
  # "unknown owner type" エラーを起こすため、GraphQL API を直接使用する (Issue #119)
  CREATE_MUTATION=$(cat <<'GRAPHQL'
mutation($projectId: ID!, $name: String!, $dataType: ProjectV2CustomFieldType!, $singleSelectOptions: [ProjectV2SingleSelectFieldOptionInput!]) {
  createProjectV2Field(input: {
    projectId: $projectId
    dataType: $dataType
    name: $name
    singleSelectOptions: $singleSelectOptions
  }) {
    projectV2Field {
      ... on ProjectV2Field {
        id
        name
      }
      ... on ProjectV2SingleSelectField {
        id
        name
        options { id name }
      }
    }
  }
}
GRAPHQL
  )

  # 変数を JSON オブジェクトとして構築（-F フラグでは JSON 配列を正しく渡せないため: Issue #127）
  VARIABLES_JSON=$(jq -n \
    --arg projectId "${PROJECT_ID}" \
    --arg name "${FIELD_NAME}" \
    --arg dataType "${FIELD_DATA_TYPE}" \
    --argjson opts "${SINGLE_SELECT_OPTIONS:-null}" \
    '{projectId: $projectId, name: $name, dataType: $dataType}
     + (if $opts != null then {singleSelectOptions: $opts} else {} end)')

  if ! CREATE_OUTPUT=$(run_graphql_json "${CREATE_MUTATION}" "フィールド '${SAFE_FIELD_NAME}' の作成" "${VARIABLES_JSON}" 2>&1); then
    SAFE_OUTPUT=$(sanitize_for_workflow_command "${CREATE_OUTPUT}")
    echo "  ::error::フィールド '${SAFE_FIELD_NAME}' の作成に失敗しました: ${SAFE_OUTPUT}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
    continue
  fi

  echo "  ::notice::フィールド '${SAFE_FIELD_NAME}' を作成しました。"
  CREATED_COUNT=$((CREATED_COUNT + 1))
done <<< "${PARSED_FIELDS}"

# --- サマリー出力 ---

print_summary "Owner" "${PROJECT_OWNER}" "Project" "#${PROJECT_NUMBER}" \
  "作成" "${CREATED_COUNT} 件" "スキップ" "${SKIPPED_COUNT} 件（既存）" "失敗" "${FAILED_COUNT} 件"

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
