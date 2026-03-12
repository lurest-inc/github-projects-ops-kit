#!/usr/bin/env bash
set -euo pipefail

# GitHub Project セットアップスクリプト
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

# PROJECT_VISIBILITY のデフォルト値設定とバリデーション
PROJECT_VISIBILITY="${PROJECT_VISIBILITY:-PRIVATE}"
if [[ "${PROJECT_VISIBILITY}" != "PUBLIC" && "${PROJECT_VISIBILITY}" != "PRIVATE" ]]; then
  SAFE_PROJECT_VISIBILITY=$(sanitize_for_workflow_command "${PROJECT_VISIBILITY}")
  echo "::error::PROJECT_VISIBILITY の値が不正です: ${SAFE_PROJECT_VISIBILITY}（PUBLIC または PRIVATE を指定してください）"
  exit 1
fi

# --- オーナータイプ判定 ---

echo "オーナータイプを判定しています..."

if ! OWNER_INFO=$(gh api "users/${PROJECT_OWNER}" --jq '.type' 2>&1); then
  SAFE_OWNER_INFO=$(sanitize_for_workflow_command "${OWNER_INFO}")
  SAFE_PROJECT_OWNER=$(sanitize_for_workflow_command "${PROJECT_OWNER}")
  echo "::error::オーナー情報の取得に失敗しました: ${SAFE_OWNER_INFO}"
  echo "::error::考えられる原因の例: PROJECT_OWNER のタイプミス / GH_TOKEN の無効化・権限不足 / gh auth 未設定 / レート制限 / ネットワークエラー"
  echo "次を確認してください:"
  echo "  - PROJECT_OWNER=${SAFE_PROJECT_OWNER} が存在するユーザー/Organization 名か"
  echo "  - gh auth status で GitHub CLI の認証状態と GH_TOKEN の有効性・権限 (Projects: Read and write) を確認"
  echo "  - gh api rate_limit でレート制限に達していないか確認"
  echo "  - ネットワーク接続やプロキシ設定に問題がないか確認"
  exit 1
fi

OWNER_TYPE="${OWNER_INFO}"
echo "  オーナータイプ: ${OWNER_TYPE}"

if [[ "${OWNER_TYPE}" == "User" ]]; then
  echo ""
  echo "個人アカウントとして検出されました。"
  echo "必要な PAT 権限: Account permissions > Projects > Read and write"
elif [[ "${OWNER_TYPE}" == "Organization" ]]; then
  echo ""
  echo "Organization として検出されました。"
  echo "必要な PAT 権限: Organization permissions > Projects > Read and write"
else
  SAFE_OWNER_TYPE=$(sanitize_for_workflow_command "${OWNER_TYPE}")
  echo "::warning::不明なオーナータイプ: ${SAFE_OWNER_TYPE}"
fi

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

if ! EDIT_OUTPUT=$(gh project edit "${PROJECT_NUMBER}" --owner "${PROJECT_OWNER}" --visibility "${PROJECT_VISIBILITY}" 2>&1); then
  SAFE_EDIT_OUTPUT=$(sanitize_for_workflow_command "${EDIT_OUTPUT}")
  echo "::error::Visibility の設定に失敗しました: ${SAFE_EDIT_OUTPUT}"
  echo "::error::Project は作成されましたが、Visibility はデフォルト（PRIVATE）のままです。"
  echo "手動で設定してください: gh project edit ${PROJECT_NUMBER} --owner ${PROJECT_OWNER} --visibility ${PROJECT_VISIBILITY}"
  exit 1
fi

echo "::notice::Visibility を ${PROJECT_VISIBILITY} に設定しました。"

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
