#!/usr/bin/env bash
set -euo pipefail

# 滞留アイテム検知スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/detect-stale-items
#
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 読み取り権限が必要）
#   PROJECT_OWNER  - Project の所有者
#   PROJECT_NUMBER - 対象 Project の Number
#   ITEM_TYPE      - 対象アイテムの種別（all / issues / prs、デフォルト: all）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- スクリプト内定数 ---

STALE_DAYS_TODO=14
STALE_DAYS_IN_PROGRESS=7
STALE_DAYS_IN_REVIEW=3
EXCLUDE_LABELS="on-hold,blocked"
ITEM_TYPE="${ITEM_TYPE:-all}"

# --- バリデーション ---

validate_common_project_env
validate_enum "ITEM_TYPE" "${ITEM_TYPE}" "all" "issues" "prs"

# --- ヘルパー関数 ---

# 現在日時を UTC で取得（テスト用に環境変数で上書き可能）
get_now_epoch() {
  if [[ -n "${NOW_EPOCH:-}" ]]; then
    echo "${NOW_EPOCH}"
  else
    date -u +%s
  fi
}

# Project のアイテム一覧を取得する（ページネーション対応、Status フィールド値を含む）
fetch_project_items() {
  local all_items="[]"

  _on_stale_page() {
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

    # アイテムを正規化して追加（DraftIssue を除外し、Status フィールド値を含む統一フォーマットに変換）
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
          assignees:  ([.content.assignees.nodes[].login] | join(\", \")),
          labels:     [.content.labels.nodes[].name],
          updated_at: .content.updatedAt,
          status:     ([.fieldValues.nodes[] | select(.field.name == \"Status\") | .name] | first // null)
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
  local query
  query=$(apply_owner_field "${query_template}")

  local variables_json
  variables_json=$(jq -n \
    --arg login "${PROJECT_OWNER}" \
    --argjson number "${PROJECT_NUMBER}" \
    '{login: $login, number: $number}')

  if ! run_graphql_paginated "${query}" "Project アイテムの取得" "${variables_json}" \
    '.data.[($owner)].projectV2.items.pageInfo' _on_stale_page 50; then
    return 1
  fi

  echo "${all_items}"
}

# 除外ラベルの CSV を JSON 配列に変換
build_exclude_labels_json() {
  local labels_csv="$1"
  if [[ -z "${labels_csv}" ]]; then
    echo "[]"
    return
  fi
  echo "${labels_csv}" | jq -R '[split(",") | .[] | gsub("^\\s+|\\s+$"; "") | ascii_downcase]'
}

# --- アイテム取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} のアイテムを取得しています..."
PROJECT_TITLE=""
ITEMS=$(fetch_project_items)

TOTAL_BEFORE_FILTER=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_BEFORE_FILTER} 件（フィルタ前）"

# --- フィルタリング ---

echo ""
echo "フィルタリングを実行しています..."

# type フィルタを適用
ITEMS=$(echo "${ITEMS}" | jq \
  --argjson includeIssues "$(should_include_issues && echo true || echo false)" \
  --argjson includePRs "$(should_include_prs && echo true || echo false)" '
  map(select(
    ($includeIssues or .type != "Issue")
    and ($includePRs or .type != "PullRequest")
  ))
')

# 除外ステータス（Done, Backlog）および除外ラベルを適用
EXCLUDE_LABELS_JSON=$(build_exclude_labels_json "${EXCLUDE_LABELS}")

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

STALE_COUNT=$(echo "${STALE_ITEMS}" | jq 'length')
echo "  滞留アイテム: ${STALE_COUNT} 件"

# --- ステータス別集計 ---

read -r IN_REVIEW_COUNT IN_PROGRESS_COUNT TODO_COUNT < <(echo "${STALE_ITEMS}" | jq -r '
  [
    ([.[] | select(.status == "In Review")] | length),
    ([.[] | select(.status == "In Progress")] | length),
    ([.[] | select(.status == "Todo")] | length)
  ] | @tsv
')

# --- Artifact 用 JSON 出力 ---

echo ""
echo "レポートを生成しています..."

EXECUTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

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

OUTPUT_FILE="stale-items-report.json"
echo "${REPORT_JSON}" > "${OUTPUT_FILE}"
echo "  JSON 出力: ${OUTPUT_FILE}"

# --- Workflow Summary 出力 ---

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "# 滞留アイテムレポート"
    echo ""
    echo "- **Project:** ${PROJECT_TITLE} (#${PROJECT_NUMBER})"
    echo "- **実行日時:** ${EXECUTED_AT}"
    echo "- **検知件数:** ${STALE_COUNT} 件"
    echo ""

    md_row_filter="${JQ_MD_ESCAPE}"'
      "| [#\(.number)](\(.url)) | \(.title | md_escape) | \(.repository) | \(if .assignees == "" then "-" else (.assignees | md_escape) end) | \(.updated_at | split("T")[0]) | \(.days_stale) |"'

    if [[ "${STALE_COUNT}" -eq 0 ]]; then
      echo "> 滞留アイテムはありません。"
    else
      # In Review
      if [[ "${IN_REVIEW_COUNT}" -gt 0 ]]; then
        echo "## In Review（${STALE_DAYS_IN_REVIEW} 日以上）: ${IN_REVIEW_COUNT} 件"
        echo ""
        echo "| # | タイトル | リポジトリ | アサイン | 最終更新 | 経過日数 |"
        echo "|---|---------|-----------|---------|---------|---------|"
        echo "${STALE_ITEMS}" | jq -r "[.[] | select(.status == \"In Review\")] | sort_by(-.days_stale)[] | ${md_row_filter}"
        echo ""
      fi

      # In Progress
      if [[ "${IN_PROGRESS_COUNT}" -gt 0 ]]; then
        echo "## In Progress（${STALE_DAYS_IN_PROGRESS} 日以上）: ${IN_PROGRESS_COUNT} 件"
        echo ""
        echo "| # | タイトル | リポジトリ | アサイン | 最終更新 | 経過日数 |"
        echo "|---|---------|-----------|---------|---------|---------|"
        echo "${STALE_ITEMS}" | jq -r "[.[] | select(.status == \"In Progress\")] | sort_by(-.days_stale)[] | ${md_row_filter}"
        echo ""
      fi

      # Todo
      if [[ "${TODO_COUNT}" -gt 0 ]]; then
        echo "## Todo（${STALE_DAYS_TODO} 日以上）: ${TODO_COUNT} 件"
        echo ""
        echo "| # | タイトル | リポジトリ | アサイン | 最終更新 | 経過日数 |"
        echo "|---|---------|-----------|---------|---------|---------|"
        echo "${STALE_ITEMS}" | jq -r "[.[] | select(.status == \"Todo\")] | sort_by(-.days_stale)[] | ${md_row_filter}"
        echo ""
      fi
    fi
  } >> "${GITHUB_STEP_SUMMARY}"
fi

# --- コンソールサマリー ---

print_summary "Project" "${PROJECT_TITLE} (#${PROJECT_NUMBER})" \
  "フィルタ(type)" "${ITEM_TYPE}" \
  "検知件数" "${STALE_COUNT} 件" \
  "In Review" "${IN_REVIEW_COUNT} 件（${STALE_DAYS_IN_REVIEW} 日以上）" \
  "In Progress" "${IN_PROGRESS_COUNT} 件（${STALE_DAYS_IN_PROGRESS} 日以上）" \
  "Todo" "${TODO_COUNT} 件（${STALE_DAYS_TODO} 日以上）" \
  "出力先" "${OUTPUT_FILE}"

echo ""
if [[ "${STALE_COUNT}" -gt 0 ]]; then
  echo "::warning::${STALE_COUNT} 件の滞留アイテムが検知されました。"
else
  echo "::notice::滞留アイテムは検知されませんでした。"
fi
