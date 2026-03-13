#!/usr/bin/env bash
set -euo pipefail

# GitHub Project セットアップスクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/setup-github-project
#
# 環境変数:
#   GH_TOKEN           - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER      - Project を作成する Owner
#   PROJECT_TITLE      - 作成する Project のタイトル
#   PROJECT_VISIBILITY - Project の公開範囲（PUBLIC / PRIVATE、デフォルト: PRIVATE）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
require_env "PROJECT_OWNER"
require_env "PROJECT_TITLE"
require_command "gh" "GitHub CLI (gh) が必要です。"
require_command "jq" "Project 情報の抽出に必要です。"

PROJECT_VISIBILITY="${PROJECT_VISIBILITY:-PRIVATE}"
validate_enum "PROJECT_VISIBILITY" "${PROJECT_VISIBILITY}" "PUBLIC" "PRIVATE"

# --- オーナータイプ判定 ---

detect_owner_type

if [[ "${OWNER_TYPE}" == "User" ]]; then
  echo ""
  echo "個人アカウントとして検出されました。"
  echo "必要な PAT 権限: Account permissions > Projects > Read and write"
elif [[ "${OWNER_TYPE}" == "Organization" ]]; then
  echo ""
  echo "Organization として検出されました。"
  echo "必要な PAT 権限: Organization permissions > Projects > Read and write"
fi

echo ""

# --- 既存 Project チェック ---

echo "同名の Project が既に存在するか確認します..."

EXISTING_PROJECT=""
HAS_NEXT_PAGE="true"
END_CURSOR=""

while [[ "${HAS_NEXT_PAGE}" == "true" ]]; do
  AFTER_CLAUSE=""
  if [[ -n "${END_CURSOR}" ]]; then
    AFTER_CLAUSE=", after: \"${END_CURSOR}\""
  fi

  EXISTING_QUERY="query {
    ${OWNER_QUERY_FIELD}(login: \"${PROJECT_OWNER}\") {
      projectsV2(first: 100${AFTER_CLAUSE}) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes { title number url }
      }
    }
  }"
  EXISTING_PROJECTS=$(run_graphql "${EXISTING_QUERY}" "既存 Project の一覧取得")

  EXISTING_PROJECT=$(echo "${EXISTING_PROJECTS}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" --arg title "${PROJECT_TITLE}" '[.data.[($owner)].projectsV2.nodes[] | select(.title == $title)] | first // ""')

  if [[ -n "${EXISTING_PROJECT}" ]]; then
    break
  fi

  HAS_NEXT_PAGE=$(echo "${EXISTING_PROJECTS}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectsV2.pageInfo.hasNextPage" 2>/dev/null || echo "false")
  END_CURSOR=$(echo "${EXISTING_PROJECTS}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectsV2.pageInfo.endCursor // empty" 2>/dev/null || true)
done

if [[ -n "${EXISTING_PROJECT}" ]]; then
  EXISTING_NUMBER=$(echo "${EXISTING_PROJECT}" | jq -r '.number // empty')
  EXISTING_URL=$(echo "${EXISTING_PROJECT}" | jq -r '.url // empty')
  echo "::warning::同名の Project が既に存在します。"
  echo "::warning::Project Number: ${EXISTING_NUMBER}"
  echo "::warning::Project URL: ${EXISTING_URL}"
  echo ""
  echo "重複作成を防止するため、スクリプトを終了します。"
  echo "既存 Project を削除してから再実行するか、タイトルを変更してください。"
  exit 0
fi

echo "同名の Project は見つかりませんでした。作成を続行します。"
echo ""

# --- Project 作成 ---

echo "GitHub Project を作成します..."
echo "  Owner:      ${PROJECT_OWNER}"
echo "  Title:      ${PROJECT_TITLE}"
echo "  Type:       ${OWNER_TYPE}"
echo "  Visibility: ${PROJECT_VISIBILITY}"

if ! OUTPUT=$(gh project create --title "${PROJECT_TITLE}" --owner "${PROJECT_OWNER}" --format json 2>&1); then
  SAFE_OUTPUT=$(sanitize_for_workflow_command "${OUTPUT}")
  echo "::error::GitHub Project の作成に失敗しました。"
  echo "::error::詳細: ${SAFE_OUTPUT}"
  echo ""
  echo "考えられる原因:"
  if [[ "${OWNER_TYPE}" == "User" ]]; then
    echo "  - PAT に Account permissions > Projects > Read and write 権限が付与されていない"
  elif [[ "${OWNER_TYPE}" == "Organization" ]]; then
    echo "  - PAT に Organization permissions > Projects > Read and write 権限が付与されていない"
    echo "  - Organization の Third-party access policy で PAT がブロックされている"
  else
    echo "  - PAT に Projects > Read and write 権限が付与されていない"
  fi
  echo "  - Owner 名が正しくない"
  echo "  - ネットワークエラー"
  exit 1
fi

echo "::notice::GitHub Project の作成に成功しました。"
echo "${OUTPUT}" | jq '.' 2>/dev/null || echo "${OUTPUT}"

# --- Project 情報の抽出 ---

if ! PROJECT_NUMBER=$(echo "${OUTPUT}" | jq -r '.number // empty'); then
  echo "::error::jq による Project Number の取得に失敗しました。"
  exit 1
fi
PROJECT_URL=$(echo "${OUTPUT}" | jq -r '.url // empty')

if [[ -z "${PROJECT_NUMBER}" ]]; then
  echo "::error::Project Number を抽出できませんでした。gh project create の出力を確認してください。"
  OUTPUT_HEAD=$(echo "${OUTPUT}" | head -5)
  SAFE_OUTPUT_HEAD=$(sanitize_for_workflow_command "${OUTPUT_HEAD}")
  echo "::error::出力: ${SAFE_OUTPUT_HEAD}"
  exit 1
fi

# --- Visibility 設定 ---

echo ""
echo "Visibility を ${PROJECT_VISIBILITY} に設定します..."

if ! EDIT_OUTPUT=$(gh project edit "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" --visibility "${PROJECT_VISIBILITY}" --format json 2>&1); then
  SAFE_EDIT_OUTPUT=$(sanitize_for_workflow_command "${EDIT_OUTPUT}")
  echo "::error::Visibility の設定に失敗しました: ${SAFE_EDIT_OUTPUT}"
  echo "::error::Project は作成されましたが、Visibility はデフォルト（PRIVATE）のままです。"
  echo "手動で設定してください: gh project edit ${PROJECT_NUMBER} --owner ${PROJECT_OWNER} --visibility ${PROJECT_VISIBILITY}"
  exit 1
fi

# Visibility 設定結果の検証
ACTUAL_VISIBILITY=$(echo "${EDIT_OUTPUT}" | jq -r '.visibility // empty')

if [[ -z "${ACTUAL_VISIBILITY}" ]]; then
  echo "::warning::Visibility の検証をスキップしました（レスポンスから visibility を取得できませんでした）。"
elif [[ "${ACTUAL_VISIBILITY}" != "${PROJECT_VISIBILITY}" ]]; then
  echo "::warning::Visibility の設定値が期待と異なります。期待: ${PROJECT_VISIBILITY}、実際: ${ACTUAL_VISIBILITY}"
else
  echo "::notice::Visibility を ${PROJECT_VISIBILITY} に設定し、検証に成功しました。"
fi

# --- サマリー出力 ---

echo ""
echo "Project URL: ${PROJECT_URL}"
echo "Project Number: ${PROJECT_NUMBER}"

# GitHub Actions の出力変数に設定（後続ステップ連携用）
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "project_number=${PROJECT_NUMBER}" >> "${GITHUB_OUTPUT}"
  echo "project_url=${PROJECT_URL}" >> "${GITHUB_OUTPUT}"
fi

# GitHub Actions のサマリーに出力
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## GitHub Project 作成完了"
    echo ""
    echo "| 項目 | 値 |"
    echo "|------|-----|"
    echo "| Owner | \`${PROJECT_OWNER}\` |"
    echo "| Title | ${PROJECT_TITLE} |"
    echo "| Type | ${OWNER_TYPE} |"
    echo "| Visibility | ${PROJECT_VISIBILITY} |"
    echo "| Number | ${PROJECT_NUMBER} |"
    echo "| URL | ${PROJECT_URL} |"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

echo ""
echo "セットアップが完了しました。"
