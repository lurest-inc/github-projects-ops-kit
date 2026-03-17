#!/usr/bin/env bash
set -euo pipefail

# GitHub Project アイテム エクスポートスクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/export-project-items
#
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 読み取り権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number
#   OUTPUT_FORMAT  - 出力形式（markdown / csv / tsv / json、デフォルト: markdown）
#   ITEM_TYPE      - 対象アイテムの種別（all / issues / prs、デフォルト: all）
#   ITEM_STATE        - 取得するアイテムの状態（open / closed / all、デフォルト: all）
#   REDACT_SENSITIVE  - 機密フィールドをリダクション（true / false、デフォルト: false）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_common_project_env

OUTPUT_FORMAT="${OUTPUT_FORMAT:-markdown}"
validate_enum "OUTPUT_FORMAT" "${OUTPUT_FORMAT}" "markdown" "csv" "tsv" "json"

ITEM_TYPE="${ITEM_TYPE:-all}"
ITEM_STATE="${ITEM_STATE:-all}"
REDACT_SENSITIVE="${REDACT_SENSITIVE:-false}"
validate_enum "ITEM_TYPE" "${ITEM_TYPE}" "all" "issues" "prs"
validate_enum "ITEM_STATE" "${ITEM_STATE}" "open" "closed" "all"

# --- ヘルパー関数 ---

# Project のアイテム一覧を取得する（ページネーション対応）
fetch_project_items() {
  local all_items="[]"

  _on_export_page() {
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

    # アイテムを正規化して追加（DraftIssue を除外し、統一フォーマットに変換）
    local normalize_filter
    normalize_filter="[.data.[(\$owner)].projectV2.items.nodes[]
      | select(.content != null)
      | select(.content.__typename != null)
      | {
          type:       .content.__typename,
          number:     .content.number,
          title:      .content.title,
          url:        .content.url,
          state:      .content.state,
          repository: .content.repository.nameWithOwner,
          author:     (.content.author.login // \"\"),
          assignees:  ([.content.assignees.nodes[].login] | join(\", \")),
          labels:     ([.content.labels.nodes[].name] | join(\", \")),
          created_at: .content.createdAt,
          updated_at: .content.updatedAt
        }]"
    local page_items
    page_items=$(echo "${result}" | jq --arg owner "${OWNER_QUERY_FIELD}" "${normalize_filter}" 2>/dev/null || echo "[]")

    local page_count
    page_count=$(echo "${page_items}" | jq 'length')
    echo "  ページ ${page} 取得完了（${page_count} 件）" >&2

    all_items=$(echo "${all_items}" "${page_items}" | jq -s '.[0] + .[1]')
  }

  local query_template
  query_template=$(cat <<'GRAPHQL'
query($login: String!, $number: Int!, $after: String) {
  __OWNER_FIELD__(login: $login) {
    projectV2(number: $number) {
      title
      items(first: 100, after: $after) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          content {
            ... on Issue {
              __typename
              number
              title
              url
              state
              createdAt
              updatedAt
              author { login }
              repository { nameWithOwner }
              assignees(first: 100) { nodes { login } }
              labels(first: 100) { nodes { name } }
            }
            ... on PullRequest {
              __typename
              number
              title
              url
              state
              createdAt
              updatedAt
              author { login }
              repository { nameWithOwner }
              assignees(first: 100) { nodes { login } }
              labels(first: 100) { nodes { name } }
            }
          }
        }
      }
    }
  }
}
GRAPHQL
)
  local query
  query=$(apply_owner_field "${query_template}")

  local variables_json
  variables_json=$(jq -n \
    --arg login "${PROJECT_OWNER}" \
    --argjson number "${PROJECT_NUMBER}" \
    '{login: $login, number: $number}')

  if ! run_graphql_paginated "${query}" "Project アイテムの取得" "${variables_json}" \
    '.data.[($owner)].projectV2.items.pageInfo' _on_export_page 50; then
    return 1
  fi

  echo "${all_items}"
}

# --- フォーマッター関数 ---

format_markdown() {
  local items="$1"
  local issue_count pr_count
  read -r issue_count pr_count < <(echo "${items}" | jq -r '[([.[] | select(.type == "Issue")] | length), ([.[] | select(.type == "PullRequest")] | length)] | @tsv')

  if is_redact_enabled; then
    local md_row_filter="${JQ_MD_ESCAPE}"'
      "| [#\(.number)](\(.url)) | \(.title | md_escape) | \(.state) | \(.repository) | \(.labels | md_escape) | \(.created_at | split(\"T\")[0]) | \(.updated_at | split(\"T\")[0]) |"'
    local table_header="| # | タイトル | 状態 | リポジトリ | ラベル | 作成日 | 更新日 |"
    local table_separator="|---|---------|------|-----------|--------|--------|--------|"
  else
    local md_row_filter="${JQ_MD_ESCAPE}"'
      "| [#\(.number)](\(.url)) | \(.title | md_escape) | \(.state) | \(.repository) | \(.author) | \(.assignees | md_escape) | \(.labels | md_escape) | \(.created_at | split(\"T\")[0]) | \(.updated_at | split(\"T\")[0]) |"'
    local table_header="| # | タイトル | 状態 | リポジトリ | 作成者 | アサイン | ラベル | 作成日 | 更新日 |"
    local table_separator="|---|---------|------|-----------|--------|---------|--------|--------|--------|"
  fi

  {
    echo "# Project アイテム一覧"
    echo ""
    echo "- **Project:** ${PROJECT_TITLE}"
    echo "- **Project Number:** ${PROJECT_NUMBER}"
    echo "- **Issue:** ${issue_count} 件"
    echo "- **Pull Request:** ${pr_count} 件"
    echo "- **合計:** $((issue_count + pr_count)) 件"
    echo ""

    if [[ "${issue_count}" -gt 0 ]]; then
      echo "## Issues"
      echo ""
      echo "${table_header}"
      echo "${table_separator}"
      echo "${items}" | jq -r ".[] | select(.type == \"Issue\") | ${md_row_filter}"
      echo ""
    fi

    if [[ "${pr_count}" -gt 0 ]]; then
      echo "## Pull Requests"
      echo ""
      echo "${table_header}"
      echo "${table_separator}"
      echo "${items}" | jq -r ".[] | select(.type == \"PullRequest\") | ${md_row_filter}"
      echo ""
    fi
  }
}

format_csv() {
  local items="$1"
  if is_redact_enabled; then
    echo "type,number,title,url,state,repository,labels,created_at,updated_at"
    echo "${items}" | jq -r '.[] | [.type, .number, .title, .url, .state, .repository, .labels, .created_at, .updated_at] | @csv'
  else
    echo "type,number,title,url,state,repository,author,assignees,labels,created_at,updated_at"
    echo "${items}" | jq -r '.[] | [.type, .number, .title, .url, .state, .repository, .author, .assignees, .labels, .created_at, .updated_at] | @csv'
  fi
}

format_tsv() {
  local items="$1"
  if is_redact_enabled; then
    echo -e "type\tnumber\ttitle\turl\tstate\trepository\tlabels\tcreated_at\tupdated_at"
    echo "${items}" | jq -r '.[] | [.type, (.number | tostring), .title, .url, .state, .repository, .labels, .created_at, .updated_at] | @tsv'
  else
    echo -e "type\tnumber\ttitle\turl\tstate\trepository\tauthor\tassignees\tlabels\tcreated_at\tupdated_at"
    echo "${items}" | jq -r '.[] | [.type, (.number | tostring), .title, .url, .state, .repository, .author, .assignees, .labels, .created_at, .updated_at] | @tsv'
  fi
}

format_json() {
  local items="$1"
  if is_redact_enabled; then
    echo "${items}" | jq '[.[] | del(.author, .assignees)]'
  else
    echo "${items}" | jq '.'
  fi
}

# --- アイテム取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} のアイテムを取得しています..."
PROJECT_TITLE=""
ITEMS=$(fetch_project_items)

TOTAL_BEFORE_FILTER=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_BEFORE_FILTER} 件（フィルタ前）"

# --- type / state フィルタリング ---

# type フィルタを適用
ITEMS=$(echo "${ITEMS}" | filter_items_by_type)

# state フィルタを適用（closed は CLOSED + MERGED を含む）
ITEMS=$(echo "${ITEMS}" | filter_items_by_state)

read -r TOTAL_COUNT ISSUE_COUNT PR_COUNT < <(echo "${ITEMS}" | jq -r '[length, ([.[] | select(.type == "Issue")] | length), ([.[] | select(.type == "PullRequest")] | length)] | @tsv')

echo "  合計: ${TOTAL_COUNT} 件（Issue: ${ISSUE_COUNT}, PR: ${PR_COUNT}）"

# --- 機密フィールドのリダクション ---

if is_redact_enabled; then
  echo "  機密フィールドをリダクションしています..."
  ITEMS=$(echo "${ITEMS}" | jq '[.[] | .author = "***" | .assignees = "***"]')
fi

if [[ "${TOTAL_COUNT}" -eq 0 ]]; then
  echo "::warning::対象の Issue / Pull Request が見つかりませんでした。"
fi

# --- フォーマット・出力 ---

echo ""
echo "出力形式: ${OUTPUT_FORMAT}"

FILE_EXT=$(get_file_extension "${OUTPUT_FORMAT}")

OUTPUT_FILE="export-${PROJECT_NUMBER}-items.${FILE_EXT}"

case "${OUTPUT_FORMAT}" in
  markdown) format_markdown "${ITEMS}" > "${OUTPUT_FILE}" ;;
  csv)      format_csv "${ITEMS}" > "${OUTPUT_FILE}" ;;
  tsv)      format_tsv "${ITEMS}" > "${OUTPUT_FILE}" ;;
  json)     format_json "${ITEMS}" > "${OUTPUT_FILE}" ;;
esac

echo "ファイル出力: ${OUTPUT_FILE}"

# --- コンソールサマリー ---

print_summary "Project" "${PROJECT_TITLE} (#${PROJECT_NUMBER})" \
  "形式" "${OUTPUT_FORMAT}" \
  "フィルタ(type)" "${ITEM_TYPE}" \
  "フィルタ(state)" "${ITEM_STATE}" \
  "Issue" "${ISSUE_COUNT} 件" \
  "PR" "${PR_COUNT} 件" "合計" "${TOTAL_COUNT} 件" "出力先" "${OUTPUT_FILE}"

echo ""
echo "::notice::Project アイテムのエクスポートが完了しました（${TOTAL_COUNT} 件、形式: ${OUTPUT_FORMAT}）。"
