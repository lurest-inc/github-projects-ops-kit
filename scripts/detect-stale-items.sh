#!/usr/bin/env bash
set -euo pipefail

# 滞留 Item 検知スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/detect-stale-items
#
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 読み取り権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number
#   ITEM_TYPE      - 対象 Item の種別（all / issues / prs、デフォルト: all）
#   ITEM_STATE     - 対象 Item の状態（open / closed / all、デフォルト: all）
#   OUTPUT_FORMAT  - 出力形式（json / markdown / csv / tsv、デフォルト: json）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- スクリプト内定数 ---

STALE_DAYS_TODO=14
STALE_DAYS_IN_PROGRESS=7
STALE_DAYS_IN_REVIEW=3
EXCLUDE_LABELS="on-hold,blocked"

# --- バリデーション ---

validate_analysis_env

# --- ヘルパー関数 ---

# 現在日時を UTC で取得（テスト用に環境変数で上書き可能）
get_now_epoch() {
  if [[ -n "${NOW_EPOCH:-}" ]]; then
    echo "${NOW_EPOCH}"
  else
    date -u +%s
  fi
}

# --- Item 取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の Item を取得しています..."
PROJECT_TITLE=""

STALE_QUERY_TEMPLATE=$(cat <<'GRAPHQL'
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
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field {
                  ... on ProjectV2FieldCommon {
                    name
                  }
                }
              }
            }
          }
          content {
            ... on Issue {
              __typename
              number
              title
              url
              state
              updatedAt
              repository { nameWithOwner }
              assignees(first: 10) { nodes { login } }
              labels(first: 20) { nodes { name } }
            }
            ... on PullRequest {
              __typename
              number
              title
              url
              state
              updatedAt
              repository { nameWithOwner }
              assignees(first: 10) { nodes { login } }
              labels(first: 20) { nodes { name } }
            }
          }
        }
      }
    }
  }
}
GRAPHQL
)

STALE_NORMALIZE_FILTER='[.data.[($owner)].projectV2.items.nodes[]
  | select(.content != null)
  | select(.content.__typename != null)
  | {
      type:       .content.__typename,
      number:     .content.number,
      title:      .content.title,
      url:        .content.url,
      state:      .content.state,
      repository: .content.repository.nameWithOwner,
      assignees:  ([.content.assignees.nodes[].login] | join(", ")),
      labels:     [.content.labels.nodes[].name],
      updated_at: .content.updatedAt,
      status:     ([.fieldValues.nodes[] | select(.field.name == "Status") | .name] | first // null)
    }]'

ITEMS=$(fetch_all_project_items "${STALE_QUERY_TEMPLATE}" "${STALE_NORMALIZE_FILTER}" 50)

TOTAL_BEFORE_FILTER=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_BEFORE_FILTER} 件（フィルタ前）"

# --- フィルタリング ---

echo ""
echo "フィルタリングを実行しています..."

# type / state フィルタを一括適用
ITEMS=$(echo "${ITEMS}" | filter_items)

# 除外ステータス（Done, Backlog）および除外ラベルを適用
EXCLUDE_LABELS_JSON=$(echo "${EXCLUDE_LABELS}" | jq -R '[split(",") | .[] | gsub("^\\s+|\\s+$"; "") | ascii_downcase]')

ITEMS=$(echo "${ITEMS}" | jq \
  --argjson exclude_labels "${EXCLUDE_LABELS_JSON}" '
  map(
    select(
      .status != null
      and .status != "Done"
      and .status != "Backlog"
      and ((.labels | map(ascii_downcase)) as $item_labels |
           ($exclude_labels | all(. as $el | $item_labels | index($el) | not)))
    )
  )
')

TOTAL_AFTER_FILTER=$(echo "${ITEMS}" | jq 'length')
echo "  フィルタ後: ${TOTAL_AFTER_FILTER} 件"

# --- 滞留判定 ---

echo ""
echo "滞留判定を実行しています..."

NOW_EPOCH=$(get_now_epoch)

# jq で滞留判定を実行
STALE_ITEMS=$(echo "${ITEMS}" | jq \
  --argjson now "${NOW_EPOCH}" \
  --argjson todo_days "${STALE_DAYS_TODO}" \
  --argjson in_progress_days "${STALE_DAYS_IN_PROGRESS}" \
  --argjson in_review_days "${STALE_DAYS_IN_REVIEW}" '
  [.[] |
    # ステータスに応じた閾値を設定
    (if .status == "Todo" then $todo_days
     elif .status == "In Progress" then $in_progress_days
     elif .status == "In Review" then $in_review_days
     else null end) as $threshold |
    select($threshold != null) |
    # 経過日数を計算
    (($now - (.updated_at | fromdateiso8601)) / 86400 | floor) as $days_stale |
    select($days_stale >= $threshold) |
    . + {days_stale: $days_stale, threshold: $threshold}
  ]
')

# --- ステータス別集計 ---

read -r STALE_COUNT IN_REVIEW_COUNT IN_PROGRESS_COUNT TODO_COUNT < <(echo "${STALE_ITEMS}" | jq -r '
  [
    length,
    ([.[] | select(.status == "In Review")] | length),
    ([.[] | select(.status == "In Progress")] | length),
    ([.[] | select(.status == "Todo")] | length)
  ] | @tsv
')
echo "  滞留 Item: ${STALE_COUNT} 件"

# --- フォーマッター関数 ---

format_stale_markdown() {
  local stale_items="$1"

  local md_row_filter="${JQ_MD_ESCAPE}"'
    "| [#\(.number)](\(.url)) | \(.title | md_escape) | \(.repository) | \(if .assignees == "" then "-" else (.assignees | md_escape) end) | \(.updated_at | split("T")[0]) | \(.days_stale) |"'

  {
    echo "# 滞留 Item レポート"
    echo ""
    echo "- **Project:** ${PROJECT_TITLE} (#${PROJECT_NUMBER})"
    echo "- **実行日時:** ${EXECUTED_AT}"
    echo "- **検知件数:** ${STALE_COUNT} 件"
    echo ""

    if [[ "${STALE_COUNT}" -eq 0 ]]; then
      echo "> 滞留 Item はありません。"
    else
      if [[ "${IN_REVIEW_COUNT}" -gt 0 ]]; then
        echo "## In Review（${STALE_DAYS_IN_REVIEW} 日以上）: ${IN_REVIEW_COUNT} 件"
        echo ""
        echo "| # | タイトル | Repository | アサイン | 最終更新 | 経過日数 |"
        echo "|---|---------|-----------|---------|---------|---------|"
        echo "${stale_items}" | jq -r "[.[] | select(.status == \"In Review\")] | sort_by(-.days_stale)[] | ${md_row_filter}"
        echo ""
      fi

      if [[ "${IN_PROGRESS_COUNT}" -gt 0 ]]; then
        echo "## In Progress（${STALE_DAYS_IN_PROGRESS} 日以上）: ${IN_PROGRESS_COUNT} 件"
        echo ""
        echo "| # | タイトル | Repository | アサイン | 最終更新 | 経過日数 |"
        echo "|---|---------|-----------|---------|---------|---------|"
        echo "${stale_items}" | jq -r "[.[] | select(.status == \"In Progress\")] | sort_by(-.days_stale)[] | ${md_row_filter}"
        echo ""
      fi

      if [[ "${TODO_COUNT}" -gt 0 ]]; then
        echo "## Todo（${STALE_DAYS_TODO} 日以上）: ${TODO_COUNT} 件"
        echo ""
        echo "| # | タイトル | Repository | アサイン | 最終更新 | 経過日数 |"
        echo "|---|---------|-----------|---------|---------|---------|"
        echo "${stale_items}" | jq -r "[.[] | select(.status == \"Todo\")] | sort_by(-.days_stale)[] | ${md_row_filter}"
        echo ""
      fi
    fi
  }
}

format_stale_csv() {
  local stale_items="$1"
  format_items_csv \
    "type,number,title,url,status,repository,assignees,updated_at,days_stale,threshold" \
    '.[] | [.type, .number, .title, .url, .status, .repository, .assignees, .updated_at, .days_stale, .threshold]' \
    "${stale_items}"
}

format_stale_tsv() {
  local stale_items="$1"
  format_items_tsv \
    "type\tnumber\ttitle\turl\tstatus\trepository\tassignees\tupdated_at\tdays_stale\tthreshold" \
    '.[] | [.type, (.number | tostring), .title, .url, .status, .repository, .assignees, .updated_at, (.days_stale | tostring), (.threshold | tostring)]' \
    "${stale_items}"
}

# --- レポート出力 ---

echo ""
echo "レポートを生成しています..."

EXECUTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

FILE_EXT=$(get_file_extension "${OUTPUT_FORMAT}")
OUTPUT_FILE="stale-items-report.${FILE_EXT}"

case "${OUTPUT_FORMAT}" in
  json)
    # Artifact 用 JSON を生成
    REPORT_JSON=$(echo "${STALE_ITEMS}" | jq \
      --arg project_title "${PROJECT_TITLE}" \
      --argjson project_number "${PROJECT_NUMBER}" \
      --arg executed_at "${EXECUTED_AT}" \
      --argjson todo_days "${STALE_DAYS_TODO}" \
      --argjson in_progress_days "${STALE_DAYS_IN_PROGRESS}" \
      --argjson in_review_days "${STALE_DAYS_IN_REVIEW}" '
      {
        project: {
          title: $project_title,
          number: $project_number
        },
        executed_at: $executed_at,
        thresholds: {
          "Todo": $todo_days,
          "In Progress": $in_progress_days,
          "In Review": $in_review_days
        },
        summary: {
          total_stale: length,
          by_status: {
            "In Review": ([.[] | select(.status == "In Review")] | length),
            "In Progress": ([.[] | select(.status == "In Progress")] | length),
            "Todo": ([.[] | select(.status == "Todo")] | length)
          }
        },
        stale_items: [.[] | {
          type,
          number,
          title,
          url,
          status,
          repository,
          assignees: (.assignees | split(", ") | map(select(. != ""))),
          labels,
          updated_at,
          days_stale
        }]
      }
    ')
    echo "${REPORT_JSON}" > "${OUTPUT_FILE}"
    ;;
  markdown)
    format_stale_markdown "${STALE_ITEMS}" > "${OUTPUT_FILE}"
    ;;
  csv)
    format_stale_csv "${STALE_ITEMS}" > "${OUTPUT_FILE}"
    ;;
  tsv)
    format_stale_tsv "${STALE_ITEMS}" > "${OUTPUT_FILE}"
    ;;
esac

echo "  出力: ${OUTPUT_FILE}（形式: ${OUTPUT_FORMAT}）"

# --- Workflow Summary 出力 ---

append_to_workflow_summary "${OUTPUT_FILE}" format_stale_markdown "${STALE_ITEMS}"

# --- コンソールサマリー ---

print_summary "Project" "${PROJECT_TITLE} (#${PROJECT_NUMBER})" \
  "形式" "${OUTPUT_FORMAT}" \
  "フィルタ(type)" "${ITEM_TYPE}" \
  "フィルタ(state)" "${ITEM_STATE}" \
  "検知件数" "${STALE_COUNT} 件" \
  "In Review" "${IN_REVIEW_COUNT} 件（${STALE_DAYS_IN_REVIEW} 日以上）" \
  "In Progress" "${IN_PROGRESS_COUNT} 件（${STALE_DAYS_IN_PROGRESS} 日以上）" \
  "Todo" "${TODO_COUNT} 件（${STALE_DAYS_TODO} 日以上）" \
  "出力先" "${OUTPUT_FILE}"

echo ""
if [[ "${STALE_COUNT}" -gt 0 ]]; then
  echo "::warning::${STALE_COUNT} 件の滞留 Item が検知されました。"
else
  echo "::notice::滞留 Item は検知されませんでした。"
fi
