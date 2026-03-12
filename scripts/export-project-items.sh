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
#   INCLUDE_ISSUES - Issue を対象にする（true / false、デフォルト: true）
#   INCLUDE_PRS    - Pull Request を対象にする（true / false、デフォルト: true）
#   ITEM_STATE     - 取得するアイテムの状態（open / closed / all、デフォルト: all）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_common_project_env

OUTPUT_FORMAT="${OUTPUT_FORMAT:-markdown}"
validate_enum "OUTPUT_FORMAT" "${OUTPUT_FORMAT}" "markdown" "csv" "tsv" "json"

INCLUDE_ISSUES="${INCLUDE_ISSUES:-true}"
INCLUDE_PRS="${INCLUDE_PRS:-true}"
ITEM_STATE="${ITEM_STATE:-all}"
validate_enum "INCLUDE_ISSUES" "${INCLUDE_ISSUES}" "true" "false"
validate_enum "INCLUDE_PRS" "${INCLUDE_PRS}" "true" "false"
validate_enum "ITEM_STATE" "${ITEM_STATE}" "open" "closed" "all"

# --- ヘルパー関数 ---

# Project のアイテム一覧を取得する（ページネーション対応）
fetch_project_items() {
  local all_items="[]"
  local cursor=""
  local has_next="true"
  local page=0
  local max_pages=50

  while [[ "${has_next}" == "true" ]]; do
    page=$((page + 1))
    if [[ "${page}" -gt "${max_pages}" ]]; then
      echo "::warning::ページネーション上限（${max_pages} ページ）に達しました。一部のアイテムが取得されていない可能性があります。" >&2
      break
    fi

    local after_clause=""
    if [[ -n "${cursor}" ]]; then
      after_clause=", after: \"${cursor}\""
    fi

    local query
    query=$(cat <<GRAPHQL
query {
  ${OWNER_QUERY_FIELD}(login: "${PROJECT_OWNER}") {
    projectV2(number: ${PROJECT_NUMBER}) {
      title
      items(first: 100${after_clause}) {
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
              assignees(first: 10) { nodes { login } }
              labels(first: 10) { nodes { name } }
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
              assignees(first: 10) { nodes { login } }
              labels(first: 10) { nodes { name } }
            }
          }
        }
      }
    }
  }
}
GRAPHQL
)

    local result
    if ! result=$(gh api graphql -f query="${query}" 2>&1); then
      local safe_result
      safe_result=$(sanitize_for_workflow_command "${result}")
      echo "::error::GraphQL API の呼び出しに失敗しました: ${safe_result}" >&2
      return 1
    fi

    # GraphQL エラーチェック（他スクリプトと統一）
    if echo "${result}" | jq -e '.errors and (.errors | length > 0)' >/dev/null 2>&1; then
      local safe_errors
      safe_errors=$(sanitize_for_workflow_command "$(echo "${result}" | jq -c '.errors')")
      echo "::error::GraphQL エラーが発生しました: ${safe_errors}" >&2
      return 1
    fi

    # Project の存在チェック（初回のみ）
    if [[ "${page}" -eq 1 ]]; then
      local project_id
      project_id=$(echo "${result}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.title // empty" 2>/dev/null || true)
      if [[ -z "${project_id}" ]]; then
        echo "::error::Project が見つかりません。PROJECT_OWNER（${PROJECT_OWNER}）と PROJECT_NUMBER（${PROJECT_NUMBER}）を確認してください。" >&2
        return 1
      fi
      PROJECT_TITLE="${project_id}"
    fi

    # アイテムを正規化して追加（DraftIssue を除外し、統一フォーマットに変換）
    local normalize_filter
    normalize_filter="[.data.${OWNER_QUERY_FIELD}.projectV2.items.nodes[]
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
    page_items=$(echo "${result}" | jq "${normalize_filter}" 2>/dev/null || echo "[]")

    local page_count
    page_count=$(echo "${page_items}" | jq 'length')
    echo "  ページ ${page} 取得完了（${page_count} 件）" >&2

    all_items=$(echo "${all_items}" "${page_items}" | jq -s '.[0] + .[1]')

    has_next=$(echo "${result}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.items.pageInfo.hasNextPage" 2>/dev/null || echo "false")
    cursor=$(echo "${result}" | jq -r ".data.${OWNER_QUERY_FIELD}.projectV2.items.pageInfo.endCursor // empty" 2>/dev/null || true)
  done

  echo "${all_items}"
}

# --- フォーマッター関数 ---

format_markdown() {
  local items="$1"
  local issue_count pr_count
  issue_count=$(echo "${items}" | jq '[.[] | select(.type == "Issue")] | length')
  pr_count=$(echo "${items}" | jq '[.[] | select(.type == "PullRequest")] | length')

  # Markdown テーブルセル用エスケープ関数（jq 内で使用）
  # パイプ文字および Markdown 特殊文字（\, `, *, _, [, ], <, >, ~）をバックスラッシュでエスケープ
  local md_escape='def md_escape: gsub("\\\\"; "\\\\") | gsub("`"; "\\`") | gsub("\\*"; "\\*") | gsub("_"; "\\_") | gsub("\\["; "\\[") | gsub("\\]"; "\\]") | gsub("<"; "\\<") | gsub(">"; "\\>") | gsub("~"; "\\~") | gsub("\\|"; "\\|");'

  # Markdown テーブル行の jq フィルタ（特殊文字をエスケープし、日付を YYYY-MM-DD に変換）
  local md_row_filter="${md_escape}"'
    "| [#\(.number)](\(.url)) | \(.title | md_escape) | \(.state) | \(.repository) | \(.author) | \(.assignees | md_escape) | \(.labels | md_escape) | \(.created_at | split("T")[0]) | \(.updated_at | split("T")[0]) |"'

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
      echo "| # | タイトル | 状態 | リポジトリ | 作成者 | アサイン | ラベル | 作成日 | 更新日 |"
      echo "|---|---------|------|-----------|--------|---------|--------|--------|--------|"
      echo "${items}" | jq -r ".[] | select(.type == \"Issue\") | ${md_row_filter}"
      echo ""
    fi

    if [[ "${pr_count}" -gt 0 ]]; then
      echo "## Pull Requests"
      echo ""
      echo "| # | タイトル | 状態 | リポジトリ | 作成者 | アサイン | ラベル | 作成日 | 更新日 |"
      echo "|---|---------|------|-----------|--------|---------|--------|--------|--------|"
      echo "${items}" | jq -r ".[] | select(.type == \"PullRequest\") | ${md_row_filter}"
      echo ""
    fi
  }
}

format_csv() {
  local items="$1"
  echo "type,number,title,url,state,repository,author,assignees,labels,created_at,updated_at"
  echo "${items}" | jq -r '.[] | [.type, .number, .title, .url, .state, .repository, .author, .assignees, .labels, .created_at, .updated_at] | @csv'
}

format_tsv() {
  local items="$1"
  echo -e "type\tnumber\ttitle\turl\tstate\trepository\tauthor\tassignees\tlabels\tcreated_at\tupdated_at"
  echo "${items}" | jq -r '.[] | [.type, (.number | tostring), .title, .url, .state, .repository, .author, .assignees, .labels, .created_at, .updated_at] | @tsv'
}

format_json() {
  local items="$1"
  echo "${items}" | jq '.'
}

# --- アイテム取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} のアイテムを取得しています..."
PROJECT_TITLE=""
ITEMS=$(fetch_project_items)

TOTAL_BEFORE_FILTER=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_BEFORE_FILTER} 件（フィルタ前）"

# --- type / state フィルタリング ---

# type / state フィルタを 1 回の jq 実行で適用
ITEMS=$(echo "${ITEMS}" | jq \
  --argjson includeIssues "$( [[ "${INCLUDE_ISSUES}" == "true" ]] && echo true || echo false )" \
  --argjson includePRs "$( [[ "${INCLUDE_PRS}" == "true" ]] && echo true || echo false )" \
  --arg itemState "${ITEM_STATE}" '
  map(
    select(
      # type フィルタ
      ( ($includeIssues or .type != "Issue")
        and ($includePRs or .type != "PullRequest")
      )
      and
      # state フィルタ（closed は CLOSED + MERGED を含む）
      ( $itemState == "all"
        or ($itemState == "open" and .state == "OPEN")
        or ($itemState == "closed" and (.state == "CLOSED" or .state == "MERGED"))
      )
    )
  )
')

TOTAL_COUNT=$(echo "${ITEMS}" | jq 'length')
ISSUE_COUNT=$(echo "${ITEMS}" | jq '[.[] | select(.type == "Issue")] | length')
PR_COUNT=$(echo "${ITEMS}" | jq '[.[] | select(.type == "PullRequest")] | length')

echo "  合計: ${TOTAL_COUNT} 件（Issue: ${ISSUE_COUNT}, PR: ${PR_COUNT}）"

if [[ "${TOTAL_COUNT}" -eq 0 ]]; then
  echo "::warning::対象の Issue / Pull Request が見つかりませんでした。"
fi

# --- フォーマット・出力 ---

echo ""
echo "出力形式: ${OUTPUT_FORMAT}"

case "${OUTPUT_FORMAT}" in
  markdown) FILE_EXT="md" ;;
  csv)      FILE_EXT="csv" ;;
  tsv)      FILE_EXT="tsv" ;;
  json)     FILE_EXT="json" ;;
esac

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
  "フィルタ(type)" "Issue=${INCLUDE_ISSUES}, PR=${INCLUDE_PRS}" \
  "フィルタ(state)" "${ITEM_STATE}" \
  "Issue" "${ISSUE_COUNT} 件" \
  "PR" "${PR_COUNT} 件" "合計" "${TOTAL_COUNT} 件" "出力先" "${OUTPUT_FILE}"

echo ""
echo "::notice::Project アイテムのエクスポートが完了しました（${TOTAL_COUNT} 件、形式: ${OUTPUT_FORMAT}）。"
