#!/usr/bin/env bash
set -euo pipefail

# 特殊 Repository 一括作成スクリプト
# https://lurest-inc.github.io/github-projects-ops-kit/scripts/create-special-repos
#
# オーナータイプ（User / Organization）を自動判定し、対応する Repository を一括作成する。
# Workflow（03-create-special-repos.yml）から呼び出される。
#
# 環境変数:
#   GH_TOKEN      - GitHub PAT（repo スコープまたは Administration: write が必要）
#   PROJECT_OWNER - 対象のオーナー名（個人アカウントまたは Organization）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
require_env "PROJECT_OWNER"
require_command "gh" "GitHub CLI (gh) が必要です。PATH を確認してください。"
require_command "jq" "JSON の解析に必要です。"

# --- オーナータイプ判定 ---

detect_owner_type

# --- オーナータイプに応じた設定 ---

case "${OWNER_TYPE}" in
  User)
    REPO_DEFINITIONS_FILE="${SCRIPT_DIR}/config/special-repo-definitions-user.json"
    ALLOWED_VISIBILITIES="public/private"
    ;;
  Organization)
    REPO_DEFINITIONS_FILE="${SCRIPT_DIR}/config/special-repo-definitions-org.json"
    ALLOWED_VISIBILITIES="public/private/internal"
    ;;
esac

# --- Repository 定義ファイルの読み込み ---

if [[ ! -f "${REPO_DEFINITIONS_FILE}" ]]; then
  echo "::error::Repository 定義ファイルが見つかりません: ${REPO_DEFINITIONS_FILE}"
  exit 1
fi

REPO_DEFINITIONS=$(cat "${REPO_DEFINITIONS_FILE}")

# --- JSON バリデーション ---

if ! validate_repo_definitions "${REPO_DEFINITIONS}" "${ALLOWED_VISIBILITIES}"; then
  exit 1
fi

# --- 個人アカウント用 Repository 作成コールバック ---
# 引数: REPO_NAME, REPO_DESCRIPTION, REPO_VISIBILITY, REPO_AUTO_INIT
# 戻り値: 0=成功, 1=失敗, 2=不正な visibility

_create_user_repo() {
  local repo_name="$1"
  local repo_description="$2"
  local repo_visibility="$3"
  local repo_auto_init="$4"

  # visibility の検証と private パラメータへの変換
  local private_flag=""
  case "${repo_visibility}" in
    public)  private_flag="false" ;;
    private) private_flag="true" ;;
    *)
      echo "    → 不正な visibility: ${repo_visibility}"
      local safe_repo_name
      safe_repo_name=$(sanitize_for_workflow_command "${repo_name}")
      echo "::error::Repository '${PROJECT_OWNER}/${safe_repo_name}' の visibility が不正です: ${repo_visibility}（public / private を指定してください）"
      return 2
      ;;
  esac

  # Repository 作成（POST /user/repos）
  if gh api "user/repos" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --method POST \
    -f name="${repo_name}" \
    -f description="${repo_description}" \
    -F private="${private_flag}" \
    -F auto_init="${repo_auto_init}" \
    >/dev/null 2>&1; then
    echo "    → 作成しました。"
    return 0
  else
    echo "    → 作成に失敗しました。"
    local safe_repo_name
    safe_repo_name=$(sanitize_for_workflow_command "${repo_name}")
    echo "::error::Repository '${PROJECT_OWNER}/${safe_repo_name}' の作成に失敗しました。"
    return 1
  fi
}

# --- Organization 用 Repository 作成コールバック ---
# 引数: REPO_NAME, REPO_DESCRIPTION, REPO_VISIBILITY, REPO_AUTO_INIT
# 戻り値: 0=成功, 1=失敗, 2=不正な visibility

_create_org_repo() {
  local repo_name="$1"
  local repo_description="$2"
  local repo_visibility="$3"
  local repo_auto_init="$4"

  # visibility の検証
  case "${repo_visibility}" in
    public|private|internal) ;;
    *)
      echo "    → 不正な visibility: ${repo_visibility}"
      local safe_repo_name
      safe_repo_name=$(sanitize_for_workflow_command "${repo_name}")
      echo "::error::Repository '${PROJECT_OWNER}/${safe_repo_name}' の visibility が不正です: ${repo_visibility}（public / private / internal を指定してください）"
      return 2
      ;;
  esac

  # Repository 作成（POST /orgs/{org}/repos）— visibility パラメータを使用
  if gh api "orgs/${PROJECT_OWNER}/repos" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --method POST \
    -f name="${repo_name}" \
    -f description="${repo_description}" \
    -f visibility="${repo_visibility}" \
    -F auto_init="${repo_auto_init}" \
    >/dev/null 2>&1; then
    echo "    → 作成しました。"
    return 0
  else
    echo "    → 作成に失敗しました。"
    local safe_repo_name
    safe_repo_name=$(sanitize_for_workflow_command "${repo_name}")
    echo "::error::Repository '${PROJECT_OWNER}/${safe_repo_name}' の作成に失敗しました。"
    return 1
  fi
}

# --- Repository の一括作成 ---

case "${OWNER_TYPE}" in
  User)
    create_repos_batch "${REPO_DEFINITIONS}" "User" _create_user_repo
    ;;
  Organization)
    create_repos_batch "${REPO_DEFINITIONS}" "Organization" _create_org_repo
    ;;
esac
