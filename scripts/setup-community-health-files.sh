#!/usr/bin/env bash
set -euo pipefail

# 指定 Repository への Community Health Files 一括登録スクリプト
#
# 対象リポジトリに作業ブランチを作成し、Community Health Files を
# 空ファイルとして登録した後、デフォルトブランチへの PR を作成する。
# 既に存在するファイルはスキップする（上書き禁止）。
#
# 環境変数:
#   GH_TOKEN        - GitHub PAT（repo スコープが必要）
#   PROJECT_OWNER   - リポジトリオーナー（個人アカウントまたは Organization）
#   REPOSITORY_NAME - 対象リポジトリ名

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
require_env "PROJECT_OWNER"
require_env "REPOSITORY_NAME"
require_command "gh" "GitHub CLI (gh) が必要です。PATH を確認してください。"
require_command "jq" "JSON の解析に必要です。"

TARGET_REPO="${PROJECT_OWNER}/${REPOSITORY_NAME}"

# --- 対象ファイル定義 ---

HEALTH_FILES=(
  ".github/CODE_OF_CONDUCT.md"
  ".github/CONTRIBUTING.md"
  ".github/GOVERNANCE.md"
  ".github/SECURITY.md"
  ".github/SUPPORT.md"
  ".github/PULL_REQUEST_TEMPLATE.md"
  ".github/ISSUE_TEMPLATE/config.yml"
)

FILE_COUNT=${#HEALTH_FILES[@]}

# --- デフォルトブランチの取得 ---

echo ""
echo "Repository ${TARGET_REPO} のデフォルトブランチを取得しています..."

DEFAULT_BRANCH=$(gh api "repos/${TARGET_REPO}" \
  -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
  --jq '.default_branch')

if [[ -z "${DEFAULT_BRANCH}" ]]; then
  echo "::error::デフォルトブランチの取得に失敗しました。"
  exit 1
fi

echo "  デフォルトブランチ: ${DEFAULT_BRANCH}"

# --- デフォルトブランチの SHA 取得 ---

echo ""
echo "デフォルトブランチの SHA を取得しています..."

DEFAULT_BRANCH_SHA=$(gh api "repos/${TARGET_REPO}/git/ref/heads/${DEFAULT_BRANCH}" \
  -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
  --jq '.object.sha')

if [[ -z "${DEFAULT_BRANCH_SHA}" ]]; then
  echo "::error::デフォルトブランチの SHA 取得に失敗しました。"
  exit 1
fi

echo "  SHA: ${DEFAULT_BRANCH_SHA}"

# --- 既存ファイルチェック＆登録対象の決定 ---

echo ""
echo "既存ファイルを確認しています..."

FILES_TO_CREATE=()
SKIPPED_COUNT=0

for file_path in "${HEALTH_FILES[@]}"; do
  if gh api "repos/${TARGET_REPO}/contents/${file_path}" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --jq '.sha' >/dev/null 2>&1; then
    echo "  ${file_path} → 既存のためスキップ"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
  else
    echo "  ${file_path} → 登録対象"
    FILES_TO_CREATE+=("${file_path}")
  fi
done

CREATED_COUNT=0
FAILED_COUNT=0

# --- 全ファイルがスキップされた場合 ---

if [[ ${#FILES_TO_CREATE[@]} -eq 0 ]]; then
  echo ""
  echo "全ファイルが既に存在するため、処理をスキップします。"

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## Community Health Files 一括登録完了"
      echo ""
      echo "| 項目 | 件数 |"
      echo "|------|------|"
      echo "| 作成 | 0 |"
      echo "| スキップ | ${SKIPPED_COUNT} |"
      echo "| 失敗 | 0 |"
      echo ""
      echo "> 全ファイルが既に存在するため、PR は作成されませんでした。"
    } >> "${GITHUB_STEP_SUMMARY}"
  fi

  print_summary "Repository" "${TARGET_REPO}" "作成" "0 件" "スキップ" "${SKIPPED_COUNT} 件" "失敗" "0 件"
  exit 0
fi

# --- 作業ブランチ作成 ---

WORK_BRANCH="chore/add-community-health-files"

echo ""
echo "作業ブランチ ${WORK_BRANCH} を作成しています..."

if ! gh api "repos/${TARGET_REPO}/git/refs" \
  -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
  --method POST \
  -f "ref=refs/heads/${WORK_BRANCH}" \
  -f "sha=${DEFAULT_BRANCH_SHA}" \
  >/dev/null 2>&1; then
  echo "::error::作業ブランチの作成に失敗しました。同名のブランチが既に存在する可能性があります。"
  exit 1
fi

echo "  作成しました。"

# --- ファイル登録 ---

echo ""
echo "Community Health Files を登録します..."

FILE_INDEX=0

for file_path in "${FILES_TO_CREATE[@]}"; do
  FILE_INDEX=$((FILE_INDEX + 1))

  echo ""
  echo "  [${FILE_INDEX}/${#FILES_TO_CREATE[@]}] ${file_path}"

  # 空ファイルの内容（base64 エンコード）— 改行のみ
  CONTENT_BASE64=$(printf '\n' | base64)

  if gh api "repos/${TARGET_REPO}/contents/${file_path}" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --method PUT \
    -f "message=docs: add ${file_path}" \
    -f "content=${CONTENT_BASE64}" \
    -f "branch=${WORK_BRANCH}" \
    >/dev/null 2>&1; then
    echo "    → 作成しました。"
    CREATED_COUNT=$((CREATED_COUNT + 1))
  else
    echo "    → 作成に失敗しました。"
    SAFE_FILE_PATH=$(sanitize_for_workflow_command "${file_path}")
    echo "::error::ファイル '${SAFE_FILE_PATH}' の作成に失敗しました。"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done

# --- PR 作成 ---

if [[ "${CREATED_COUNT}" -gt 0 ]]; then
  echo ""
  echo "PR を作成しています..."

  PR_BODY="## 概要

Community Health Files を一括登録します。

### 追加ファイル

| ファイル | 状態 |
|---|---|"

  for file_path in "${HEALTH_FILES[@]}"; do
    # FILES_TO_CREATE に含まれるかチェック
    local_status="スキップ（既存）"
    for created_file in "${FILES_TO_CREATE[@]}"; do
      if [[ "${file_path}" == "${created_file}" ]]; then
        local_status="追加"
        break
      fi
    done
    PR_BODY="${PR_BODY}
| \`${file_path}\` | ${local_status} |"
  done

  if PR_URL=$(gh pr create \
    --repo "${TARGET_REPO}" \
    --base "${DEFAULT_BRANCH}" \
    --head "${WORK_BRANCH}" \
    --title "docs: add community health files" \
    --body "${PR_BODY}" 2>&1); then
    echo "  PR を作成しました: ${PR_URL}"
  else
    echo "::error::PR の作成に失敗しました: ${PR_URL}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
fi

# --- サマリー出力 ---

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Community Health Files 一括登録完了"
    echo ""
    echo "| 項目 | 件数 |"
    echo "|------|------|"
    echo "| 作成 | ${CREATED_COUNT} |"
    echo "| スキップ | ${SKIPPED_COUNT} |"
    echo "| 失敗 | ${FAILED_COUNT} |"
    if [[ -n "${PR_URL:-}" ]] && [[ "${PR_URL}" == http* ]]; then
      echo ""
      echo "### 作成された PR"
      echo ""
      echo "- ${PR_URL}"
    fi
  } >> "${GITHUB_STEP_SUMMARY}"
fi

print_summary "Repository" "${TARGET_REPO}" "作成" "${CREATED_COUNT} 件" "スキップ" "${SKIPPED_COUNT} 件" "失敗" "${FAILED_COUNT} 件"

if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  echo ""
  echo "::error::${FAILED_COUNT} 件の処理に失敗しました。"
  exit 1
fi

echo ""
echo "セットアップが完了しました。"
