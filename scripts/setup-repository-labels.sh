#!/usr/bin/env bash
set -euo pipefail

# 指定 Repository への Issue ラベル一括作成スクリプト
# https://lurest-inc.github.io/github-projects-ops-kit/scripts/setup-repository-labels
#
# 環境変数:
#   GH_TOKEN    - GitHub PAT（repo または public_repo スコープが必要）
#   TARGET_REPO - 対象 Repository（owner/repo 形式）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_target_repo_env

# --- ラベル定義ファイルの読み込み ---

LABEL_DEFINITIONS=$(load_config_file "${SCRIPT_DIR}/config/repo-label-definitions.json" "ラベル定義ファイル")

# --- JSON バリデーション ---

echo ""
echo "ラベル定義ファイルを検証しています..."

# JSON 配列であること、各要素に必須フィールドが存在すること
VALIDATION_ERRORS=$(echo "${LABEL_DEFINITIONS}" | jq -r '
  if type != "array" then
    "ラベル定義ファイルが JSON 配列ではありません。"
  else
    [to_entries[] |
      .key as $i |
      .value |
      (if .name == null or .name == "" then "[\($i)]: name が未定義または空です。" else empty end),
      (if .color == null or .color == "" then "[\($i)]: color が未定義または空です。" else empty end),
      (if .description == null then "[\($i)]: description が未定義です。" else empty end),
      (if .color != null and .color != "" and (.color | test("^[0-9a-fA-F]{6}$") | not) then "[\($i)]: color の形式が不正です: \(.color)（6桁の HEX 文字列を指定してください）" else empty end)
    ] | join("\n")
  end
')

if [[ -n "${VALIDATION_ERRORS}" ]]; then
  echo "::error::ラベル定義ファイルのバリデーションに失敗しました:"
  echo "${VALIDATION_ERRORS}" | while IFS= read -r line; do
    echo "::error::  ${line}"
  done
  exit 1
fi

LABEL_COUNT=$(echo "${LABEL_DEFINITIONS}" | jq 'length')
echo "  ${LABEL_COUNT} 件のラベル定義を読み込みました。"

if [[ "${LABEL_COUNT}" -eq 0 ]]; then
  echo ""
  echo "ラベル定義が空のため、処理をスキップします。"
  print_summary "Repository" "${TARGET_REPO}" "作成" "0 件" "スキップ" "0 件" "失敗" "0 件"
  exit 0
fi

# --- 既存ラベル一覧の取得（重複チェック用） ---

echo ""
echo "Repository ${TARGET_REPO} の既存ラベルを取得しています..."

EXISTING_LABELS=""
if existing_output=$(gh label list --repo "${TARGET_REPO}" --limit 9999 --json name --jq ".[].name" 2>&1); then
  EXISTING_LABELS="${existing_output}"
  EXISTING_LABEL_COUNT=$(echo "${EXISTING_LABELS}" | grep -c . || true)
  echo "  既存ラベル数: ${EXISTING_LABEL_COUNT}"
else
  echo "::error::既存ラベルの取得に失敗しました: ${existing_output}"
  exit 1
fi

# --- ラベルの一括作成 ---

echo ""
echo "Repository ${TARGET_REPO} にラベルを作成します..."

# ループ前にラベル定義を 1 回の jq で事前解析する
PARSED_LABELS=$(echo "${LABEL_DEFINITIONS}" | jq -r '.[] | [.name, .color, .description] | @tsv')

CREATED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0
LABEL_INDEX=0

while IFS=$'\t' read -r LABEL_NAME LABEL_COLOR LABEL_DESCRIPTION; do
  LABEL_INDEX=$((LABEL_INDEX + 1))

  echo ""
  echo "  [${LABEL_INDEX}/${LABEL_COUNT}] ${LABEL_NAME} (${LABEL_COLOR})"

  # 既存ラベルの重複チェック（ラベル名は固定文字列として比較）
  if [[ -n "${EXISTING_LABELS}" ]] && echo "${EXISTING_LABELS}" | grep -Fqx "${LABEL_NAME}"; then
    echo "    → 既存ラベルのためスキップしました。"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  if gh label create "${LABEL_NAME}" \
    --repo "${TARGET_REPO}" \
    --color "${LABEL_COLOR}" \
    --description "${LABEL_DESCRIPTION}" 2>/dev/null; then
    echo "    → 作成しました。"
    CREATED_COUNT=$((CREATED_COUNT + 1))
  else
    echo "    → 作成に失敗しました。"
    SAFE_LABEL_NAME=$(sanitize_for_workflow_command "${LABEL_NAME}")
    echo "::error::ラベル '${SAFE_LABEL_NAME}' の作成に失敗しました。"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done <<< "${PARSED_LABELS}"

# --- サマリー出力 ---

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## ラベル一括作成完了"
    echo ""
    echo "| 項目 | 件数 |"
    echo "|------|------|"
    echo "| 作成 | ${CREATED_COUNT} |"
    echo "| スキップ | ${SKIPPED_COUNT} |"
    echo "| 失敗 | ${FAILED_COUNT} |"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

print_summary "Repository" "${TARGET_REPO}" "作成" "${CREATED_COUNT} 件" "スキップ" "${SKIPPED_COUNT} 件" "失敗" "${FAILED_COUNT} 件"

if [[ "${FAILED_COUNT}" -gt 0 ]]; then
  echo ""
  echo "::error::${FAILED_COUNT} 件のラベル作成に失敗しました。"
  exit 1
fi

echo ""
echo "セットアップが完了しました。"
