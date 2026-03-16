#!/usr/bin/env bash
set -euo pipefail

# ステータス自動同期ワークフローのセットアップスクリプト
# https://mabubu0203.github.io/github-projects-starter-kit/scripts/setup-sync-project-status
#
# 対象リポジトリにイベント駆動ワークフロー（sync-project-status.yml + sync-project-status.sh）を
# テンプレートから生成し、PR として配置する。
#
# 環境変数:
#   GH_TOKEN       - GitHub PAT（Projects 操作権限 + 対象リポジトリへの書き込み権限）
#   TARGET_REPO    - 対象リポジトリ（owner/repo 形式）
#   PROJECT_OWNER  - Project の所有者（ユーザー名 or 組織名）
#   PROJECT_NUMBER - 対象 Project の番号

# --- 共通ライブラリ読み込み ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- バリデーション ---

require_env "GH_TOKEN" "Secrets に PROJECT_PAT を設定してください。"
require_env "TARGET_REPO"
require_env "PROJECT_OWNER"
require_env "PROJECT_NUMBER"

if [[ ! "${TARGET_REPO}" =~ ^[^/]+/[^/]+$ ]]; then
  echo "::error::TARGET_REPO は owner/repo 形式で指定してください（例: myorg/myrepo）。"
  exit 1
fi

validate_project_number

require_command "gh" "GitHub CLI (gh) が必要です。PATH を確認してください。"
require_command "jq" "JSON の解析に必要です。"
require_command "sed" "テンプレート展開に必要です。"
require_command "git" "Git が必要です。"

# --- テンプレートファイルの存在確認 ---

TEMPLATE_DIR="${SCRIPT_DIR}/templates"
WF_TEMPLATE="${TEMPLATE_DIR}/sync-project-status.yml.tpl"
SCRIPT_TEMPLATE="${TEMPLATE_DIR}/sync-project-status.sh.tpl"

for tpl in "${WF_TEMPLATE}" "${SCRIPT_TEMPLATE}"; do
  if [[ ! -f "${tpl}" ]]; then
    echo "::error::テンプレートファイルが見つかりません: ${tpl}"
    exit 1
  fi
done

# --- 対象リポジトリの存在確認 ---

echo ""
echo "対象リポジトリを確認しています..."
if ! gh repo view "${TARGET_REPO}" --json name >/dev/null 2>&1; then
  safe_repo=$(sanitize_for_workflow_command "${TARGET_REPO}")
  echo "::error::対象リポジトリにアクセスできません: ${safe_repo}"
  echo "::error::リポジトリが存在し、PAT にアクセス権限があることを確認してください。"
  exit 1
fi
echo "  対象リポジトリ: ${TARGET_REPO}"

# --- テンプレートからファイル生成 ---

echo ""
echo "テンプレートからワークフローファイルを生成しています..."

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

GENERATED_WF="${WORK_DIR}/sync-project-status.yml"
GENERATED_SCRIPT="${WORK_DIR}/sync-project-status.sh"

sed \
  -e "s/__PROJECT_OWNER__/${PROJECT_OWNER}/g" \
  -e "s/__PROJECT_NUMBER__/${PROJECT_NUMBER}/g" \
  "${WF_TEMPLATE}" \
  > "${GENERATED_WF}"

sed \
  -e "s/__PROJECT_OWNER__/${PROJECT_OWNER}/g" \
  -e "s/__PROJECT_NUMBER__/${PROJECT_NUMBER}/g" \
  "${SCRIPT_TEMPLATE}" \
  > "${GENERATED_SCRIPT}"

echo "  ワークフローファイル: 生成完了"
echo "  スクリプトファイル: 生成完了"

# --- 対象リポジトリにブランチ作成・コミット・プッシュ ---

echo ""
echo "対象リポジトリをクローンしています..."

CLONE_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}" "${CLONE_DIR}"' EXIT

gh repo clone "${TARGET_REPO}" "${CLONE_DIR}" -- --depth 1

cd "${CLONE_DIR}"

BRANCH_NAME="setup/sync-project-status"

echo ""
echo "ブランチを作成しています: ${BRANCH_NAME}"
git checkout -b "${BRANCH_NAME}"

# ワークフローファイルを配置
mkdir -p .github/workflows
cp "${GENERATED_WF}" .github/workflows/sync-project-status.yml

# スクリプトファイルを配置
mkdir -p scripts
cp "${GENERATED_SCRIPT}" scripts/sync-project-status.sh
chmod +x scripts/sync-project-status.sh

echo ""
echo "変更をコミットしています..."
git add .github/workflows/sync-project-status.yml scripts/sync-project-status.sh
git commit -m "ci: ステータス自動同期ワークフローを追加

Project のステータスを Issue/PR のライフサイクルイベントに連動して
自動更新するワークフローとスクリプトを追加します。

- イベント駆動ワークフロー（issues / pull_request / pull_request_review）
- ステータス遷移ルールに基づく自動更新
- 前方遷移ガードによる不正な後退防止
- 紐付け Issue の連動更新
- 複数プロジェクト帰属への対応"

echo ""
echo "リモートにプッシュしています..."
git push origin "${BRANCH_NAME}"

# --- PR 作成 ---

echo ""
echo "PR を作成しています..."

PR_BODY=$(cat <<PRBODY
## 概要

GitHub Project のステータスを Issue/PR のライフサイクルイベントに連動して自動更新するワークフローとスクリプトを追加します。

## セットアップ手順

### 1. SECRET の設定（必須）

このワークフローが正しく動作するには、リポジトリに以下の Secret を設定する必要があります。

| Secret 名 | 説明 |
|-----------|------|
| \`PROJECT_PAT\` | GitHub PAT（Personal Access Token） |

#### PAT に必要なスコープ

- \`project\` — Projects V2 の読み書き
- \`repo\` — リポジトリの読み取り（Issue/PR 情報の取得）

#### 設定方法

1. [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens) で PAT を作成
2. リポジトリの **Settings > Secrets and variables > Actions** で \`PROJECT_PAT\` として登録

### 2. GitHub Actions の有効化

リポジトリの **Settings > Actions > General** で GitHub Actions が有効になっていることを確認してください。

## 追加されるファイル

| ファイル | 説明 |
|---------|------|
| \`.github/workflows/sync-project-status.yml\` | イベント駆動ワークフロー |
| \`scripts/sync-project-status.sh\` | ステータス同期スクリプト |

## 対象 Project

| 項目 | 値 |
|------|-----|
| Project Owner | \`${PROJECT_OWNER}\` |
| Project Number | \`${PROJECT_NUMBER}\` |

## ステータス遷移ルール

| イベント | 遷移先 |
|---------|--------|
| Issue opened | Backlog |
| Issue closed | Done |
| Issue reopened | Todo |
| PR opened | In Progress |
| PR review_requested / ready_for_review | In Review |
| PR converted_to_draft | In Progress |
| PR closed (merged/unmerged) | Done |
| Review changes_requested | In Progress |
PRBODY
)

PR_URL=$(gh pr create \
  --repo "${TARGET_REPO}" \
  --title "ci: ステータス自動同期ワークフローを追加" \
  --body "${PR_BODY}")

echo "  PR を作成しました: ${PR_URL}"

# --- サマリー出力 ---

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## ステータス自動同期セットアップ完了"
    echo ""
    echo "| 項目 | 値 |"
    echo "|------|-----|"
    echo "| 対象リポジトリ | \`${TARGET_REPO}\` |"
    echo "| Project Owner | \`${PROJECT_OWNER}\` |"
    echo "| Project Number | \`${PROJECT_NUMBER}\` |"
    echo "| ブランチ | \`${BRANCH_NAME}\` |"
    echo "| PR | ${PR_URL} |"
    echo ""
    echo "### 生成ファイル"
    echo ""
    echo "| ファイル | 説明 |"
    echo "|---------|------|"
    echo "| \`.github/workflows/sync-project-status.yml\` | イベント駆動ワークフロー |"
    echo "| \`scripts/sync-project-status.sh\` | ステータス同期スクリプト |"
    echo ""
    echo "> **次のステップ**: PR をマージする前に、対象リポジトリの Secrets に \`PROJECT_PAT\` を設定してください。"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

print_summary \
  "リポジトリ" "${TARGET_REPO}" \
  "Owner" "${PROJECT_OWNER}" \
  "Project" "#${PROJECT_NUMBER}" \
  "ブランチ" "${BRANCH_NAME}" \
  "PR" "${PR_URL}"

echo ""
echo "セットアップが完了しました。"
echo "対象リポジトリの Secrets に PROJECT_PAT を設定してから PR をマージしてください。"
