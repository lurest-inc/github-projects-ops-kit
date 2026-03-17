#!/usr/bin/env bash
set -euo pipefail

# プロジェクトサマリーレポート生成スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/generate-summary-report
#
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 読み取り権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number
#   ITEM_TYPE      - 対象アイテムの種別（all / issues / prs、デフォルト: all）
#   OUTPUT_FORMAT  - 出力形式（json / markdown / csv / tsv、デフォルト: json）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- スクリプト内定数 ---

ITEM_TYPE="${ITEM_TYPE:-all}"

# --- バリデーション ---

validate_common_project_env
validate_enum "ITEM_TYPE" "${ITEM_TYPE}" "all" "issues" "prs"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
validate_enum "OUTPUT_FORMAT" "${OUTPUT_FORMAT}" "markdown" "csv" "tsv" "json"

# --- ヘルパー関数 ---

# Project のアイテム一覧を取得する（ページネーション対応、フィールド値を含む）
fetch_project_items() {
  local all_items="[]"

  _on_summary_page() {
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

    # アイテムを正規化して追加（DraftIssue を除外し、フィールド値を含む統一フォーマットに変換）
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
          assignees:  [.content.assignees.nodes[].login],
          labels:     [.content.labels.nodes[].name],
          created_at: .content.createdAt,
          updated_at: .content.updatedAt,
          status:     ([.fieldValues.nodes[] | select(.field.name == \"Status\") | .name] | first // null),
          estimated_hours: ([.fieldValues.nodes[] | select(.field.name == \"見積もり工数(h)\") | .number] | first // null),
          actual_hours:    ([.fieldValues.nodes[] | select(.field.name == \"実績工数(h)\") | .number] | first // null),
          due_date:        ([.fieldValues.nodes[] | select(.field.name == \"終了期日\") | .date] | first // null)
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
  local query
  query=$(apply_owner_field "${query_template}")

  local variables_json
  variables_json=$(jq -n \
    --arg login "${PROJECT_OWNER}" \
    --argjson number "${PROJECT_NUMBER}" \
    '{login: $login, number: $number}')

  if ! run_graphql_paginated "${query}" "Project アイテムの取得" "${variables_json}" \
    '.data.[($owner)].projectV2.items.pageInfo' _on_summary_page 50; then
    return 1
  fi

  echo "${all_items}"
}

# --- アイテム取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} のアイテムを取得しています..."
PROJECT_TITLE=""
ITEMS=$(fetch_project_items)

TOTAL_BEFORE_FILTER=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_BEFORE_FILTER} 件（フィルタ前）"

# --- type フィルタリング ---

ITEMS=$(echo "${ITEMS}" | filter_items_by_type)

TOTAL_COUNT=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_COUNT} 件（フィルタ後）"

# --- 基本集計 ---

echo ""
echo "集計処理を実行しています..."

EXECUTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TODAY=$(date -u +"%Y-%m-%d")

# タイプ別・状態別件数
read -r ISSUE_COUNT PR_COUNT < <(echo "${ITEMS}" | jq -r '[
  ([.[] | select(.type == "Issue")] | length),
  ([.[] | select(.type == "PullRequest")] | length)
] | @tsv')

read -r OPEN_COUNT CLOSED_COUNT MERGED_COUNT < <(echo "${ITEMS}" | jq -r '[
  ([.[] | select(.state == "OPEN")] | length),
  ([.[] | select(.state == "CLOSED")] | length),
  ([.[] | select(.state == "MERGED")] | length)
] | @tsv')

# ステータス別集計
STATUS_SUMMARY=$(echo "${ITEMS}" | jq --argjson total "${TOTAL_COUNT}" '
  sort_by(.status // "(未設定)") | group_by(.status // "(未設定)")
  | map({
      status: .[0].status // "(未設定)",
      count: length,
      percentage: (if $total > 0 then (length / $total * 1000 | round / 10) else 0 end)
    })
  | sort_by(
      if .status == "Backlog" then 0
      elif .status == "Todo" then 1
      elif .status == "In Progress" then 2
      elif .status == "In Review" then 3
      elif .status == "Done" then 4
      else 5 end
    )
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

# カスタムフィールド集計（工数）
HAS_EFFORT=$(echo "${ITEMS}" | jq '[.[] | select(.estimated_hours != null or .actual_hours != null)] | length > 0')

EFFORT_SUMMARY=""
if [[ "${HAS_EFFORT}" == "true" ]]; then
  EFFORT_SUMMARY=$(echo "${ITEMS}" | jq '
    sort_by(.status // "(未設定)") | group_by(.status // "(未設定)")
    | map({
        status: .[0].status // "(未設定)",
        estimated_hours: ([.[] | .estimated_hours // 0] | add),
        actual_hours: ([.[] | .actual_hours // 0] | add)
      })
    | sort_by(
        if .status == "Backlog" then 0
        elif .status == "Todo" then 1
        elif .status == "In Progress" then 2
        elif .status == "In Review" then 3
        elif .status == "Done" then 4
        else 5 end
      )
  ')
fi

# 期日超過アイテム
HAS_DUE_DATE=$(echo "${ITEMS}" | jq '[.[] | select(.due_date != null)] | length > 0')

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
  TOTAL_ESTIMATED=$(echo "${EFFORT_SUMMARY}" | jq '[.[].estimated_hours] | add')
  TOTAL_ACTUAL=$(echo "${EFFORT_SUMMARY}" | jq '[.[].actual_hours] | add')
fi

# --- フォーマッター関数 ---

format_summary_markdown() {
  {
    echo "# 📊 プロジェクトサマリーレポート"
    echo ""
    echo "- **Project:** ${PROJECT_TITLE} (#${PROJECT_NUMBER})"
    echo "- **実行日時:** ${EXECUTED_AT}"
    echo "- **総アイテム数:** ${TOTAL_COUNT} 件（Issue: ${ISSUE_COUNT}, PR: ${PR_COUNT}）"
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
      echo 'pie title ステータス別アイテム分布'
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

    # 期日超過アイテム
    if [[ "${HAS_DUE_DATE}" == "true" && "${OVERDUE_COUNT}" -gt 0 ]]; then
      local md_row_filter="${JQ_MD_ESCAPE}"'
        "| [#\(.number)](\(.url)) | \(.title | md_escape) | \((.status // \"-\") | md_escape) | \(if (.assignees | length) > 0 then (.assignees | join(\", \") | md_escape) else \"-\" end) | \(.due_date) | \(.days_overdue) |"'

      echo "## 期日超過アイテム: ${OVERDUE_COUNT} 件"
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
  echo "type,number,title,url,state,repository,author,assignees,labels,created_at,updated_at,status,estimated_hours,actual_hours,due_date"
  echo "${items}" | jq -r '.[] | [.type, .number, .title, .url, .state, .repository, .author, (.assignees | join("; ")), (.labels | join("; ")), .created_at, .updated_at, (.status // ""), (.estimated_hours // "" | tostring), (.actual_hours // "" | tostring), (.due_date // "")] | @csv'
}

format_summary_tsv() {
  local items="$1"
  echo -e "type\tnumber\ttitle\turl\tstate\trepository\tauthor\tassignees\tlabels\tcreated_at\tupdated_at\tstatus\testimated_hours\tactual_hours\tdue_date"
  echo "${items}" | jq -r '.[] | [.type, (.number | tostring), .title, .url, .state, .repository, .author, (.assignees | join("; ")), (.labels | join("; ")), .created_at, .updated_at, (.status // ""), (.estimated_hours // "" | tostring), (.actual_hours // "" | tostring), (.due_date // "")] | @tsv'
}

# --- レポート出力 ---

echo ""
echo "レポートを生成しています..."

FILE_EXT=$(get_file_extension "${OUTPUT_FORMAT}")
OUTPUT_FILE="report-${PROJECT_NUMBER}-summary.${FILE_EXT}"

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

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  format_summary_markdown >> "${GITHUB_STEP_SUMMARY}"
fi

# --- コンソールサマリー ---

print_summary "Project" "${PROJECT_TITLE} (#${PROJECT_NUMBER})" \
  "形式" "${OUTPUT_FORMAT}" \
  "フィルタ(type)" "${ITEM_TYPE}" \
  "総アイテム数" "${TOTAL_COUNT} 件" \
  "Issue" "${ISSUE_COUNT} 件" \
  "PR" "${PR_COUNT} 件" \
  "期日超過" "${OVERDUE_COUNT} 件" \
  "出力先" "${OUTPUT_FILE}"

echo ""
echo "::notice::プロジェクトサマリーレポートの生成が完了しました（${TOTAL_COUNT} 件）。"
