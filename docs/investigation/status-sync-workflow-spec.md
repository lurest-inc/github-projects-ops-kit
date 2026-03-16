# 🔄 ステータス自動同期 — ワークフロー入出力仕様書

<!-- START doctoc -->
<!-- END doctoc -->

本ドキュメントは、Issue/PR のライフサイクルイベントに連動して GitHub Project のステータスを自動更新する仕組みの入出力仕様を定義する。

関連 Issue: [#187](https://github.com/mabubu0203/github-projects-starter-kit/issues/187)

---

## 概要

本機能は **2 層構成** で実現する。

1. **セットアップワークフロー（⑥）** — 本リポジトリで `workflow_dispatch` により手動実行。対象リポジトリにイベント駆動ワークフローを PR として配置する
2. **生成ワークフロー** — 対象リポジトリに配置されるイベント駆動ワークフロー。Issue/PR のライフサイクルイベントでステータスを自動同期する

```mermaid
flowchart LR
    A["⑥ セットアップWF\n(本リポジトリ)\nworkflow_dispatch"] -->|"target_repo\nproject_owner\nproject_number"| B["セットアップスクリプト"]
    B -->|"1. WFファイル生成\n2. ブランチ作成\n3. コミット&プッシュ\n4. PR作成"| C["対象リポジトリ"]
    C -->|"PRマージ後"| D["生成WF\n(イベント駆動)"]
    D -->|"issues / PR / review\nイベント発火"| E["ステータス\n自動同期"]
```

### 既存ワークフロー（①〜⑤）との統一

| 項目 | 既存（①〜⑤） | ⑥ セットアップ |
|------|-------------|---------------|
| トリガー | `workflow_dispatch` | `workflow_dispatch` |
| 入力 | `project_owner`, `project_number` 等 | `target_repo`, `project_owner`, `project_number` |
| 実行場所 | 本リポジトリ | 本リポジトリ |
| フォーク後の追加設定 | Secret のみ | Secret のみ |

---

## Part 1: セットアップワークフロー（⑥）

### トリガー

```yaml
on:
  workflow_dispatch:
    inputs:
      target_repo:
        description: "対象リポジトリ（owner/repo 形式）"
        required: true
        type: string
      project_owner:
        description: "Project の所有者（ユーザー名 or 組織名）"
        required: true
        type: string
      project_number:
        description: "対象 Project の番号"
        required: true
        type: number
```

### 入力

| 変数名 | 必須 | 説明 | 取得元 |
|--------|------|------|--------|
| `GH_TOKEN` | Yes | GitHub PAT（Projects 操作権限 + 対象リポジトリへの書き込み権限） | Secrets: `PROJECT_PAT` |
| `TARGET_REPO` | Yes | 対象リポジトリ（`owner/repo` 形式） | `inputs.target_repo` |
| `PROJECT_OWNER` | Yes | Project の所有者 | `inputs.project_owner` |
| `PROJECT_NUMBER` | Yes | 対象 Project の番号 | `inputs.project_number` |

### 処理フロー

```mermaid
flowchart TD
    A["入力バリデーション"] --> B["対象リポジトリの存在確認"]
    B --> C["ワークフローファイル生成\n(テンプレートに値を埋め込み)"]
    C --> D["対象リポジトリに\nブランチ作成"]
    D --> E["ワークフローファイルを\nコミット & プッシュ"]
    E --> F["PR 作成"]
    F --> G["サマリー出力\n(PR URL 等)"]
```

#### Step 1: 入力バリデーション

- `TARGET_REPO` が `owner/repo` 形式であること
- `PROJECT_NUMBER` が数値であること
- 対象リポジトリが存在し、PAT でアクセス可能であること

#### Step 2: ワークフローファイル生成

テンプレートから `PROJECT_OWNER` と `PROJECT_NUMBER` を埋め込んだワークフローファイルを生成する。

```bash
# テンプレートファイルからプレースホルダーを置換して生成
sed \
  -e "s/__PROJECT_OWNER__/${PROJECT_OWNER}/g" \
  -e "s/__PROJECT_NUMBER__/${PROJECT_NUMBER}/g" \
  "${SCRIPT_DIR}/templates/sync-project-status.yml.tpl" \
  > "${WORK_DIR}/.github/workflows/sync-project-status.yml"
```

#### Step 3: 対象リポジトリにブランチ作成・コミット・プッシュ・PR 作成

```bash
# 対象リポジトリをクローン
gh repo clone "${TARGET_REPO}" "${WORK_DIR}" -- --depth 1

# ブランチ作成
cd "${WORK_DIR}"
BRANCH_NAME="setup/sync-project-status"
git checkout -b "${BRANCH_NAME}"

# ワークフローファイルを配置
mkdir -p .github/workflows
cp "${GENERATED_FILE}" .github/workflows/sync-project-status.yml

# コミット & プッシュ
git add .github/workflows/sync-project-status.yml
git commit -m "ci: ステータス自動同期ワークフローを追加"
git push origin "${BRANCH_NAME}"

# PR 作成
gh pr create \
  --repo "${TARGET_REPO}" \
  --title "ci: ステータス自動同期ワークフローを追加" \
  --body "..."
```

### 出力

| 項目 | 出力内容 |
|------|---------|
| PR URL | 対象リポジトリに作成された PR の URL |
| 生成ファイルパス | `.github/workflows/sync-project-status.yml` |
| 埋め込み値 | `PROJECT_OWNER`, `PROJECT_NUMBER` |

---

## Part 2: 生成ワークフロー（対象リポジトリに配置）

### トリガー

```yaml
on:
  issues:
    types: [opened, closed, reopened]
  pull_request:
    types: [opened, closed, review_requested, converted_to_draft, ready_for_review]
  pull_request_review:
    types: [submitted]
```

### 対象アクションのフィルタリング

| イベント | activity type | 追加条件 |
|---------|--------------|---------|
| `issues.opened` | — | — |
| `issues.closed` | — | — |
| `issues.reopened` | — | — |
| `pull_request.opened` | — | — |
| `pull_request.closed` | — | merged/unmerged どちらも Done（分岐不要） |
| `pull_request.review_requested` | — | — |
| `pull_request.converted_to_draft` | — | — |
| `pull_request.ready_for_review` | — | — |
| `pull_request_review.submitted` | — | `github.event.review.state` で分岐（`changes_requested` のみ対象） |

### 入力（生成時に埋め込み）

| 変数名 | 説明 | 値の由来 |
|--------|------|---------|
| `PROJECT_OWNER` | Project の所有者 | セットアップ時に埋め込み |
| `PROJECT_NUMBER` | 対象 Project の番号 | セットアップ時に埋め込み |
| `GH_TOKEN` | GitHub PAT | 対象リポジトリの Secrets: `PROJECT_PAT` |

> **注意**: 対象リポジトリにも `PROJECT_PAT` Secret の設定が必要。これはセットアップワークフローの PR 本文に手順として記載する。

### GitHub Event Context

| フィールド | 説明 |
|-----------|------|
| `github.event_name` | イベント名（`issues` / `pull_request` / `pull_request_review`） |
| `github.event.action` | アクション種別（`opened` / `closed` 等） |
| `github.event.issue` | Issue オブジェクト（`issues` イベント時） |
| `github.event.pull_request` | PR オブジェクト（`pull_request` / `pull_request_review` イベント時） |
| `github.event.review` | レビューオブジェクト（`pull_request_review` イベント時） |
| `github.event.issue.node_id` | Issue の GraphQL Node ID |
| `github.event.pull_request.node_id` | PR の GraphQL Node ID |
| `github.event.issue.state_reason` | Issue クローズ理由（`completed` / `not_planned` / `null`） |
| `github.event.pull_request.merged` | PR がマージされたか（boolean） |
| `github.event.review.state` | レビュー状態（`approved` / `changes_requested` / `commented`） |

---

### 処理フロー

```mermaid
flowchart TD
    A["GitHub Event\n(issues / pull_request / pull_request_review)"] --> B["ワークフロー起動"]
    B --> C["イベント解析\n対象アクション判定"]
    C --> D{"対象アクション?"}
    D -- Yes --> E["対象ノードの\nProject Item 取得"]
    D -- No --> Z["スキップ"]
    E --> F{"Project に\n属している?"}
    F -- Yes --> G["遷移ルール判定"]
    F -- No --> Z
    G --> H{"前方遷移\nガード通過?"}
    H -- Yes --> I["ステータス更新\n(GraphQL Mutation)"]
    H -- No --> Z
    I --> J["紐付け Issue の\n連動更新"]
    J --> K["サマリー出力"]
```

#### Step 1: イベント解析

イベント種別とアクションから遷移先ステータスを決定する。

```bash
case "${EVENT_NAME}" in
  issues)
    NODE_ID="${ISSUE_NODE_ID}"
    case "${ACTION}" in
      opened)    TARGET_STATUS="Backlog" ;;
      closed)    TARGET_STATUS="Done" ;;
      reopened)  TARGET_STATUS="Todo" ;;
    esac
    ;;
  pull_request)
    NODE_ID="${PR_NODE_ID}"
    case "${ACTION}" in
      opened)              TARGET_STATUS="In Progress" ;;
      review_requested)    TARGET_STATUS="In Review" ;;
      converted_to_draft)  TARGET_STATUS="In Progress" ;;
      ready_for_review)    TARGET_STATUS="In Review" ;;
      closed)
        # merged/closed の区別は不要（どちらも Done）
        TARGET_STATUS="Done"
        ;;
    esac
    ;;
  pull_request_review)
    NODE_ID="${PR_NODE_ID}"
    case "${REVIEW_STATE}" in
      changes_requested)  TARGET_STATUS="In Progress" ;;
      *)                  exit 0 ;;  # approved / commented はスキップ
    esac
    ;;
esac
```

#### Step 2: Project Item 取得

対象ノードが属する全 Project の Item 情報を取得する。`first: 100` で取得し、通常のユースケースでは十分なカバー範囲となる。100 件を超える Project への帰属が想定される場合は、ページネーション（`pageInfo` / `after`）を実装する。

```graphql
query($nodeId: ID!) {
  node(id: $nodeId) {
    ... on Issue {
      projectItems(first: 100) {
        nodes {
          id
          project {
            id
            number
            field(name: "Status") {
              ... on ProjectV2SingleSelectField {
                id
                options { id name }
              }
            }
          }
          fieldValueByName(name: "Status") {
            ... on ProjectV2ItemFieldSingleSelectValue {
              name
            }
          }
        }
      }
    }
    ... on PullRequest {
      projectItems(first: 100) {
        nodes {
          id
          project {
            id
            number
            field(name: "Status") {
              ... on ProjectV2SingleSelectField {
                id
                options { id name }
              }
            }
          }
          fieldValueByName(name: "Status") {
            ... on ProjectV2ItemFieldSingleSelectValue {
              name
            }
          }
        }
      }
    }
  }
}
```

#### Step 3: 前方遷移ガード

現在のステータスと遷移先を比較し、ルールに基づき更新可否を判定する。

```bash
# ステータスの順序値（数値が大きいほど後方）
declare -A STATUS_ORDER=(
  ["Backlog"]=1
  ["Todo"]=2
  ["In Progress"]=3
  ["In Review"]=4
  ["Done"]=5
)

is_forward_transition() {
  local current="$1"
  local target="$2"

  # 例外: In Review → In Progress（差し戻し）
  if [[ "${current}" == "In Review" && "${target}" == "In Progress" ]]; then
    return 0
  fi

  # 例外: Done → Todo（再オープン）
  if [[ "${current}" == "Done" && "${target}" == "Todo" ]]; then
    return 0
  fi

  local current_order="${STATUS_ORDER[${current}]:-0}"
  local target_order="${STATUS_ORDER[${target}]:-0}"

  [[ "${target_order}" -gt "${current_order}" ]]
}
```

#### Step 4: ステータス更新

`updateProjectV2ItemFieldValue` ミューテーションで更新する（既存の `add-items-to-project.sh` と同一の API）。

```graphql
mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: $projectId
    itemId: $itemId
    fieldId: $fieldId
    value: { singleSelectOptionId: $optionId }
  }) {
    projectV2Item { id }
  }
}
```

#### Step 5: 紐付け Issue の連動更新（PR イベント / PR レビューイベント時）

PR に紐付けられた Issue のステータスも連動更新する。対象イベントは以下の通り。

- `pull_request.opened` → 紐付け Issue を In Progress に
- `pull_request.closed (merged)` → 紐付け Issue を Done に
- `pull_request_review.submitted (changes_requested)` → 紐付け Issue を In Progress に

> **上限**: `closingIssuesReferences` は `first: 50` で取得する。1 つの PR に 50 件を超える紐付け Issue があるケースは想定外とし、超過時はワーニングログを出力する。

```graphql
query($prNodeId: ID!) {
  node(id: $prNodeId) {
    ... on PullRequest {
      closingIssuesReferences(first: 50) {
        nodes {
          id
          number
          projectItems(first: 100) {
            nodes {
              id
              project {
                id
                number
                field(name: "Status") {
                  ... on ProjectV2SingleSelectField {
                    id
                    options { id name }
                  }
                }
              }
              fieldValueByName(name: "Status") {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                }
              }
            }
          }
        }
      }
    }
  }
}
```

---

## 出力（生成ワークフロー）

### ワークフローログ

| 項目 | 出力内容 |
|------|---------|
| イベント種別 | `issues` / `pull_request` / `pull_request_review` |
| アクション | `opened` / `closed` / `reopened` 等 |
| 対象ノード | Issue/PR の URL |
| 現在のステータス | 更新前のステータス名 |
| 遷移先ステータス | 更新後のステータス名 |
| 更新結果 | 成功 / スキップ（ガード） / スキップ（Project 未所属） / 失敗 |
| 紐付け Issue 更新 | 連動更新した Issue の一覧（PR / レビューイベント時） |

### GitHub Actions Job Summary

```markdown
## ステータス自動同期 完了

| 項目 | 値 |
|------|-----|
| イベント | `pull_request.closed (merged)` |
| 対象 | `#123 Fix login bug` |
| ステータス遷移 | In Review → Done |
| 紐付け Issue | #100 → Done |
```

---

## API レート制限への影響評価

### 1 イベントあたりの API 呼び出し数

| 処理 | API 呼び出し数 | 種別 |
|------|--------------|------|
| Project Item 取得 | 1 | GraphQL |
| ステータス更新（対象アイテム） | 1〜N（所属プロジェクト数） | GraphQL |
| 紐付け Issue 取得 | 0〜1（PR イベント時のみ） | GraphQL |
| 紐付け Issue ステータス更新 | 0〜M（紐付け Issue 数 × プロジェクト数） | GraphQL |

### 見積もり

- **通常ケース**（1 Project, 紐付け Issue なし）: **2 回**（取得 + 更新）
- **最大ケース**（N Project, M 紐付け Issue）: **2 + N + 1 + M×N 回**
- **典型的な上限**: 1 Project, 1 紐付け Issue = **4 回**

### GitHub GraphQL API レート制限

- **5,000 ポイント/時間**（認証済みユーザー）
- 各クエリのコストは通常 1 ポイント
- 1 イベントあたり最大 4 ポイント消費と仮定した場合、**1 時間あたり約 1,250 イベント**を処理可能
- 通常の開発フローでは十分なキャパシティ

### リスク軽減策

- イベントフィルタリングにより不要な API 呼び出しを抑制
- `approved` レビューなどステータス変更不要なイベントは早期 return
- 前方遷移ガードにより不要な更新を防止

---

## ファイル構成（案）

### 本リポジトリ

```
.github/workflows/
  06-setup-sync-project-status.yml    # セットアップワークフロー

scripts/
  setup-sync-project-status.sh        # セットアップスクリプト
  templates/
    sync-project-status.yml.tpl       # 生成ワークフローのテンプレート
    sync-project-status.sh.tpl        # 生成スクリプトのテンプレート
  config/
    project-status-options.json       # 既存（変更なし）
```

### 対象リポジトリ（生成後）

```
.github/workflows/
  sync-project-status.yml             # イベント駆動ワークフロー

scripts/
  sync-project-status.sh              # ステータス同期スクリプト
```

### 権限設定

#### セットアップワークフロー（⑥）

```yaml
permissions:
  contents: read
```

> **注意**: 対象リポジトリへの操作（クローン・ブランチ作成・プッシュ・PR 作成）は `PROJECT_PAT` 経由で行う。

#### 生成ワークフロー（対象リポジトリ）

```yaml
permissions:
  contents: read
  issues: read
  pull-requests: read
```

> **注意**: Projects V2 の操作は PAT 経由で行うため、対象リポジトリにも `PROJECT_PAT` Secret の設定が必要。PR 本文にセットアップ手順を記載する。

---

## 対象リポジトリの前提条件

生成ワークフローが正しく動作するには、対象リポジトリで以下の設定が必要。

| 設定項目 | 説明 | 設定タイミング |
|---------|------|-------------|
| `PROJECT_PAT` Secret | Projects 操作権限を持つ PAT | PR マージ前に設定 |
| GitHub Actions 有効化 | ワークフロー実行の許可 | PR マージ前に確認 |

> これらの手順はセットアップワークフローが作成する PR 本文に記載し、利用者がマージ前に確認できるようにする。
