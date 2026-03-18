#!/usr/bin/env bash
set -euo pipefail

# 工数集計レポート生成スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/generate-effort-report
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

# --- 定数 ---

VARIANCE_THRESHOLD=10
VARIANCE_TOP_N=10

# --- バリデーション ---

validate_analysis_env

# --- Item 取得 ---

echo ""
echo "Project #${PROJECT_NUMBER} の Item を取得しています..."
PROJECT_TITLE=""

EFFORT_QUERY_TEMPLATE=$(cat <<'GRAPHQL'
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

EFFORT_NORMALIZE_FILTER='[.data.[($owner)].projectV2.items.nodes[]
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
      status:         ([.fieldValues.nodes[] | select(.field.name == "Status") | .name] | first // null),
      estimated_hours: ([.fieldValues.nodes[] | select(.field.name == "見積もり工数(h)") | .number] | first // null),
      actual_hours:    ([.fieldValues.nodes[] | select(.field.name == "実績工数(h)") | .number] | first // null),
      due_date:        ([.fieldValues.nodes[] | select(.field.name == "終了期日") | .date] | first // null),
      planned_start:   ([.fieldValues.nodes[] | select(.field.name == "開始予定") | .date] | first // null),
      planned_end:     ([.fieldValues.nodes[] | select(.field.name == "終了予定") | .date] | first // null),
      actual_start:    ([.fieldValues.nodes[] | select(.field.name == "開始実績") | .date] | first // null),
      actual_end:      ([.fieldValues.nodes[] | select(.field.name == "終了実績") | .date] | first // null)
    }]'

ITEMS=$(fetch_all_project_items "${EFFORT_QUERY_TEMPLATE}" "${EFFORT_NORMALIZE_FILTER}" 50)

TOTAL_BEFORE_FILTER=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_BEFORE_FILTER} 件（フィルタ前）"

# --- フィルタリング ---

ITEMS=$(echo "${ITEMS}" | filter_items)

TOTAL_COUNT=$(echo "${ITEMS}" | jq 'length')
echo "  合計: ${TOTAL_COUNT} 件（フィルタ後）"

# --- 工数集計 ---

echo ""
echo "工数集計を実行しています..."

EXECUTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 工数データの有無判定・全体サマリー（1 回の jq で算出）
read -r ITEMS_WITH_EFFORT_COUNT ITEMS_WITHOUT_EFFORT_COUNT TOTAL_ESTIMATED TOTAL_ACTUAL < <(echo "${ITEMS}" | jq -r '
  ([.[] | select(.estimated_hours != null or .actual_hours != null)] | length) as $with |
  ([.[] | select(.estimated_hours == null and .actual_hours == null)] | length) as $without |
  ([.[].estimated_hours // 0] | add // 0) as $est |
  ([.[].actual_hours // 0] | add // 0) as $act |
  [$with, $without, $est, $act] | @tsv
')

# 工数入力率
if [[ "${TOTAL_COUNT}" -gt 0 ]]; then
  EFFORT_INPUT_RATE=$(echo "${ITEMS_WITH_EFFORT_COUNT} ${TOTAL_COUNT}" | awk '{printf "%.1f", $1 / $2 * 100}')
else
  EFFORT_INPUT_RATE="0.0"
fi

# 全体乖離率
if [[ $(echo "${TOTAL_ESTIMATED}" | awk '{print ($1 > 0)}') -eq 1 ]]; then
  OVERALL_VARIANCE_RATE=$(echo "${TOTAL_ACTUAL} ${TOTAL_ESTIMATED}" | awk '{printf "%.1f", ($1 - $2) / $2 * 100}')
else
  OVERALL_VARIANCE_RATE="-"
fi

echo "  工数入力済み: ${ITEMS_WITH_EFFORT_COUNT} 件 / 未入力: ${ITEMS_WITHOUT_EFFORT_COUNT} 件"
echo "  総見積もり工数: ${TOTAL_ESTIMATED} h / 総実績工数: ${TOTAL_ACTUAL} h"

# 担当者別工数集計
ASSIGNEE_EFFORT=$(echo "${ITEMS}" | jq '
  [.[] | select(.estimated_hours != null or .actual_hours != null) | . as $item |
    (if (.assignees | length) == 0 then ["(未アサイン)"] else .assignees end)[]
    | {
        assignee: .,
        estimated_hours: $item.estimated_hours,
        actual_hours: $item.actual_hours
      }
  ]
  | sort_by(.assignee) | group_by(.assignee)
  | map({
      assignee: .[0].assignee,
      count: length,
      estimated_hours: ([.[].estimated_hours // 0] | add),
      actual_hours: ([.[].actual_hours // 0] | add),
      variance_rate: (
        if ([.[].estimated_hours // 0] | add) > 0 then
          ((([.[].actual_hours // 0] | add) - ([.[].estimated_hours // 0] | add)) / ([.[].estimated_hours // 0] | add) * 1000 | round / 10)
        else null end
      )
    })
  | sort_by(-.estimated_hours)
')

# ステータス別工数集計
STATUS_EFFORT=$(echo "${ITEMS}" | jq --argjson total_estimated "${TOTAL_ESTIMATED}" "${JQ_STATUS_ORDER}"'
  [.[] | select(.estimated_hours != null or .actual_hours != null)]
  | sort_by(.status // "(未設定)") | group_by(.status // "(未設定)")
  | map({
      status: (.[0].status // "(未設定)"),
      count: length,
      estimated_hours: ([.[].estimated_hours // 0] | add),
      actual_hours: ([.[].actual_hours // 0] | add)
    })
  | map(. + {
      consumption_rate: (
        if .status == "Done" and $total_estimated > 0 then
          (.actual_hours / $total_estimated * 1000 | round / 10)
        else null end
      )
    })
  | sort_by(status_order(.status))
')

# 乖離 Item 抽出（乖離率の絶対値が閾値以上）
VARIANCE_ITEMS=$(echo "${ITEMS}" | jq --argjson threshold "${VARIANCE_THRESHOLD}" --argjson top_n "${VARIANCE_TOP_N}" '
  [.[] | select(.estimated_hours != null and .estimated_hours > 0 and .actual_hours != null) |
    . + {
      variance_rate: ((.actual_hours - .estimated_hours) / .estimated_hours * 1000 | round / 10)
    }
  ]
  | [.[] | select((.variance_rate | fabs) >= $threshold)]
  | sort_by(-(.variance_rate | fabs)) | .[:$top_n]
')

VARIANCE_ITEMS_COUNT=$(echo "${VARIANCE_ITEMS}" | jq 'length')

echo "  担当者別: $(echo "${ASSIGNEE_EFFORT}" | jq 'length') 件"
echo "  ステータス別: $(echo "${STATUS_EFFORT}" | jq 'length') 件"
echo "  乖離 Item: ${VARIANCE_ITEMS_COUNT} 件"

# --- リードタイム分析（条件付き） ---

HAS_LEAD_TIME=$(echo "${ITEMS}" | jq '[.[] | select(.actual_start != null and .actual_end != null)] | length > 0')

LEAD_TIME_ITEMS="[]"
if [[ "${HAS_LEAD_TIME}" == "true" ]]; then
  echo ""
  echo "リードタイム分析を実行しています..."

  LEAD_TIME_ITEMS=$(echo "${ITEMS}" | jq '
    [.[] | select(.actual_start != null and .actual_end != null) |
      {
        type: .type,
        number: .number,
        title: .title,
        url: .url,
        assignees: .assignees,
        estimated_hours: .estimated_hours,
        actual_hours: .actual_hours,
        planned_start: .planned_start,
        planned_end: .planned_end,
        actual_start: .actual_start,
        actual_end: .actual_end,
        actual_days: (
          ((.actual_end | strptime("%Y-%m-%d") | mktime) -
           (.actual_start | strptime("%Y-%m-%d") | mktime)) / 86400 | floor
        ),
        planned_days: (
          if .planned_start != null and .planned_end != null then
            ((.planned_end | strptime("%Y-%m-%d") | mktime) -
             (.planned_start | strptime("%Y-%m-%d") | mktime)) / 86400 | floor
          else null end
        )
      }
      | . + {
          lead_time_variance: (
            if .planned_days != null then (.actual_days - .planned_days)
            else null end
          ),
          hours_per_day: (
            if .actual_days > 0 and .actual_hours != null then
              (.actual_hours / .actual_days * 10 | round / 10)
            else null end
          )
        }
    ] | sort_by(-.actual_days)
  ')

  echo "  リードタイム分析対象: $(echo "${LEAD_TIME_ITEMS}" | jq 'length') 件"
fi

# --- 工数未入力 Item 抽出 ---

MISSING_EFFORT_ITEMS=$(echo "${ITEMS}" | jq '
  [.[] | select(.estimated_hours == null and .actual_hours == null) |
    {
      type: .type,
      number: .number,
      title: .title,
      url: .url,
      status: .status,
      assignees: .assignees,
      is_done: (.status == "Done")
    }
  ]
  | sort_by(if .is_done then 0 else 1 end, .number)
')

MISSING_EFFORT_COUNT=$(echo "${MISSING_EFFORT_ITEMS}" | jq 'length')
MISSING_EFFORT_DONE_COUNT=$(echo "${MISSING_EFFORT_ITEMS}" | jq '[.[] | select(.is_done)] | length')

echo "  工数未入力: ${MISSING_EFFORT_COUNT} 件（うち Done: ${MISSING_EFFORT_DONE_COUNT} 件）"

# --- フォーマッター関数 ---

format_effort_markdown() {
  {
    echo "# 📊 工数集計レポート"
    echo ""
    echo "- **Project:** ${PROJECT_TITLE} (#${PROJECT_NUMBER})"
    echo "- **実行日時:** ${EXECUTED_AT}"
    echo "- **対象 Item 数:** ${TOTAL_COUNT} 件（工数入力済み: ${ITEMS_WITH_EFFORT_COUNT} 件、未入力: ${ITEMS_WITHOUT_EFFORT_COUNT} 件）"
    echo ""
    echo "---"
    echo ""

    # 全体サマリー
    echo "## 全体サマリー"
    echo ""
    echo "| 指標 | 値 |"
    echo "|---|---|"
    echo "| 総見積もり工数 | ${TOTAL_ESTIMATED} h |"
    echo "| 総実績工数 | ${TOTAL_ACTUAL} h |"
    if [[ "${OVERALL_VARIANCE_RATE}" != "-" ]]; then
      if [[ $(echo "${OVERALL_VARIANCE_RATE}" | awk '{print ($1 >= 0)}') -eq 1 ]]; then
        echo "| 全体乖離率 | +${OVERALL_VARIANCE_RATE}% |"
      else
        echo "| 全体乖離率 | ${OVERALL_VARIANCE_RATE}% |"
      fi
    else
      echo "| 全体乖離率 | - |"
    fi
    echo "| 工数入力率 | ${EFFORT_INPUT_RATE}% |"
    echo ""

    # 担当者別工数
    local assignee_count
    assignee_count=$(echo "${ASSIGNEE_EFFORT}" | jq 'length')
    if [[ "${assignee_count}" -gt 0 ]]; then
      echo "## 担当者別工数"
      echo ""
      echo "| 担当者 | Item 数 | 見積もり(h) | 実績(h) | 乖離率 |"
      echo "|---|---|---|---|---|"
      echo "${ASSIGNEE_EFFORT}" | jq -r '.[] | "| \(.assignee) | \(.count) | \(.estimated_hours) | \(.actual_hours) | \(if .variance_rate != null then (if .variance_rate >= 0 then "+\(.variance_rate)%" else "\(.variance_rate)%" end) else "-" end) |"'
      echo ""

      echo "> **Note:** 複数担当者がアサインされた Item は、各担当者に同一工数が計上されます。担当者別の合計は全体合計と一致しない場合があります。"
      echo ""

      # Mermaid 円グラフ
      local has_actual
      has_actual=$(echo "${ASSIGNEE_EFFORT}" | jq '[.[] | select(.actual_hours > 0)] | length')
      if [[ "${has_actual}" -gt 0 ]]; then
        echo '```mermaid'
        echo 'pie title 担当者別実績工数'
        echo "${ASSIGNEE_EFFORT}" | jq -r '.[] | select(.actual_hours > 0) | "    \"\(.assignee)\" : \(.actual_hours)"'
        echo '```'
        echo ""
      fi
    fi

    # ステータス別工数
    local status_count
    status_count=$(echo "${STATUS_EFFORT}" | jq 'length')
    if [[ "${status_count}" -gt 0 ]]; then
      echo "## ステータス別工数"
      echo ""
      echo "| ステータス | Item 数 | 見積もり(h) | 実績(h) | 消化率 |"
      echo "|---|---|---|---|---|"
      echo "${STATUS_EFFORT}" | jq -r "${JQ_MD_ESCAPE}"'.[] | "| \(.status | md_escape) | \(.count) | \(.estimated_hours) | \(.actual_hours) | \(if .consumption_rate != null then "\(.consumption_rate)%" else "-" end) |"'
      echo ""
    fi

    # 乖離 Item
    if [[ "${VARIANCE_ITEMS_COUNT}" -gt 0 ]]; then
      local md_row_filter="${JQ_MD_ESCAPE}"'
        "| [#\(.number)](\(.url)) | \(.title | md_escape) | \(if (.assignees | length) > 0 then (.assignees | join(", ")) else "-" end) | \(.estimated_hours) | \(.actual_hours) | \(if .variance_rate >= 0 then "+\(.variance_rate)%" else "\(.variance_rate)%" end) |"'

      echo "## 乖離 Item（上位）"
      echo ""
      echo "| # | タイトル | 担当者 | 見積もり(h) | 実績(h) | 乖離率 |"
      echo "|---|---|---|---|---|---|"
      echo "${VARIANCE_ITEMS}" | jq -r ".[] | ${md_row_filter}"
      echo ""
    fi

    # リードタイム分析
    if [[ "${HAS_LEAD_TIME}" == "true" ]]; then
      local lead_time_count
      lead_time_count=$(echo "${LEAD_TIME_ITEMS}" | jq 'length')
      if [[ "${lead_time_count}" -gt 0 ]]; then
        local md_row_filter="${JQ_MD_ESCAPE}"'
          "| [#\(.number)](\(.url)) | \(.title | md_escape) | \(if .planned_days != null then .planned_days else "-" end) | \(.actual_days) | \(if .lead_time_variance != null then (if .lead_time_variance >= 0 then "+\(.lead_time_variance)" else "\(.lead_time_variance)" end) else "-" end) | \(if .hours_per_day != null then .hours_per_day else "-" end) |"'

        echo "## リードタイム分析"
        echo ""
        echo "| # | タイトル | 計画(日) | 実績(日) | 乖離(日) | 日あたり工数(h) |"
        echo "|---|---|---|---|---|---|"
        echo "${LEAD_TIME_ITEMS}" | jq -r ".[] | ${md_row_filter}"
        echo ""
      fi
    fi

    # 工数未入力 Item
    if [[ "${MISSING_EFFORT_COUNT}" -gt 0 ]]; then
      local md_row_filter="${JQ_MD_ESCAPE}"'
        "| \(if .is_done then "**" else "" end)[#\(.number)](\(.url))\(if .is_done then "**" else "" end) | \(if .is_done then "**" else "" end)\(.title | md_escape)\(if .is_done then "**" else "" end) | \(if .is_done then "**" else "" end)\((.status // "-") | md_escape)\(if .is_done then "**" else "" end) | \(if (.assignees | length) > 0 then (.assignees | join(", ") | md_escape) else "-" end) |"'

      echo "## 工数未入力 Item: ${MISSING_EFFORT_COUNT} 件"
      echo ""
      if [[ "${MISSING_EFFORT_DONE_COUNT}" -gt 0 ]]; then
        echo "> **Warning:** Done ステータスで工数未入力の Item が ${MISSING_EFFORT_DONE_COUNT} 件あります（太字で表示）。"
        echo ""
      fi
      echo "| # | タイトル | ステータス | 担当者 |"
      echo "|---|---|---|---|"
      echo "${MISSING_EFFORT_ITEMS}" | jq -r ".[] | ${md_row_filter}"
      echo ""
    fi
  }
}

format_effort_csv() {
  local items="$1"
  echo "type,number,title,url,state,repository,author,assignees,labels,created_at,updated_at,status,estimated_hours,actual_hours,due_date,planned_start,planned_end,actual_start,actual_end"
  echo "${items}" | jq -r '.[] | [.type, .number, .title, .url, .state, .repository, .author, (.assignees | join("; ")), (.labels | join("; ")), .created_at, .updated_at, (.status // ""), (.estimated_hours // "" | tostring), (.actual_hours // "" | tostring), (.due_date // ""), (.planned_start // ""), (.planned_end // ""), (.actual_start // ""), (.actual_end // "")] | @csv'
}

format_effort_tsv() {
  local items="$1"
  echo -e "type\tnumber\ttitle\turl\tstate\trepository\tauthor\tassignees\tlabels\tcreated_at\tupdated_at\tstatus\testimated_hours\tactual_hours\tdue_date\tplanned_start\tplanned_end\tactual_start\tactual_end"
  echo "${items}" | jq -r '.[] | [.type, (.number | tostring), .title, .url, .state, .repository, .author, (.assignees | join("; ")), (.labels | join("; ")), .created_at, .updated_at, (.status // ""), (.estimated_hours // "" | tostring), (.actual_hours // "" | tostring), (.due_date // ""), (.planned_start // ""), (.planned_end // ""), (.actual_start // ""), (.actual_end // "")] | @tsv'
}

# --- レポート出力 ---

echo ""
echo "レポートを生成しています..."

FILE_EXT=$(get_file_extension "${OUTPUT_FORMAT}")
OUTPUT_FILE="report-${PROJECT_NUMBER}-effort.${FILE_EXT}"

case "${OUTPUT_FORMAT}" in
  json)
    REPORT_JSON=$(jq -n \
      --arg project_title "${PROJECT_TITLE}" \
      --argjson project_number "${PROJECT_NUMBER}" \
      --arg executed_at "${EXECUTED_AT}" \
      --argjson total_items "${TOTAL_COUNT}" \
      --argjson items_with_effort "${ITEMS_WITH_EFFORT_COUNT}" \
      --argjson items_without_effort "${ITEMS_WITHOUT_EFFORT_COUNT}" \
      --arg effort_input_rate "${EFFORT_INPUT_RATE}" \
      --argjson total_estimated "${TOTAL_ESTIMATED}" \
      --argjson total_actual "${TOTAL_ACTUAL}" \
      --arg overall_variance_rate "${OVERALL_VARIANCE_RATE}" \
      --argjson by_assignee "${ASSIGNEE_EFFORT}" \
      --argjson by_status "${STATUS_EFFORT}" \
      --argjson variance_items "${VARIANCE_ITEMS}" \
      --argjson lead_time "${LEAD_TIME_ITEMS}" \
      --argjson missing_effort_items "${MISSING_EFFORT_ITEMS}" '
      {
        project: {
          title: $project_title,
          number: $project_number
        },
        executed_at: $executed_at,
        overview: {
          total_items: $total_items,
          items_with_effort: $items_with_effort,
          items_without_effort: $items_without_effort,
          effort_input_rate: ($effort_input_rate | tonumber),
          total_estimated_hours: $total_estimated,
          total_actual_hours: $total_actual,
          overall_variance_rate: (if $overall_variance_rate == "-" then null else ($overall_variance_rate | tonumber) end)
        },
        by_assignee: $by_assignee,
        by_status: $by_status,
        variance_items: $variance_items,
        lead_time: $lead_time,
        missing_effort_items: $missing_effort_items
      }
    ')
    echo "${REPORT_JSON}" > "${OUTPUT_FILE}"
    ;;
  markdown)
    format_effort_markdown > "${OUTPUT_FILE}"
    ;;
  csv)
    format_effort_csv "${ITEMS}" > "${OUTPUT_FILE}"
    ;;
  tsv)
    format_effort_tsv "${ITEMS}" > "${OUTPUT_FILE}"
    ;;
esac

echo "  出力: ${OUTPUT_FILE}（形式: ${OUTPUT_FORMAT}）"

# --- Workflow Summary 出力 ---

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  if [[ "${OUTPUT_FORMAT}" == "markdown" ]]; then
    cat "${OUTPUT_FILE}" >> "${GITHUB_STEP_SUMMARY}"
  else
    format_effort_markdown >> "${GITHUB_STEP_SUMMARY}"
  fi
fi

# --- コンソールサマリー ---

print_summary "Project" "${PROJECT_TITLE} (#${PROJECT_NUMBER})" \
  "形式" "${OUTPUT_FORMAT}" \
  "フィルタ(type)" "${ITEM_TYPE}" \
  "フィルタ(state)" "${ITEM_STATE}" \
  "総 Item 数" "${TOTAL_COUNT} 件" \
  "工数入力済み" "${ITEMS_WITH_EFFORT_COUNT} 件" \
  "工数未入力" "${ITEMS_WITHOUT_EFFORT_COUNT} 件" \
  "見積もり工数" "${TOTAL_ESTIMATED} h" \
  "実績工数" "${TOTAL_ACTUAL} h" \
  "出力先" "${OUTPUT_FILE}"

echo ""
echo "::notice::工数集計レポートの生成が完了しました（${TOTAL_COUNT} 件）。"
