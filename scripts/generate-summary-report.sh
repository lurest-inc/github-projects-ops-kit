#!/usr/bin/env bash
set -euo pipefail

# Project サマリーレポート生成スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/generate-summary-report
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

# --- バリデーション ---

validate_analysis_env

# --- Item 取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の Item を取得しています..."
PROJECT_TITLE=""

SUMMARY_QUERY_TEMPLATE=$(cat <<'GRAPHQL'
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
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldNumberValue {
                number
                field { ... on ProjectV2FieldCommon { name } }
              }
              ... on ProjectV2ItemFieldDateValue {
                date
                field { ... on ProjectV2FieldCommon { name } }
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

SUMMARY_NORMALIZE_FILTER='[.data.[($owner)].projectV2.items.nodes[]
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
      assignees:  [.content.assignees.nodes[].login],
      labels:     [.content.labels.nodes[].name],
      created_at: .content.createdAt,
      updated_at: .content.updatedAt,
      status:     ([.fieldValues.nodes[] | select(.field.name == "Status") | .name] | first // null),
      estimated_hours: ([.fieldValues.nodes[] | select(.field.name == "見積もり工数(h)") | .number] | first // null),
      actual_hours:    ([.fieldValues.nodes[] | select(.field.name == "実績工数(h)") | .number] | first // null),
      due_date:        ([.fieldValues.nodes[] | select(.field.name == "終了期日") | .date] | first // null)
    }]'

ITEMS=$(fetch_all_project_items "${SUMMARY_QUERY_TEMPLATE}" "${SUMMARY_NORMALIZE_FILTER}" 50)

TOTAL_BEFORE_FILTER=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_BEFORE_FILTER} 件（フィルタ前）"

# --- フィルタリング ---

ITEMS=$(echo "${ITEMS}" | filter_items)

TOTAL_COUNT=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_COUNT} 件（フィルタ後）"

# --- 基本集計 ---

echo ""
echo "集計処理を実行しています..."

EXECUTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date -u +"%Y-%m-%d")

# タイプ別・状態別件数（1 回の jq で算出）
read -r ISSUE_COUNT PR_COUNT OPEN_COUNT CLOSED_COUNT MERGED_COUNT < <(echo "${ITEMS}" | jq -r '[
  ([.[] | select(.type == "Issue")] | length),
  ([.[] | select(.type == "PullRequest")] | length),
  ([.[] | select(.state == "OPEN")] | length),
  ([.[] | select(.state == "CLOSED")] | length),
  ([.[] | select(.state == "MERGED")] | length)
] | @tsv')

# ステータス別集計
STATUS_SUMMARY=$(echo "${ITEMS}" | jq --argjson total "${TOTAL_COUNT}" "${JQ_STATUS_ORDER}"'
  sort_by(.status // "(未設定)") | group_by(.status // "(未設定)")
  | map({
      status: (.[0].status // "(未設定)"),
      count: length,
      percentage: (if $total > 0 then (length / $total * 1000 | round / 10) else 0 end)
    })
  | sort_by(status_order(.status))
')

# 担当者別集計
ASSIGNEE_SUMMARY=$(echo "${ITEMS}" | jq '
  [.[] | . as $item | (if (.assignees | length) == 0 then ["(未アサイン)"] else .assignees end)[] | {assignee: ., status: $item.status}]
  | sort_by(.assignee) | group_by(.assignee)
  | map({
      assignee: .[0].assignee,
      total: length,
      in_progress: ([.[] | select(.status == "In Progress")] | length),
      in_review: ([.[] | select(.status == "In Review")] | length)
    })
  | sort_by(-.total)
')

# ラベル別集計
LABEL_SUMMARY=$(echo "${ITEMS}" | jq '
  [.[] | . as $item | (if (.labels | length) == 0 then ["(ラベルなし)"] else .labels end)[] | {label: ., url: $item.url}]
  | sort_by(.label) | group_by(.label)
  | map({
      label: .[0].label,
      count: (map(.url) | unique | length)
    })
  | sort_by(-.count)
')

# Field 集計（工数）・期日超過 Item のフラグを 1 回の jq で判定
read -r HAS_EFFORT HAS_DUE_DATE < <(echo "${ITEMS}" | jq -r '[
  ([.[] | select(.estimated_hours != null or .actual_hours != null)] | length > 0),
  ([.[] | select(.due_date != null)] | length > 0)
] | @tsv')

EFFORT_SUMMARY=""
if [[ "${HAS_EFFORT}" == "true" ]]; then
  EFFORT_SUMMARY=$(echo "${ITEMS}" | jq "${JQ_STATUS_ORDER}"'
    sort_by(.status // "(未設定)") | group_by(.status // "(未設定)")
    | map({
        status: (.[0].status // "(未設定)"),
        estimated_hours: ([.[] | .estimated_hours // 0] | add),
        actual_hours: ([.[] | .actual_hours // 0] | add)
      })
    | sort_by(status_order(.status))
  ')
fi

OVERDUE_ITEMS="[]"
if [[ "${HAS_DUE_DATE}" == "true" ]]; then
  OVERDUE_ITEMS=$(echo "${ITEMS}" | jq --arg today "${TODAY}" '
    [.[] |
      select(.due_date != null) |
      select(.status != "Done") |
      select(.due_date < $today) |
      . + {
        days_overdue: ((($today | strptime("%Y-%m-%d") | mktime) - (.due_date | strptime("%Y-%m-%d") | mktime)) / 86400 | floor)
      }
    ] | sort_by(-.days_overdue)
  ')
fi

OVERDUE_COUNT=$(echo "${OVERDUE_ITEMS}" | jq 'length')

echo "  ステータス別: $(echo "${STATUS_SUMMARY}" | jq 'length') 件"
echo "  担当者別: $(echo "${ASSIGNEE_SUMMARY}" | jq 'length') 件"
echo "  ラベル別: $(echo "${LABEL_SUMMARY}" | jq 'length') 件"
echo "  期日超過: ${OVERDUE_COUNT} 件"

# --- 工数合計の計算（複数セクションで使用） ---

TOTAL_ESTIMATED=0
TOTAL_ACTUAL=0
if [[ "${HAS_EFFORT}" == "true" ]]; then
  read -r TOTAL_ESTIMATED TOTAL_ACTUAL < <(echo "${EFFORT_SUMMARY}" | jq -r '[([.[].estimated_hours] | add), ([.[].actual_hours] | add)] | @tsv')
fi

# --- フォーマッター関数 ---

format_summary_markdown() {
  {
    echo "# 📊 Project サマリーレポート"
    echo ""
    echo "- **Project:** ${PROJECT_TITLE} (#${PROJECT_NUMBER})"
    echo "- **実行日時:** ${EXECUTED_AT}"
    echo "- **総 Item 数:** ${TOTAL_COUNT} 件（Issue: ${ISSUE_COUNT}, PR: ${PR_COUNT}）"
    echo ""
    echo "---"
    echo ""

    # ステータス別
    echo "## ステータス別"
    echo ""
    echo "| ステータス | 件数 | 割合 |"
    echo "|---|---|---|"
    echo "${STATUS_SUMMARY}" | jq -r "${JQ_MD_ESCAPE}"'.[] | "| \(.status | md_escape) | \(.count) | \(.percentage)% |"'
    echo ""

    # Mermaid 円グラフ
    local has_nonzero
    has_nonzero=$(echo "${STATUS_SUMMARY}" | jq '[.[] | select(.count > 0)] | length')
    if [[ "${has_nonzero}" -gt 0 ]]; then
      echo '```mermaid'
      echo 'pie title ステータス別 Item 分布'
      echo "${STATUS_SUMMARY}" | jq -r '.[] | select(.count > 0) | "    \"\(.status | gsub("\""; "\\\"") | gsub("\\\\"; "\\\\"))\" : \(.count)"'
      echo '```'
      echo ""
    fi

    # 担当者別
    echo "## 担当者別"
    echo ""
    echo "| 担当者 | 件数 | In Progress | In Review |"
    echo "|---|---|---|---|"
    echo "${ASSIGNEE_SUMMARY}" | jq -r '.[] | "| \(.assignee) | \(.total) | \(.in_progress) | \(.in_review) |"'
    echo ""

    # ラベル別
    echo "## ラベル別"
    echo ""
    echo "| ラベル | 件数 |"
    echo "|---|---|"
    echo "${LABEL_SUMMARY}" | jq -r '.[] | "| \(.label) | \(.count) |"'
    echo ""

    # 工数サマリー
    if [[ "${HAS_EFFORT}" == "true" ]]; then
      echo "## 工数サマリー"
      echo ""
      echo "| ステータス | 見積もり工数(h) | 実績工数(h) |"
      echo "|---|---|---|"
      echo "${EFFORT_SUMMARY}" | jq -r "${JQ_MD_ESCAPE}"'.[] | "| \(.status | md_escape) | \(.estimated_hours) | \(.actual_hours) |"'
      echo "| **合計** | **${TOTAL_ESTIMATED}** | **${TOTAL_ACTUAL}** |"
      echo ""
    fi

    # 期日超過 Item
    if [[ "${HAS_DUE_DATE}" == "true" && "${OVERDUE_COUNT}" -gt 0 ]]; then
      local md_row_filter="${JQ_MD_ESCAPE}"'
        "| [#\(.number)](\(.url)) | \(.title | md_escape) | \((.status // \"-\") | md_escape) | \(if (.assignees | length) > 0 then (.assignees | join(\", \") | md_escape) else \"-\" end) | \(.due_date) | \(.days_overdue) |"'

      echo "## 期日超過 Item: ${OVERDUE_COUNT} 件"
      echo ""
      echo "| # | タイトル | ステータス | 担当者 | 終了期日 | 超過日数 |"
      echo "|---|---------|-----------|--------|---------|---------|"
      echo "${OVERDUE_ITEMS}" | jq -r ".[] | ${md_row_filter}"
      echo ""
    fi
  }
}

format_summary_csv() {
  local items="$1"
  format_items_csv \
    "type,number,title,url,state,repository,author,assignees,labels,created_at,updated_at,status,estimated_hours,actual_hours,due_date" \
    '.[] | [.type, .number, .title, .url, .state, .repository, .author, (.assignees | join("; ")), (.labels | join("; ")), .created_at, .updated_at, (.status // ""), (.estimated_hours // "" | tostring), (.actual_hours // "" | tostring), (.due_date // "")]' \
    "${items}"
}

format_summary_tsv() {
  local items="$1"
  format_items_tsv \
    "type\tnumber\ttitle\turl\tstate\trepository\tauthor\tassignees\tlabels\tcreated_at\tupdated_at\tstatus\testimated_hours\tactual_hours\tdue_date" \
    '.[] | [.type, (.number | tostring), .title, .url, .state, .repository, .author, (.assignees | join("; ")), (.labels | join("; ")), .created_at, .updated_at, (.status // ""), (.estimated_hours // "" | tostring), (.actual_hours // "" | tostring), (.due_date // "")]' \
    "${items}"
}

# --- レポート出力 ---

echo ""
echo "レポートを生成しています..."

OUTPUT_FILE=$(build_output_filename "report" "summary")

case "${OUTPUT_FORMAT}" in
  json)
    REPORT_JSON=$(jq -n \
      --arg project_title "${PROJECT_TITLE}" \
      --argjson project_number "${PROJECT_NUMBER}" \
      --arg executed_at "${EXECUTED_AT}" \
      --argjson total "${TOTAL_COUNT}" \
      --argjson issue_count "${ISSUE_COUNT}" \
      --argjson pr_count "${PR_COUNT}" \
      --argjson open_count "${OPEN_COUNT}" \
      --argjson closed_count "${CLOSED_COUNT}" \
      --argjson merged_count "${MERGED_COUNT}" \
      --argjson by_status "${STATUS_SUMMARY}" \
      --argjson by_assignee "${ASSIGNEE_SUMMARY}" \
      --argjson by_label "${LABEL_SUMMARY}" \
      --argjson overdue_items "${OVERDUE_ITEMS}" '
      {
        project: {
          title: $project_title,
          number: $project_number
        },
        executed_at: $executed_at,
        summary: {
          total: $total,
          by_type: {
            Issue: $issue_count,
            PullRequest: $pr_count
          },
          by_state: {
            OPEN: $open_count,
            CLOSED: $closed_count,
            MERGED: $merged_count
          }
        },
        by_status: $by_status,
        by_assignee: $by_assignee,
        by_label: $by_label,
        overdue_items: $overdue_items
      }
    ')

    # 工数データがある場合は effort セクションを追加
    if [[ "${HAS_EFFORT}" == "true" ]]; then
      REPORT_JSON=$(echo "${REPORT_JSON}" | jq \
        --argjson effort_by_status "${EFFORT_SUMMARY}" \
        --argjson total_estimated "${TOTAL_ESTIMATED}" \
        --argjson total_actual "${TOTAL_ACTUAL}" '
        . + {
          effort: {
            by_status: $effort_by_status,
            total_estimated: $total_estimated,
            total_actual: $total_actual
          }
        }
      ')
    fi

    echo "${REPORT_JSON}" > "${OUTPUT_FILE}"
    ;;
  markdown)
    format_summary_markdown > "${OUTPUT_FILE}"
    ;;
  csv)
    format_summary_csv "${ITEMS}" > "${OUTPUT_FILE}"
    ;;
  tsv)
    format_summary_tsv "${ITEMS}" > "${OUTPUT_FILE}"
    ;;
esac

echo "  出力: ${OUTPUT_FILE}（形式: ${OUTPUT_FORMAT}）"

# --- Workflow Summary 出力 ---

append_to_workflow_summary "${OUTPUT_FILE}" format_summary_markdown

# --- コンソールサマリー ---

print_summary "Project" "${PROJECT_TITLE} (#${PROJECT_NUMBER})" \
  "形式" "${OUTPUT_FORMAT}" \
  "フィルタ(type)" "${ITEM_TYPE}" \
  "フィルタ(state)" "${ITEM_STATE}" \
  "総 Item 数" "${TOTAL_COUNT} 件" \
  "Issue" "${ISSUE_COUNT} 件" \
  "PR" "${PR_COUNT} 件" \
  "期日超過" "${OVERDUE_COUNT} 件" \
  "出力先" "${OUTPUT_FILE}"

echo ""
echo "::notice::Project サマリーレポートの生成が完了しました（${TOTAL_COUNT} 件）。"
