#!/usr/bin/env bash
set -euo pipefail

# 特殊 Repository 一括作成 統合エントリポイント
# https://mabubu0203.github.io/github-projects-starter-kit/workflows/03-create-special-repos
#
# オーナータイプ（User / Organization）を自動判定し、対応するスクリプトを実行する。
# Workflow（03-create-special-repos.yml）から呼び出される。
#
# 環境変数:
#   GH_TOKEN      - GitHub PAT（repo スコープまたは Administration: write が必要）
#   PROJECT_OWNER - 対象のオーナー名（個人アカウントまたは Organization）

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
require_env "PROJECT_OWNER"
require_command "gh" "GitHub CLI (gh) が必要です。PATH を確認してください。"
require_command "jq" "JSON の解析に必要です。"

# --- オーナータイプ判定 ---

detect_owner_type

# --- オーナータイプに応じたスクリプトにディスパッチ ---

case "${OWNER_TYPE}" in
  User)
    echo "個人アカウント用スクリプトを実行します..."
    exec bash "${SCRIPT_DIR}/create-special-repos-user.sh"
    ;;
  Organization)
    echo "Organization 用スクリプトを実行します..."
    exec bash "${SCRIPT_DIR}/create-special-repos-org.sh"
    ;;
esac
