#!/usr/bin/env bash
set -euo pipefail

# 指定リポジトリへの Issue ラベル一括作成スクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/setup-repository-labels
#
# 環境変数:
#   GH_TOKEN    - GitHub PAT（repo または public_repo スコープが必要）
#   TARGET_REPO - 対象リポジトリ（owner/repo 形式）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
require_env "TARGET_REPO"
require_command "gh" "GitHub CLI (gh) が必要です。PATH を確認してください。"
require_command "jq" "JSON の解析に必要です。"

# --- ラベル定義ファイルの読み込み ---

LABEL_DEFINITIONS_FILE="${SCRIPT_DIR}/config/repository-label-definitions.json"
if [[ ! -f "${LABEL_DEFINITIONS_FILE}" ]]; then
  echo "::error::ラベル定義ファイルが見つかりません: ${LABEL_DEFINITIONS_FILE}"
  exit 1
fi
LABEL_DEFINITIONS=$(cat "${LABEL_DEFINITIONS_FILE}")

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

# --- ラベルの一括作成 ---

echo ""
echo "リポジトリ ${TARGET_REPO} にラベルを作成します..."

CREATED=0
SKIPPED=0
FAILED=0

for i in $(seq 0 $((LABEL_COUNT - 1))); do
  LABEL_NAME=$(echo "${LABEL_DEFINITIONS}" | jq -r ".[$i].name")
  LABEL_COLOR=$(echo "${LABEL_DEFINITIONS}" | jq -r ".[$i].color")
  LABEL_DESCRIPTION=$(echo "${LABEL_DEFINITIONS}" | jq -r ".[$i].description")

  echo ""
  echo "  [$((i + 1))/${LABEL_COUNT}] ${LABEL_NAME} (${LABEL_COLOR})"

  if gh label create "${LABEL_NAME}" \
    --repo "${TARGET_REPO}" \
    --color "${LABEL_COLOR}" \
    --description "${LABEL_DESCRIPTION}" 2>/dev/null; then
    echo "    → 作成しました。"
    CREATED=$((CREATED + 1))
  else
    # 既存ラベルかどうかを確認
    if gh label list --repo "${TARGET_REPO}" --json name --jq ".[].name" 2>/dev/null | grep -qx "${LABEL_NAME}"; then
      echo "    → 既存ラベルのためスキップしました。"
      SKIPPED=$((SKIPPED + 1))
    else
      echo "    → 作成に失敗しました。"
      echo "::error::ラベル '${LABEL_NAME}' の作成に失敗しました。"
      FAILED=$((FAILED + 1))
    fi
  fi
done

# --- サマリー出力 ---

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## ラベル一括作成完了"
    echo ""
    echo "| 項目 | 件数 |"
    echo "|------|------|"
    echo "| 作成 | ${CREATED} |"
    echo "| スキップ | ${SKIPPED} |"
    echo "| 失敗 | ${FAILED} |"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

print_summary "リポジトリ" "${TARGET_REPO}" "作成" "${CREATED} 件" "スキップ" "${SKIPPED} 件" "失敗" "${FAILED} 件"

if [[ "${FAILED}" -gt 0 ]]; then
  echo ""
  echo "::error::${FAILED} 件のラベル作成に失敗しました。"
  exit 1
fi

echo ""
echo "セットアップが完了しました。"
