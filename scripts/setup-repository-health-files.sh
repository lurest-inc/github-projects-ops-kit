#!/usr/bin/env bash
set -euo pipefail

# 指定 Repository への Community Health Files 一括登録スクリプト
#
# 対象リポジトリに作業ブランチを作成し、Community Health Files を
# 空ファイルとして登録した後、デフォルトブランチへの PR を作成する。
# 既に存在するファイルはスキップする（上書き禁止）。
#
# 環境変数:
#   GH_TOKEN    - GitHub PAT（repo スコープが必要）
#   TARGET_REPO - 対象 Repository（owner/repo 形式）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

validate_target_repo_env

# --- 対象ファイル定義（JSON から読み込み） ---

HEALTH_FILE_DEFINITIONS=$(load_config_file "${SCRIPT_DIR}/config/repo-health-file-definitions.json" "Health File 定義ファイル")

mapfile -t HEALTH_FILES < <(echo "${HEALTH_FILE_DEFINITIONS}" | jq -r '.[].path')
FILE_COUNT=${#HEALTH_FILES[@]}

if [[ "${FILE_COUNT}" -eq 0 ]]; then
  echo "::error::設定ファイルに対象ファイルが定義されていません。"
  exit 1
fi

# --- デフォルトブランチの取得 ---

get_default_branch_info "${TARGET_REPO}"

# --- 既存ファイルチェック＆登録対象の決定 ---

check_existing_repo_files "${TARGET_REPO}" "${HEALTH_FILES[@]}"

CREATED_COUNT=0
FAILED_COUNT=0

# --- 全ファイルがスキップされた場合 ---

if [[ ${#FILES_TO_CREATE[@]} -eq 0 ]]; then
  echo ""
  echo "全ファイルが既に存在するため、処理をスキップします。"
  output_repo_files_summary "Community Health Files 一括登録完了"
  exit 0
fi

# --- ファイル登録 & PR 作成 ---

create_files_via_pr \
  "${TARGET_REPO}" \
  "chore/add-community-health-files" \
  "docs" \
  "Community Health Files" \
  "docs: add community health files" \
  "## 概要

Community Health Files を一括登録します。" \
  "${HEALTH_FILES[@]}"

# --- サマリー出力 ---

output_repo_files_summary "Community Health Files 一括登録完了"
