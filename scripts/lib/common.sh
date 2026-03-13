#!/usr/bin/env bash
# GitHub Project スクリプト共通ライブラリ
# https://mabubu0203.github.io/github-projects-starter-kit/
#
# 各スクリプトから source して使用する

# --- REST API バージョン ---

REST_API_VERSION="2022-11-28"

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
# ローカル実行時に親切なエラーメッセージを表示するための防御的チェック。
# GitHub Actions の ubuntu-latest には gh・jq ともにプリインストール済みのため
# CI 上では実質スキップされるが、ローカル環境での利便性を考慮して残している。
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
# 成功時: OWNER_TYPE, OWNER_QUERY_FIELD, OWNER_NODE_ID をグローバルに設定
detect_owner_type() {
  echo "オーナータイプを判定しています..."

  local owner_json
  if ! owner_json=$(gh api "users/${PROJECT_OWNER}" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --jq '{type: .type, node_id: .node_id}' 2>&1); then
    local safe_owner_info safe_project_owner
    safe_owner_info=$(sanitize_for_workflow_command "${owner_json}")
    safe_project_owner=$(sanitize_for_workflow_command "${PROJECT_OWNER}")
    echo "::error::オーナー情報の取得に失敗しました: ${safe_owner_info}"
    echo "::error::PROJECT_OWNER=${safe_project_owner} が正しいか確認してください。"
    exit 1
  fi

  IFS=$'\t' read -r OWNER_TYPE OWNER_NODE_ID < <(echo "${owner_json}" | jq -r '[.type, .node_id] | @tsv')

  if [[ -z "${OWNER_NODE_ID}" || "${OWNER_NODE_ID}" == "null" ]]; then
    echo "::error::オーナーの node_id を取得できませんでした。PAT の権限を確認してください。"
    exit 1
  fi

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

# GraphQL クエリ／ミューテーションを実行し、エラーチェックを行う
# 成功時: 結果を標準出力に出力（呼び出し元で変数にキャプチャする）
# 失敗時: エラーメッセージを出力して exit 1
# 使用例: RESULT=$(run_graphql "${QUERY}" "Project 情報の取得")
# 追加引数付き: RESULT=$(run_graphql "${MUTATION}" "View の作成" -f projectId="..." -f name="...")
run_graphql() {
  local query="$1"
  local context="${2:-GraphQL API の呼び出し}"
  shift 2 || shift $#
  local extra_args=("$@")

  local result
  if ! result=$(gh api graphql -f query="${query}" ${extra_args[@]+"${extra_args[@]}"} 2>&1); then
    local safe_result
    safe_result=$(sanitize_for_workflow_command "${result}")
    echo "::error::${context}に失敗しました: ${safe_result}" >&2
    exit 1
  fi

  if echo "${result}" | jq -e '.errors and (.errors | length > 0)' >/dev/null 2>&1; then
    local safe_errors
    safe_errors=$(sanitize_for_workflow_command "$(echo "${result}" | jq -c '.errors')")
    echo "::error::${context}中に GraphQL エラーが発生しました: ${safe_errors}" >&2
    exit 1
  fi

  echo "${result}"
}

# 罫線付きコンソールサマリーを出力する
# 使用例: print_summary "Owner" "${PROJECT_OWNER}" "Project" "#${PROJECT_NUMBER}" "作成" "${COUNT} 件"
print_summary() {
  echo ""
  echo "========================================="
  echo "  完了サマリー"
  echo "========================================="
  while [[ $# -ge 2 ]]; do
    printf "  %-10s %s\n" "$1:" "$2"
    shift 2
  done
  echo "========================================="
}

# Project 操作スクリプト共通の環境変数バリデーションを一括実行する
# GH_TOKEN, PROJECT_OWNER, PROJECT_NUMBER の存在確認、PROJECT_NUMBER の数値チェック、
# gh / jq コマンドの存在確認、オーナータイプ判定を行う
# 使用例: validate_common_project_env
validate_common_project_env() {
  require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
  require_env "PROJECT_OWNER"
  require_env "PROJECT_NUMBER"
  validate_project_number
  require_command "gh" "GitHub CLI (gh) が必要です。PATH を確認してください。"
  require_command "jq" "JSON の解析に必要です。"
  detect_owner_type
}

# 環境変数の値が許可リストに含まれるかチェックする
# 使用例: validate_enum "OUTPUT_FORMAT" "${OUTPUT_FORMAT}" "markdown" "csv" "tsv" "json"
validate_enum() {
  local var_name="$1"
  local value="$2"
  shift 2
  local allowed=("$@")

  for v in "${allowed[@]}"; do
    [[ "${value}" == "${v}" ]] && return 0
  done

  local safe_value
  safe_value=$(sanitize_for_workflow_command "${value}")
  local allowed_str
  allowed_str=$(IFS=" / "; echo "${allowed[*]}")
  echo "::error::${var_name} の値が不正です: ${safe_value}（${allowed_str} を指定してください）"
  exit 1
}
