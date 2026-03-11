#!/usr/bin/env bash
set -euo pipefail

# GitHub Project セットアップスクリプト
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 操作権限が必要）
#   PROJECT_OWNER  - Project を作成する Owner
#   PROJECT_TITLE  - 作成する Project のタイトル

# --- バリデーション ---

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "::error::GH_TOKEN が設定されていません。Secrets に PROJECT_PAT を設定してください。"
  exit 1
fi

if [[ -z "${PROJECT_OWNER:-}" ]]; then
  echo "::error::PROJECT_OWNER が指定されていません。"
  exit 1
fi

if [[ -z "${PROJECT_TITLE:-}" ]]; then
  echo "::error::PROJECT_TITLE が指定されていません。"
  exit 1
fi

# --- ヘルパー関数 ---

# GitHub Actions ワークフローコマンドインジェクションを防ぐためのサニタイズ関数
sanitize_for_workflow_command() {
  local value="$1"
  value="${value//'%'/'%25'}"
  value="${value//$'\n'/'%0A'}"
  value="${value//$'\r'/'%0D'}"
  echo "${value}"
}

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
echo "  Owner: ${PROJECT_OWNER}"
echo "  Title: ${PROJECT_TITLE}"
echo "  Type:  ${OWNER_TYPE}"

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

# Project URL をサマリーに出力
if command -v jq &>/dev/null; then
  PROJECT_URL=$(echo "${OUTPUT}" | jq -r '.url // empty')
  PROJECT_NUMBER=$(echo "${OUTPUT}" | jq -r '.number // empty')

  if [[ -n "${PROJECT_URL}" ]]; then
    echo ""
    echo "Project URL: ${PROJECT_URL}"
    echo "Project Number: ${PROJECT_NUMBER}"

    # GitHub Actions のサマリーに出力
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
      {
        echo "## GitHub Project 作成完了"
        echo ""
        echo "| 項目 | 値 |"
        echo "|------|-----|"
        echo "| Owner | \`${PROJECT_OWNER}\` |"
        echo "| Type | ${OWNER_TYPE} |"
        echo "| Title | ${PROJECT_TITLE} |"
        echo "| Number | ${PROJECT_NUMBER} |"
        echo "| URL | ${PROJECT_URL} |"
      } >> "${GITHUB_STEP_SUMMARY}"
    fi
  fi
fi

echo ""
echo "セットアップが完了しました。"
