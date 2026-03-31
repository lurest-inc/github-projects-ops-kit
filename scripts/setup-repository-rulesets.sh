#!/usr/bin/env bash
set -euo pipefail

# 指定 Repository に対する Branch Ruleset 一括作成スクリプト
# https://lurest-inc.github.io/github-projects-ops-kit/scripts/setup-repository-rulesets
#
# 環境変数:
#   GH_TOKEN    - GitHub PAT（repo スコープが必要）
#   TARGET_REPO - 対象 Repository（owner/repo 形式）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_target_repo_env

# --- Ruleset 定義ファイルの読み込み ---

RULESET_DEFINITIONS=$(load_config_file "${SCRIPT_DIR}/config/repo-ruleset-definitions.json" "Ruleset 定義ファイル")

# --- JSON バリデーション ---

echo ""
echo "Ruleset 定義ファイルを検証しています..."

VALIDATION_ERRORS=$(echo "${RULESET_DEFINITIONS}" | jq -r '
  if type != "array" then
    "Ruleset 定義ファイルが JSON 配列ではありません。"
  else
    [to_entries[] |
      .key as $i |
      .value |
      (if .name == null or .name == "" then "[\($i)]: name が未定義または空です。" else empty end),
      (if .target == null or .target == "" then "[\($i)]: target が未定義または空です。" else empty end),
      (if .enforcement == null or .enforcement == "" then "[\($i)]: enforcement が未定義または空です。" else empty end),
      (if .enforcement != null and (.enforcement | IN("active", "disabled", "evaluate") | not) then "[\($i)]: enforcement の値が不正です: \(.enforcement)（active, disabled, evaluate のいずれかを指定してください）" else empty end),
      (if .conditions == null then "[\($i)]: conditions が未定義です。" else empty end),
      (if .conditions != null and (.conditions.ref_name == null) then "[\($i)]: conditions.ref_name が未定義です。" else empty end),
      (if .rules == null or (.rules | type) != "array" then "[\($i)]: rules が未定義または配列ではありません。" else empty end)
    ] | join("\n")
  end
')

if [[ -n "${VALIDATION_ERRORS}" ]]; then
  echo "::error::Ruleset 定義ファイルのバリデーションに失敗しました:"
  echo "${VALIDATION_ERRORS}" | while IFS= read -r line; do
    echo "::error::  ${line}"
  done
  exit 1
fi

RULESET_COUNT=$(echo "${RULESET_DEFINITIONS}" | jq 'length')
echo "  ${RULESET_COUNT} 件の Ruleset 定義を読み込みました。"

if [[ "${RULESET_COUNT}" -eq 0 ]]; then
  echo ""
  echo "Ruleset 定義が空のため、処理をスキップします。"
  print_summary "Repository" "${TARGET_REPO}" "作成" "0 件" "スキップ" "0 件" "失敗" "0 件"
  exit 0
fi

# --- 既存 Ruleset 一覧の取得（重複チェック用） ---

echo ""
echo "Repository ${TARGET_REPO} の既存 Ruleset を取得しています..."

EXISTING_RULESETS=""
PLAN_RESTRICTED=false
if existing_output=$(gh api "repos/${TARGET_REPO}/rulesets" \
  -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
  --jq ".[].name" 2>&1); then
  EXISTING_RULESETS="${existing_output}"
  EXISTING_RULESET_COUNT=$(echo "${EXISTING_RULESETS}" | grep -c . || true)
  echo "  既存 Ruleset 数: ${EXISTING_RULESET_COUNT}"
elif echo "${existing_output}" | grep -q "Upgrade to GitHub Pro"; then
  echo "  ⚠️  プランの制約により Rulesets API を利用できません。"
  echo "     Free プランの Private リポジトリでは Rulesets がサポートされていません。"
  echo "     リポジトリを Public にするか、GitHub Pro 以上にアップグレードしてください。"
  PLAN_RESTRICTED=true
else
  echo "::error::既存 Ruleset の取得に失敗しました: ${existing_output}"
  exit 1
fi

# --- プラン制約による早期終了 ---

CREATED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
EVALUATE_COUNT=0

if [[ "${PLAN_RESTRICTED}" == true ]]; then
  echo ""

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## Ruleset 一括作成"
      echo ""
      echo "> **⚠️ プラン制約:** Free プランの Private リポジトリでは Rulesets API を利用できません。"
      echo "> リポジトリを Public にするか、GitHub Pro 以上にアップグレードしてください。"
    } >> "${GITHUB_STEP_SUMMARY}"
  fi

  print_summary "Repository" "${TARGET_REPO}" "状態" "プラン制約によりスキップ"
  echo ""
  echo "⚠️  プランの制約により Ruleset の作成をスキップしました。"
  exit 0
fi

# --- Ruleset の一括作成 ---

echo ""
echo "Repository ${TARGET_REPO} に Ruleset を作成します..."

RULESET_INDEX=0

# ループ前に Ruleset 名を事前解析する
PARSED_NAMES=$(echo "${RULESET_DEFINITIONS}" | jq -r '.[].name')

while IFS= read -r RULESET_NAME; do
  RULESET_INDEX=$((RULESET_INDEX + 1))

  echo ""
  echo "  [${RULESET_INDEX}/${RULESET_COUNT}] ${RULESET_NAME}"

  # 既存 Ruleset の重複チェック
  if [[ -n "${EXISTING_RULESETS}" ]] && echo "${EXISTING_RULESETS}" | grep -Fqx "${RULESET_NAME}"; then
    echo "    → 既存 Ruleset のためスキップしました。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  # 定義から該当 Ruleset の JSON ペイロードを構築
  RULESET_PAYLOAD=$(echo "${RULESET_DEFINITIONS}" | jq -c --arg name "${RULESET_NAME}" '
    .[] | select(.name == $name) |
    {
      name: .name,
      target: .target,
      enforcement: .enforcement,
      conditions: .conditions,
      rules: .rules
    }
  ')

  if create_output=$(gh api "repos/${TARGET_REPO}/rulesets" \
    -H "X-GitHub-Api-Version: ${REST_API_VERSION}" \
    --method POST \
    --input - <<< "${RULESET_PAYLOAD}" 2>&1); then

    # 作成後の enforcement 状態を確認
    ACTUAL_ENFORCEMENT=$(echo "${create_output}" | jq -r '.enforcement // empty')

    if [[ "${ACTUAL_ENFORCEMENT}" == "evaluate" ]]; then
      echo "    → 作成しました（⚠️ evaluate モード: プランの制約により active にできませんでした）。"
      EVALUATE_COUNT=$((EVALUATE_COUNT + 1))
    else
      echo "    → 作成しました（enforcement: ${ACTUAL_ENFORCEMENT}）。"
    fi
    CREATED_COUNT=$((CREATED_COUNT + 1))
  else
    echo "    → 作成に失敗しました。"
    SAFE_RULESET_NAME=$(sanitize_for_workflow_command "${RULESET_NAME}")
    echo "::error::Ruleset '${SAFE_RULESET_NAME}' の作成に失敗しました: ${create_output}"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done <<< "${PARSED_NAMES}"

# --- サマリー出力 ---

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Ruleset 一括作成完了"
    echo ""
    echo "| 項目 | 件数 |"
    echo "|------|------|"
    echo "| 作成 | ${CREATED_COUNT} |"
    echo "| スキップ | ${SKIPPED_COUNT} |"
    echo "| 失敗 | ${FAILED_COUNT} |"
    if [[ "${EVALUATE_COUNT}" -gt 0 ]]; then
      echo ""
      echo "> **⚠️ 注意:** ${EVALUATE_COUNT} 件の Ruleset が \`evaluate\` モードになっています。"
      echo "> Free プラン（Private リポジトリ）では Ruleset を \`active\` にできない場合があります。"
      echo "> 詳細は [GitHub Docs: Repository Rulesets](https://docs.github.com/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) を参照してください。"
    fi
  } >> "${GITHUB_STEP_SUMMARY}"
fi

SUMMARY_ARGS=("Repository" "${TARGET_REPO}" "作成" "${CREATED_COUNT} 件" "スキップ" "${SKIPPED_COUNT} 件" "失敗" "${FAILED_COUNT} 件")
if [[ "${EVALUATE_COUNT}" -gt 0 ]]; then
  SUMMARY_ARGS+=("evaluate" "${EVALUATE_COUNT} 件")
fi
print_summary "${SUMMARY_ARGS[@]}"

if [[ "${EVALUATE_COUNT}" -gt 0 ]]; then
  echo ""
  echo "⚠️  ${EVALUATE_COUNT} 件の Ruleset が evaluate モードです。"
  echo "   Free プラン（Private リポジトリ）では Ruleset を active にできない場合があります。"
fi

if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  echo ""
  echo "::error::${FAILED_COUNT} 件の Ruleset 作成に失敗しました。"
  exit 1
fi

echo ""
echo "セットアップが完了しました。"
