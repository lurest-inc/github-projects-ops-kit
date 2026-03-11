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

# --- オーナータイプ判定 ---

echo "オーナータイプを判定しています..."

if ! OWNER_INFO=$(gh api "users/${PROJECT_OWNER}" --jq '.type' 2>&1); then
  echo "::error::オーナー情報の取得に失敗しました: ${OWNER_INFO}"
  echo "::error::PROJECT_OWNER（${PROJECT_OWNER}）が正しいか確認してください。"
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
  echo "::warning::不明なオーナータイプ: ${OWNER_TYPE}"
fi

echo ""

# --- Project 作成 ---

echo "GitHub Project を作成します..."
echo "  Owner: ${PROJECT_OWNER}"
echo "  Title: ${PROJECT_TITLE}"
echo "  Type:  ${OWNER_TYPE}"

if ! OUTPUT=$(gh project create --title "${PROJECT_TITLE}" --owner "${PROJECT_OWNER}" --format json 2>&1); then
  echo "::error::GitHub Project の作成に失敗しました。"
  echo "::error::詳細: ${OUTPUT}"
  echo ""
  echo "考えられる原因:"
  if [[ "${OWNER_TYPE}" == "User" ]]; then
    echo "  - PAT に Account permissions > Projects > Read and write 権限が付与されていない"
  elif [[ "${OWNER_TYPE}" == "Organization" ]]; then
    echo "  - PAT に Organization permissions > Projects > Read and write 権限が付与されていない"
    echo "  - Organization の Third-party access policy で PAT がブロックされている"
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
