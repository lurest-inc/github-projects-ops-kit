#!/usr/bin/env bash
# GitHub Project スクリプト共通ライブラリ
# 各スクリプトから source して使用する

# GitHub Actions ワークフローコマンドインジェクションを防ぐためのサニタイズ関数
sanitize_for_workflow_command() {
  local value="$1"
  value="${value//'%'/'%25'}"
  value="${value//$'\n'/'%0A'}"
  value="${value//$'\r'/'%0D'}"
  printf '%s\n' "${value}"
}

# 環境変数の存在チェック
# 使用例: require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
require_env() {
  local var_name="$1"
  local hint="${2:-}"
  if [[ -z "${!var_name:-}" ]]; then
    local message="${var_name} が設定されていません。"
    if [[ -n "${hint}" ]]; then
      message="${message}${hint}"
    fi
    echo "::error::${message}"
    exit 1
  fi
}

# コマンドの存在チェック
# 使用例: require_command "jq" "JSON の解析に必要です。"
require_command() {
  local cmd="$1"
  local purpose="${2:-}"
  if ! command -v "${cmd}" &>/dev/null; then
    local message="${cmd} がインストールされていません。"
    if [[ -n "${purpose}" ]]; then
      message="${message}${purpose}"
    fi
    echo "::error::${message}"
    exit 1
  fi
}

# PROJECT_NUMBER の数値バリデーション
validate_project_number() {
  if ! [[ "${PROJECT_NUMBER}" =~ ^[0-9]+$ ]]; then
    local safe_value
    safe_value=$(sanitize_for_workflow_command "${PROJECT_NUMBER}")
    echo "::error::PROJECT_NUMBER の値が不正です: ${safe_value}（数値のみを指定してください）"
    exit 1
  fi
}

# オーナータイプ判定
# 成功時: OWNER_TYPE と OWNER_QUERY_FIELD をグローバルに設定
detect_owner_type() {
  echo "オーナータイプを判定しています..."

  if ! OWNER_INFO=$(gh api "users/${PROJECT_OWNER}" --jq '.type' 2>&1); then
    local safe_owner_info safe_project_owner
    safe_owner_info=$(sanitize_for_workflow_command "${OWNER_INFO}")
    safe_project_owner=$(sanitize_for_workflow_command "${PROJECT_OWNER}")
    echo "::error::オーナー情報の取得に失敗しました: ${safe_owner_info}"
    echo "::error::PROJECT_OWNER=${safe_project_owner} が正しいか確認してください。"
    exit 1
  fi

  OWNER_TYPE="${OWNER_INFO}"
  echo "  オーナータイプ: ${OWNER_TYPE}"

  if [[ "${OWNER_TYPE}" == "User" ]]; then
    OWNER_QUERY_FIELD="user"
  elif [[ "${OWNER_TYPE}" == "Organization" ]]; then
    OWNER_QUERY_FIELD="organization"
  else
    local safe_owner_type
    safe_owner_type=$(sanitize_for_workflow_command "${OWNER_TYPE}")
    echo "::error::不明なオーナータイプ: ${safe_owner_type}"
    exit 1
  fi
}
