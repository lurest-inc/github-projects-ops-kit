#!/usr/bin/env bash
set -euo pipefail

# GitHub Project Item エクスポートスクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/export-project-items
#
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 読み取り権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number
#   OUTPUT_FORMAT  - 出力形式（markdown / csv / tsv / json、デフォルト: markdown）
#   ITEM_TYPE      - 対象 Item の種別（all / issues / prs、デフォルト: all）
#   ITEM_STATE     - 取得する Item の状態（open / closed / all、デフォルト: all）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_analysis_env "markdown"

# --- フォーマッター関数 ---

format_markdown() {
  local items="$1"
  local issue_count pr_count
  read -r issue_count pr_count < <(echo "${items}" | jq -r '[([.[] | select(.type == "Issue")] | length), ([.[] | select(.type == "PullRequest")] | length)] | @tsv')

  # Markdown テーブル行の jq フィルタ（特殊文字をエスケープし、日付を YYYY-MM-DD に変換）
  local md_row_filter="${JQ_MD_ESCAPE}"'
    "| [#\(.number)](\(.url)) | \(.title | md_escape) | \(.state) | \(.repository) | \(.author) | \(.assignees | md_escape) | \(.labels | md_escape) | \(.created_at | split("T")[0]) | \(.updated_at | split("T")[0]) |"'

  {
    echo "# Project Item 一覧"
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
      echo "| # | タイトル | 状態 | Repository | 作成者 | アサイン | ラベル | 作成日 | 更新日 |"
      echo "|---|---------|------|-----------|--------|---------|--------|--------|--------|"
      echo "${items}" | jq -r ".[] | select(.type == \"Issue\") | ${md_row_filter}"
      echo ""
    fi

    if [[ "${pr_count}" -gt 0 ]]; then
      echo "## Pull Requests"
      echo ""
      echo "| # | タイトル | 状態 | Repository | 作成者 | アサイン | ラベル | 作成日 | 更新日 |"
      echo "|---|---------|------|-----------|--------|---------|--------|--------|--------|"
      echo "${items}" | jq -r ".[] | select(.type == \"PullRequest\") | ${md_row_filter}"
      echo ""
    fi
  }
}

format_csv() {
  local items="$1"
  format_items_csv \
    "type,number,title,url,state,repository,author,assignees,labels,created_at,updated_at" \
    '.[] | [.type, .number, .title, .url, .state, .repository, .author, .assignees, .labels, .created_at, .updated_at]' \
    "${items}"
}

format_tsv() {
  local items="$1"
  format_items_tsv \
    "type\tnumber\ttitle\turl\tstate\trepository\tauthor\tassignees\tlabels\tcreated_at\tupdated_at" \
    '.[] | [.type, (.number | tostring), .title, .url, .state, .repository, .author, .assignees, .labels, .created_at, .updated_at]' \
    "${items}"
}

# --- Item 取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の Item を取得しています..."
PROJECT_TITLE=""

EXPORT_QUERY_TEMPLATE=$(cat <<'GRAPHQL'
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

EXPORT_NORMALIZE_FILTER='[.data.[($owner)].projectV2.items.nodes[]
  | select(.content != null)
  | select(.content.__typename != null)
  | {
      type:       .content.__typename,
      number:     .content.number,
      title:      .content.title,
      url:        .content.url,
      state:      .content.state,
      repository: .content.repository.nameWithOwner,
      author:     (.content.author.login // ""),
      assignees:  ([.content.assignees.nodes[].login] | join(", ")),
      labels:     ([.content.labels.nodes[].name] | join(", ")),
      created_at: .content.createdAt,
      updated_at: .content.updatedAt
    }]'

ITEMS=$(fetch_all_project_items "${EXPORT_QUERY_TEMPLATE}" "${EXPORT_NORMALIZE_FILTER}" 50)

TOTAL_BEFORE_FILTER=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_BEFORE_FILTER} 件（フィルタ前）"

# --- type / state フィルタリング ---

# type / state フィルタを一括適用
ITEMS=$(echo "${ITEMS}" | filter_items)

read -r TOTAL_COUNT ISSUE_COUNT PR_COUNT < <(echo "${ITEMS}" | jq -r '[length, ([.[] | select(.type == "Issue")] | length), ([.[] | select(.type == "PullRequest")] | length)] | @tsv')

echo "  合計: ${TOTAL_COUNT} 件（Issue: ${ISSUE_COUNT}, PR: ${PR_COUNT}）"

if [[ "${TOTAL_COUNT}" -eq 0 ]]; then
  echo "::warning::対象の Issue / Pull Request が見つかりませんでした。"
fi

# --- フォーマット・出力 ---

echo ""
echo "出力形式: ${OUTPUT_FORMAT}"

OUTPUT_FILE=$(build_output_filename "export" "items")

case "${OUTPUT_FORMAT}" in
  markdown) format_markdown "${ITEMS}" > "${OUTPUT_FILE}" ;;
  csv)      format_csv "${ITEMS}" > "${OUTPUT_FILE}" ;;
  tsv)      format_tsv "${ITEMS}" > "${OUTPUT_FILE}" ;;
  json)     echo "${ITEMS}" | jq '.' > "${OUTPUT_FILE}" ;;
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
echo "::notice::Project Item のエクスポートが完了しました（${TOTAL_COUNT} 件、形式: ${OUTPUT_FORMAT}）。"
