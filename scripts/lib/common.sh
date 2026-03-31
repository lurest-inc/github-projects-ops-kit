#!/usr/bin/env bash
# GitHub Project スクリプト共通ライブラリ
# https://lurest-inc.github.io/github-projects-ops-kit/
#
# 各スクリプトから source して使用する

# --- REST API バージョン ---

REST_API_VERSION="2022-11-28"

# 設定ファイルを読み込み、存在チェックを行う
# 使用例: DEFINITIONS=$(load_config_file "${SCRIPT_DIR}/config/repo-label-definitions.json" "ラベル定義ファイル")
load_config_file() {
  local file_path="$1"
  local description="${2:-設定ファイル}"
  if [[ ! -f "${file_path}" ]]; then
    echo "::error::${description}が見つかりません: ${file_path}"
    exit 1
  fi
  cat "${file_path}"
}

# UTC タイムスタンプを取得する
# 使用例: EXECUTED_AT=$(get_timestamp_utc)
get_timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# UTC 日付を取得する
# 使用例: TODAY=$(get_date_utc)
get_date_utc() {
  date -u +"%Y-%m-%d"
}

# TARGET_REPO 環境変数のバリデーション（owner/repo 形式チェック含む）
# 使用例: validate_target_repo_env
validate_target_repo_env() {
  require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
  require_env "TARGET_REPO"
  if [[ ! "${TARGET_REPO}" =~ ^[^/]+/[^/]+$ ]]; then
    echo "::error::TARGET_REPO は owner/repo 形式で指定してください（例: myorg/myrepo）。"
    exit 1
  fi
  require_command "gh" "GitHub CLI (gh) が必要です。PATH を確認してください。"
  require_command "jq" "JSON の解析に必要です。"
}

# リポジトリのデフォルトブランチ名と SHA を取得する
# 成功時: DEFAULT_BRANCH, DEFAULT_BRANCH_SHA をグローバルに設定
# 使用例: get_default_branch_info "${TARGET_REPO}"
get_default_branch_info() {
  local target_repo="$1"

  echo ""
  echo "Repository ${target_repo} のデフォルトブランチを取得しています..."

  DEFAULT_BRANCH=$(gh api "repos/${target_repo}" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --jq '.default_branch')

  if [[ -z "${DEFAULT_BRANCH}" ]]; then
    echo "::error::デフォルトブランチの取得に失敗しました。"
    exit 1
  fi
  echo "  デフォルトブランチ: ${DEFAULT_BRANCH}"

  echo ""
  echo "デフォルトブランチの SHA を取得しています..."

  DEFAULT_BRANCH_SHA=$(gh api "repos/${target_repo}/git/ref/heads/${DEFAULT_BRANCH}" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --jq '.object.sha')

  if [[ -z "${DEFAULT_BRANCH_SHA}" ]]; then
    echo "::error::デフォルトブランチの SHA 取得に失敗しました。"
    exit 1
  fi
  echo "  SHA: ${DEFAULT_BRANCH_SHA}"
}

# リポジトリのファイル存在チェックを行い、登録対象を決定する
# 成功時: FILES_TO_CREATE 配列と SKIPPED_COUNT をグローバルに設定
# 引数:
#   $1 - target_repo: 対象 Repository（owner/repo 形式）
#   残り - ファイルパスの配列
# 使用例: check_existing_repo_files "${TARGET_REPO}" "${ALL_FILES[@]}"
check_existing_repo_files() {
  local target_repo="$1"
  shift
  local all_files=("$@")

  echo ""
  echo "既存ファイルを確認しています..."

  FILES_TO_CREATE=()
  SKIPPED_COUNT=0

  for file_path in "${all_files[@]}"; do
    if gh api "repos/${target_repo}/contents/${file_path}" \
      -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
      --jq '.sha' >/dev/null 2>&1; then
      echo "  ${file_path} → 既存のためスキップ"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
      echo "  ${file_path} → 登録対象"
      FILES_TO_CREATE+=("${file_path}")
    fi
  done
}

# 作業ブランチを作成し、空ファイルを登録して PR を作成する
# 引数:
#   $1 - target_repo: 対象 Repository（owner/repo 形式）
#   $2 - work_branch: 作業ブランチ名
#   $3 - commit_prefix: コミットメッセージのプレフィックス（例: "docs" / "chore"）
#   $4 - file_type_label: ファイル種別ラベル（例: "Community Health Files" / "Scaffold ファイル"）
#   $5 - pr_title: PR タイトル
#   $6 - pr_body_intro: PR 本文の冒頭説明文
# グローバル参照: DEFAULT_BRANCH, DEFAULT_BRANCH_SHA, FILES_TO_CREATE, HEALTH_FILES/SCAFFOLD_FILES (all_files_ref)
# 使用例: create_files_via_pr "${TARGET_REPO}" "chore/add-files" "docs" "Health Files" "docs: add files" "説明文" "${ALL_FILES[@]}"
create_files_via_pr() {
  local target_repo="$1"
  local work_branch="$2"
  local commit_prefix="$3"
  local file_type_label="$4"
  local pr_title="$5"
  local pr_body_intro="$6"
  shift 6
  local all_files=("$@")

  CREATED_COUNT=0
  FAILED_COUNT=0

  # 作業ブランチ作成
  echo ""
  echo "作業ブランチ ${work_branch} を作成しています..."

  if ! gh api "repos/${target_repo}/git/refs" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --method POST \
    -f "ref=refs/heads/${work_branch}" \
    -f "sha=${DEFAULT_BRANCH_SHA}" \
    >/dev/null 2>&1; then
    echo "::error::作業ブランチの作成に失敗しました。同名のブランチが既に存在する可能性があります。"
    exit 1
  fi
  echo "  作成しました。"

  # ファイル登録
  echo ""
  echo "${file_type_label} を登録します..."

  local file_index=0
  for file_path in "${FILES_TO_CREATE[@]}"; do
    file_index=$((file_index + 1))

    echo ""
    echo "  [${file_index}/${#FILES_TO_CREATE[@]}] ${file_path}"

    local content_base64
    content_base64=$(printf '\n' | base64)

    if gh api "repos/${target_repo}/contents/${file_path}" \
      -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
      --method PUT \
      -f "message=${commit_prefix}: add ${file_path}" \
      -f "content=${content_base64}" \
      -f "branch=${work_branch}" \
      >/dev/null 2>&1; then
      echo "    → 作成しました。"
      CREATED_COUNT=$((CREATED_COUNT + 1))
    else
      echo "    → 作成に失敗しました。"
      local safe_file_path
      safe_file_path=$(sanitize_for_workflow_command "${file_path}")
      echo "::error::ファイル '${safe_file_path}' の作成に失敗しました。"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
  done

  # PR 作成
  PR_URL=""
  if [[ "${CREATED_COUNT}" -gt 0 ]]; then
    echo ""
    echo "PR を作成しています..."

    local pr_body="${pr_body_intro}

### 追加ファイル

| ファイル | 状態 |
|---|---|"

    for file_path in "${all_files[@]}"; do
      local local_status="スキップ（既存）"
      for created_file in "${FILES_TO_CREATE[@]}"; do
        if [[ "${file_path}" == "${created_file}" ]]; then
          local_status="追加"
          break
        fi
      done
      pr_body="${pr_body}
| \`${file_path}\` | ${local_status} |"
    done

    if PR_URL=$(gh pr create \
      --repo "${target_repo}" \
      --base "${DEFAULT_BRANCH}" \
      --head "${work_branch}" \
      --title "${pr_title}" \
      --body "${pr_body}" 2>&1); then
      echo "  PR を作成しました: ${PR_URL}"
    else
      echo "::error::PR の作成に失敗しました: ${PR_URL}"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
  fi
}

# リポジトリファイル一括登録の GitHub Actions サマリーを出力する
# 引数:
#   $1 - summary_title: サマリーのタイトル
# グローバル参照: CREATED_COUNT, SKIPPED_COUNT, FAILED_COUNT, PR_URL
# 使用例: output_repo_files_summary "Community Health Files 一括登録完了"
output_repo_files_summary() {
  local summary_title="$1"

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## ${summary_title}"
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
}

# GitHub Actions Workflow コマンドインジェクションを防ぐためのサニタイズ関数
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

# クエリテンプレート内の __OWNER_FIELD__ を OWNER_QUERY_FIELD に置換する
# GraphQL ではフィールド名を変数化できないため、テンプレートプレースホルダーで対応する
# 使用例: QUERY=$(apply_owner_field "${QUERY_TEMPLATE}")
apply_owner_field() {
  local template="$1"
  echo "${template//__OWNER_FIELD__/${OWNER_QUERY_FIELD}}"
}

# GraphQL レスポンスのエラーチェックを行う（内部ヘルパー）
# gh api の終了コードが 0 でもレスポンス内に GraphQL エラーが含まれる場合がある
# 使用例: _check_graphql_errors "${result}" "Project 情報の取得"
_check_graphql_errors() {
  local result="$1"
  local context="$2"

  if echo "${result}" | jq -e '.errors and (.errors | length > 0)' >/dev/null 2>&1; then
    local safe_errors
    safe_errors=$(sanitize_for_workflow_command "$(echo "${result}" | jq -c '.errors')")
    echo "::error::${context}中に GraphQL エラーが発生しました: ${safe_errors}" >&2
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

  _check_graphql_errors "${result}" "${context}"
  echo "${result}"
}

# GraphQL クエリ／ミューテーションを JSON 変数付きで実行し、エラーチェックを行う
# -F フラグでは JSON 配列を正しく渡せない問題 (Issue #127) を回避するため、
# 変数を JSON オブジェクトとして --input 経由で渡す
# 使用例: RESULT=$(run_graphql_json "${MUTATION}" "フィールドの作成" "${VARIABLES_JSON}")
run_graphql_json() {
  local query="$1"
  local context="${2:-GraphQL API の呼び出し}"
  local variables='{}'
  if [[ -n "${3:-}" ]]; then
    variables="$3"
  fi

  local request_body
  if ! request_body=$(jq -n --arg query "${query}" --argjson variables "${variables}" \
    '{query: $query, variables: $variables}' 2>&1); then
    local safe_error
    safe_error=$(sanitize_for_workflow_command "${request_body}")
    echo "::error::${context}のリクエスト構築に失敗しました: ${safe_error}" >&2
    exit 1
  fi

  local result
  if ! result=$(printf '%s' "${request_body}" | gh api graphql --input - 2>&1); then
    local safe_result
    safe_result=$(sanitize_for_workflow_command "${result}")
    echo "::error::${context}に失敗しました: ${safe_result}" >&2
    exit 1
  fi

  _check_graphql_errors "${result}" "${context}"
  echo "${result}"
}

# ページネーション付き GraphQL クエリを実行し、コールバックでページごとの結果を処理する
# 引数:
#   $1 - GraphQL クエリ
#   $2 - コンテキスト（エラーメッセージ用）
#   $3 - ベース変数 JSON（after は自動付与される）
#   $4 - pageInfo への jq フィルタ（$owner 変数で OWNER_QUERY_FIELD を参照可能）
#   $5 - コールバック関数名（引数: $1=ページ結果 JSON, $2=ページ番号）
#        戻り値: 0=継続, 1=エラー（関数も非ゼロで返る）, 2=早期終了（成功扱い）
#   $6 - 最大ページ数（省略または 0 で無制限）
# 使用例:
#   _on_page() { ALL_ITEMS+=$(echo "$1" | jq -r '...'); }
#   run_graphql_paginated "${QUERY}" "Item 取得" "${VARS}" \
#     '.data.[($owner)].projectV2.items.pageInfo' _on_page 50
run_graphql_paginated() {
  local query="$1"
  local context="$2"
  local base_variables="$3"
  local page_info_jq="$4"
  local callback="$5"
  local max_pages="${6:-0}"

  # コールバック関数の存在チェック
  if ! declare -F "${callback}" >/dev/null 2>&1; then
    echo "::error::コールバック関数 '${callback}' が定義されていません。" >&2
    return 1
  fi

  local _pgn_cursor=""
  local _pgn_has_next="true"
  local _pgn_page=0

  while [[ "${_pgn_has_next}" == "true" ]]; do
    _pgn_page=$((_pgn_page + 1))
    if [[ "${max_pages}" -gt 0 && "${_pgn_page}" -gt "${max_pages}" ]]; then
      echo "::warning::ページネーション上限（${max_pages} ページ）に達しました。一部のデータが取得されていない可能性があります。" >&2
      break
    fi

    local _pgn_variables
    _pgn_variables=$(echo "${base_variables}" | jq --arg after "${_pgn_cursor}" \
      'if $after == "" then . else . + {after: $after} end')

    local _pgn_result
    if ! _pgn_result=$(run_graphql_json "${query}" "${context}" "${_pgn_variables}"); then
      return 1
    fi

    # コールバック実行（0=継続, 1=エラー, 2=早期終了）
    local _pgn_cb_status=0
    "${callback}" "${_pgn_result}" "${_pgn_page}" || _pgn_cb_status=$?
    if [[ "${_pgn_cb_status}" -eq 1 ]]; then
      return 1
    elif [[ "${_pgn_cb_status}" -ne 0 ]]; then
      break
    fi

    IFS=$'\t' read -r _pgn_has_next _pgn_cursor < <(
      echo "${_pgn_result}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" \
        "[${page_info_jq}.hasNextPage // false, ${page_info_jq}.endCursor // \"\"] | @tsv" 2>/dev/null || printf '%s\t%s\n' false ""
    )
  done
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

# Markdown テーブルセル用エスケープ関数（jq 内で使用）
# パイプ文字および Markdown 特殊文字（\, `, *, _, [, ], <, >, ~）をバックスラッシュでエスケープ
JQ_MD_ESCAPE='def md_escape: gsub("\\\\"; "\\\\") | gsub("`"; "\\`") | gsub("\\*"; "\\*") | gsub("_"; "\\_") | gsub("\\["; "\\[") | gsub("\\]"; "\\]") | gsub("<"; "\\<") | gsub(">"; "\\>") | gsub("~"; "\\~") | gsub("\\|"; "\\|");'

# ステータス順序付け用 jq 関数定義
# Backlog → Todo → In Progress → In Review → Done の順でソートする
# 使用例: echo "${DATA}" | jq "${JQ_STATUS_ORDER}"'sort_by(status_order(.status))'
JQ_STATUS_ORDER='def status_order(s): if s == "Backlog" then 0 elif s == "Todo" then 1 elif s == "In Progress" then 2 elif s == "In Review" then 3 elif s == "Done" then 4 else 5 end;'

# ITEM_TYPE フィルタ用ヘルパー関数
# ITEM_TYPE 環境変数の値に応じて Issue / PR を含めるかどうかを判定する
should_include_issues() { [[ "${ITEM_TYPE}" == "all" || "${ITEM_TYPE}" == "issues" ]]; }
should_include_prs() { [[ "${ITEM_TYPE}" == "all" || "${ITEM_TYPE}" == "prs" ]]; }

# ITEM_TYPE と ITEM_STATE に基づいて Item JSON 配列を一括フィルタリングする
# type フィルタと state フィルタを 1 回の jq 呼び出しで実行する
# 標準入力から JSON 配列を受け取り、フィルタ後の JSON 配列を標準出力に返す
# 使用例: ITEMS=$(echo "${ITEMS}" | filter_items)
filter_items() {
  jq \
    --argjson includeIssues "$(should_include_issues && echo true || echo false)" \
    --argjson includePRs "$(should_include_prs && echo true || echo false)" \
    --arg itemState "${ITEM_STATE}" '
    map(select(
      ($includeIssues or .type != "Issue")
      and ($includePRs or .type != "PullRequest")
      and (
        $itemState == "all"
        or ($itemState == "open" and .state == "OPEN")
        or ($itemState == "closed" and (.state == "CLOSED" or .state == "MERGED"))
      )
    ))
  '
}

# OUTPUT_FORMAT から出力ファイルの拡張子を返す
# 使用例: FILE_EXT=$(get_file_extension "${OUTPUT_FORMAT}")
get_file_extension() {
  local format="$1"
  case "${format}" in
    markdown) echo "md" ;;
    csv)      echo "csv" ;;
    tsv)      echo "tsv" ;;
    json)     echo "json" ;;
    *)        echo "json" ;;
  esac
}

# OUTPUT_FORMAT に対応する出力ファイルパスを構築する
# 使用例: OUTPUT_FILE=$(build_output_filename "report" "effort")
#         → report-${PROJECT_NUMBER}-effort.json
build_output_filename() {
  local prefix="$1"
  local suffix="$2"
  local file_ext
  file_ext=$(get_file_extension "${OUTPUT_FORMAT}")
  echo "${prefix}-${PROJECT_NUMBER}-${suffix}.${file_ext}"
}

# レポート結果を Workflow Summary に追記する
# markdown 形式の場合は出力ファイルをそのまま追記し、
# それ以外の場合は指定された markdown 生成関数を呼び出して追記する
# 使用例: append_to_workflow_summary "${OUTPUT_FILE}" format_stale_markdown "${STALE_ITEMS}"
append_to_workflow_summary() {
  local output_file="$1"
  local markdown_func="$2"
  shift 2
  local func_args=("$@")

  if [[ -z "${GITHUB_STEP_SUMMARY:-}" ]]; then
    return
  fi

  if [[ "${OUTPUT_FORMAT}" == "markdown" ]]; then
    cat "${output_file}" >> "${GITHUB_STEP_SUMMARY}"
  else
    "${markdown_func}" ${func_args[@]+"${func_args[@]}"} >> "${GITHUB_STEP_SUMMARY}"
  fi
}

# Project の全 Item をページネーション付きで取得する汎用関数
# 成功時: PROJECT_TITLE をグローバルに設定し、正規化済み Item JSON 配列を標準出力に出力
# 失敗時: エラーメッセージを出力して return 1
# 引数:
#   $1 - GraphQL クエリテンプレート（__OWNER_FIELD__ プレースホルダーを含む）
#   $2 - Item 正規化用 jq フィルタ（$owner 変数で OWNER_QUERY_FIELD を参照可能）
#   $3 - ページネーション上限（省略時: 50）
# 使用例:
#   ITEMS=$(fetch_all_project_items "${QUERY_TEMPLATE}" "${NORMALIZE_FILTER}" 50)
fetch_all_project_items() {
  local query_template="$1"
  local normalize_filter="$2"
  local max_pages="${3:-50}"

  _FAPI_ALL_ITEMS="[]"
  _FAPI_NORMALIZE_FILTER="${normalize_filter}"

  _fapi_on_page() {
    local result="$1"
    local page="$2"

    # Project の存在チェック（初回のみ）
    if [[ "${page}" -eq 1 ]]; then
      local project_title_check
      project_title_check=$(echo "${result}" | jq -r --arg owner "${OWNER_QUERY_FIELD}" '.data.[($owner)].projectV2.title // empty' 2>/dev/null || true)
      if [[ -z "${project_title_check}" ]]; then
        echo "::error::Project が見つかりません。PROJECT_OWNER（${PROJECT_OWNER}）と PROJECT_NUMBER（${PROJECT_NUMBER}）を確認してください。" >&2
        return 1
      fi
      PROJECT_TITLE="${project_title_check}"
    fi

    local page_items
    page_items=$(echo "${result}" | jq --arg owner "${OWNER_QUERY_FIELD}" "${_FAPI_NORMALIZE_FILTER}" 2>/dev/null || echo "[]")

    local page_count
    page_count=$(echo "${page_items}" | jq 'length')
    echo "  ページ ${page} 取得完了（${page_count} 件）" >&2

    _FAPI_ALL_ITEMS=$(echo "${_FAPI_ALL_ITEMS}" "${page_items}" | jq -s '.[0] + .[1]')
  }

  local query
  query=$(apply_owner_field "${query_template}")

  local variables_json
  variables_json=$(jq -n \
    --arg login "${PROJECT_OWNER}" \
    --argjson number "${PROJECT_NUMBER}" \
    '{login: $login, number: $number}')

  if ! run_graphql_paginated "${query}" "Project Item の取得" "${variables_json}" \
    '.data.[($owner)].projectV2.items.pageInfo' _fapi_on_page "${max_pages}"; then
    return 1
  fi

  echo "${_FAPI_ALL_ITEMS}"
}

# 分析系スクリプト共通の環境変数バリデーションを一括実行する
# validate_common_project_env に加え、ITEM_TYPE / ITEM_STATE / OUTPUT_FORMAT のチェックを行う
# 引数:
#   $1 - OUTPUT_FORMAT のデフォルト値（省略時: "json"）
# 使用例: validate_analysis_env "markdown"
validate_analysis_env() {
  local default_format="${1:-json}"

  validate_common_project_env

  ITEM_TYPE="${ITEM_TYPE:-all}"
  ITEM_STATE="${ITEM_STATE:-all}"
  OUTPUT_FORMAT="${OUTPUT_FORMAT:-${default_format}}"

  validate_enum "ITEM_TYPE" "${ITEM_TYPE}" "all" "issues" "prs"
  validate_enum "ITEM_STATE" "${ITEM_STATE}" "open" "closed" "all"
  validate_enum "OUTPUT_FORMAT" "${OUTPUT_FORMAT}" "markdown" "csv" "tsv" "json"
}

# 汎用 CSV フォーマッタ
# ヘッダー行とデータ行を @csv で出力する
# 使用例: format_items_csv "type,number,title" '.[] | [.type, .number, .title]' "${ITEMS}"
format_items_csv() {
  local header="$1"
  local row_filter="$2"
  local items="$3"
  echo "${header}"
  echo "${items}" | jq -r "${row_filter} | @csv"
}

# 汎用 TSV フォーマッタ
# ヘッダー行とデータ行を @tsv で出力する
# 使用例: format_items_tsv "type\tnumber\ttitle" '.[] | [.type, .number, .title]' "${ITEMS}"
format_items_tsv() {
  local header="$1"
  local row_filter="$2"
  local items="$3"
  echo -e "${header}"
  echo "${items}" | jq -r "${row_filter} | @tsv"
}

# Repository 定義 JSON のバリデーションを行う
# 引数:
#   $1 - definitions_json: Repository 定義の JSON 文字列
#   $2 - allowed_visibilities: 許可される visibility の値（例: "public/private/internal" または "public/private"）
# 戻り値: バリデーションエラーがある場合は非ゼロを返す
# 使用例: validate_repo_definitions "${REPO_DEFINITIONS}" "public/private/internal"
validate_repo_definitions() {
  local definitions_json="$1"
  local allowed_visibilities="$2"

  echo ""
  echo "Repository 定義ファイルを検証しています..."

  # 許可される visibility を JSON 配列に変換（例: "public/private/internal" → '["public","private","internal"]'）
  local allowed_json
  allowed_json=$(echo "${allowed_visibilities}" | jq -R 'split("/")')

  # 許可値の表示用文字列（例: public / private / internal）
  local allowed_display
  allowed_display=$(echo "${allowed_visibilities}" | sed 's|/| / |g')

  local validation_errors
  if ! validation_errors=$(echo "${definitions_json}" | jq -r \
    --argjson allowed "${allowed_json}" \
    --arg allowed_display "${allowed_display}" '
    if type != "array" then
      "Repository 定義ファイルが JSON 配列ではありません。"
    else
      [to_entries[] |
        .key as $i |
        .value |
        (if .name_template == null or .name_template == "" then "[\($i)]: name_template が未定義または空です。" else empty end),
        (if .description == null then "[\($i)]: description が未定義です。" else empty end),
        (if .visibility == null or .visibility == "" then "[\($i)]: visibility が未定義または空です。" else empty end),
        (if .visibility != null and .visibility != "" and (.visibility as $v | $allowed | any(. == $v) | not) then "[\($i)]: visibility の値が不正です: \(.visibility)（\($allowed_display) を指定してください）" else empty end),
        (if .auto_init == null then "[\($i)]: auto_init が未定義です。" else empty end),
        (if .auto_init != null and (.auto_init | type) != "boolean" then "[\($i)]: auto_init は boolean で指定してください。" else empty end)
      ] | join("\n")
    end
  ' 2>&1); then
    echo "::error::Repository 定義ファイルの解析に失敗しました: $(sanitize_for_workflow_command "${validation_errors}")"
    return 1
  fi

  if [[ -n "${validation_errors}" ]]; then
    echo "::error::Repository 定義ファイルのバリデーションに失敗しました:"
    echo "${validation_errors}" | while IFS= read -r line; do
      echo "::error::  ${line}"
    done
    return 1
  fi

  return 0
}

# Repository 一括作成の共通処理
# 引数:
#   $1 - definitions_json: Repository 定義の JSON 文字列
#   $2 - owner_type_label: オーナータイプのラベル（例: "Organization" または "User"）
#   $3 - api_creator_func: Repository 作成 API を呼び出すコールバック関数名
#        コールバック引数: REPO_NAME, REPO_DESCRIPTION, REPO_VISIBILITY, REPO_AUTO_INIT
#        コールバック戻り値: 0=成功, 1=失敗, 2=不正な visibility
# 使用例: create_repos_batch "${REPO_DEFINITIONS}" "Organization" _create_org_repo
create_repos_batch() {
  local definitions_json="$1"
  local owner_type_label="$2"
  local api_creator_func="$3"

  local repo_count
  repo_count=$(echo "${definitions_json}" | jq 'length')
  echo "  ${repo_count} 件の Repository 定義を読み込みました。"

  # オーナータイプに応じたラベルを設定
  local type_label_ja
  if [[ "${owner_type_label}" == "Organization" ]]; then
    type_label_ja="Organization 用"
  else
    type_label_ja="個人アカウント用"
  fi

  echo ""
  echo "${type_label_ja}の特殊 Repository を作成します..."
  echo "  オーナー: ${PROJECT_OWNER}"
  echo "  定義数: ${repo_count} 件"

  if [[ "${repo_count}" -eq 0 ]]; then
    echo ""
    echo "Repository 定義が空のため、処理をスキップします。"
    print_summary "Owner" "${PROJECT_OWNER}" "作成" "0 件" "スキップ" "0 件" "失敗" "0 件"
    exit 0
  fi

  # --- Repository の一括作成 ---

  local parsed_repos
  parsed_repos=$(echo "${definitions_json}" | jq -r --arg owner "${PROJECT_OWNER}" \
    '.[] | [(.name_template | gsub("\\{\\{owner\\}\\}"; $owner)), .description, .visibility, (.auto_init | tostring)] | @tsv')

  local created_count=0
  local skipped_count=0
  local failed_count=0
  local repo_index=0

  while IFS=$'\t' read -r REPO_NAME REPO_DESCRIPTION REPO_VISIBILITY REPO_AUTO_INIT; do
    repo_index=$((repo_index + 1))

    echo ""
    echo "  [${repo_index}/${repo_count}] ${PROJECT_OWNER}/${REPO_NAME} (${REPO_VISIBILITY})"

    # 既存 Repository の重複チェック
    if gh api "repos/${PROJECT_OWNER}/${REPO_NAME}" \
      -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
      >/dev/null 2>&1; then
      echo "    → 既存 Repository のためスキップしました。"
      skipped_count=$((skipped_count + 1))
      continue
    fi

    # コールバック関数で Repository を作成（0=成功, 1=失敗, 2=不正な visibility）
    local _cb_status=0
    "${api_creator_func}" "${REPO_NAME}" "${REPO_DESCRIPTION}" "${REPO_VISIBILITY}" "${REPO_AUTO_INIT}" || _cb_status=$?

    case "${_cb_status}" in
      0) created_count=$((created_count + 1)) ;;
      2) failed_count=$((failed_count + 1)) ;;
      *) failed_count=$((failed_count + 1)) ;;
    esac
  done <<< "${parsed_repos}"

  # --- サマリー出力 ---

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## ${type_label_ja}特殊 Repository 一括作成完了"
      echo ""
      echo "| 項目 | 件数 |"
      echo "|------|------|"
      echo "| 作成 | ${created_count} |"
      echo "| スキップ | ${skipped_count} |"
      echo "| 失敗 | ${failed_count} |"
    } >> "${GITHUB_STEP_SUMMARY}"
  fi

  print_summary "Owner" "${PROJECT_OWNER}" "タイプ" "${owner_type_label}" "作成" "${created_count} 件" "スキップ" "${skipped_count} 件" "失敗" "${failed_count} 件"

  if [[ "${failed_count}" -gt 0 ]]; then
    echo ""
    echo "::error::${failed_count} 件の Repository 作成に失敗しました。"
    exit 1
  fi

  echo ""
  echo "セットアップが完了しました。"
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
