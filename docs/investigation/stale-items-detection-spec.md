# 🔍 滞留アイテム検知ワークフロー仕様書

<!-- START doctoc -->
<!-- END doctoc -->

> **ステータス:** 調査・仕様策定（Issue #188）
> **目的:** 一定期間更新（アクティビティ）がないプロジェクトアイテムを検出・報告する

---

## 📋 1. 背景

長期間放置されたタスクはプロジェクトの進行を阻害する。
定期的に滞留アイテムを検知し可視化することで、早期対応を促す。

## 🔬 2. 調査結果

### 2.1 GitHub Projects V2 GraphQL API でのアイテム更新日時取得

#### 利用可能なフィールド

| フィールド | 所属オブジェクト | 説明 |
|---|---|---|
| `updatedAt` | `ProjectV2Item` | プロジェクトアイテムのフィールドが最後に更新された日時 |
| `updatedAt` | `Issue` / `PullRequest` | Issue/PR 自体が最後に更新された日時（コメント・コミット等を含む） |
| `createdAt` | `Issue` / `PullRequest` | Issue/PR の作成日時 |
| `fieldValues` | `ProjectV2Item` | プロジェクトアイテムのフィールド値（Status 等）を取得可能 |

#### GraphQL クエリ例

```graphql
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
          id
          updatedAt
          fieldValues(first: 20) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                updatedAt
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
              assignees(first: 10) { nodes { login } }
              labels(first: 20) { nodes { name } }
              repository { nameWithOwner }
            }
            ... on PullRequest {
              __typename
              number
              title
              url
              state
              updatedAt
              assignees(first: 10) { nodes { login } }
              labels(first: 20) { nodes { name } }
              repository { nameWithOwner }
            }
          }
        }
      }
    }
  }
}
```

### 2.2 ステータス変更日時 vs アイテム更新日時

| 基準 | 利点 | 欠点 |
|---|---|---|
| **コンテンツ `updatedAt`（Issue/PR）** | コメント・コミット・ラベル変更等の実際のアクティビティを反映 | ステータス変更を直接反映しない |
| **アイテム `updatedAt`（ProjectV2Item）** | プロジェクトフィールド変更を反映 | フィールド変更のみで、実際の作業活動を反映しない |
| **フィールド値 `updatedAt`（SingleSelectValue）** | ステータスフィールド自体の最終更新を反映 | API の安定性に依存 |

**推奨:** コンテンツ `updatedAt`（Issue/PR）を主基準とする。

理由:
- Issue/PR に対するコメント、コミットプッシュ、レビュー等の実際のアクティビティを反映する
- ステータスだけ変更して放置されるケースも検出できる
- 既存の `export-project-items.sh` と同じフィールドを使用でき、一貫性がある
- GitHub API で最も安定的に提供されているフィールドである

### 2.3 スケジュール実行の設定

| 頻度 | ユースケース | cron 式（例） |
|---|---|---|
| **日次** | アクティブなプロジェクトで迅速な検知が必要 | `0 9 * * 1-5`（平日 9:00 UTC） |
| **週次** | 一般的なプロジェクト管理 | `0 9 * * 1`（毎週月曜 9:00 UTC） |

**推奨:** 週次（毎週月曜）をデフォルトとし、`workflow_dispatch` による手動実行も可能にする。

### 2.4 検知結果の報告方法

| 方法 | 利点 | 欠点 |
|---|---|---|
| **Workflow Summary** | 追加設定不要、GitHub Actions 標準機能 | 実行ごとに消える、通知が届かない |
| **Issue コメント** | 履歴が残る、メンション通知が可能 | コメントが蓄積して見づらくなる |
| **専用 Issue 作成** | 実行ごとに独立、検索しやすい | Issue が大量に作成される可能性 |
| **Artifact** | 大量データに対応、ダウンロード可能 | 閲覧に手間がかかる |

**推奨:** Workflow Summary を主出力とし、Artifact（JSON）を補助出力とする。

理由:
- Workflow Summary は追加設定なしで閲覧でき、既存の `workflow-summary` アクションと組み合わせ可能
- Artifact に JSON を出力することで、後続の自動化（Slack 通知等）への拡張が容易
- Issue コメントは将来のオプションとして検討可能

### 2.5 除外条件

以下の条件に該当するアイテムは滞留検知の対象外とする:

| 条件 | 理由 |
|---|---|
| ステータスが `Done` のアイテム | 完了済みのため検知不要 |
| ステータスが `Backlog` のアイテム（オプション） | 未着手のバックログは滞留とみなさない運用もある |
| `on-hold` ラベルが付与されたアイテム | 意図的に保留されている |
| `blocked` ラベルが付与されたアイテム | 外部要因で進行不可 |
| `DraftIssue` タイプのアイテム | プロジェクト内メモであり追跡対象外 |

除外ラベルは環境変数 `EXCLUDE_LABELS` で設定可能にする（カンマ区切り、デフォルト: `on-hold,blocked`）。

### 2.6 大規模プロジェクト（1000+ アイテム）での実行性能

| 項目 | 対応策 |
|---|---|
| ページネーション | 既存の `run_graphql_paginated` を使用（100件/ページ、最大50ページ = 5000件） |
| API レート制限 | GraphQL API のレート制限は 5,000 ポイント/時間。クエリのコストは取得フィールド・接続の `first` 値等で変動するため、`rateLimit { cost remaining resetAt }` を併用して実測し余裕を見積もること |
| 実行時間 | 1000 アイテムの場合、10 ページ × 約 1-2 秒 = 約 10-20 秒で完了見込み |
| メモリ | jq によるストリーム処理で、全件をメモリに保持するのはフィルタ後のアイテムのみ |

## ⚖️ 3. 滞留判定ルール

### 3.1 ステータス別閾値

| ステータス | デフォルト閾値（日） | 説明 |
|---|---|---|
| `Todo` | 14 | 着手予定のまま 2 週間以上経過 |
| `In Progress` | 7 | 作業中のまま 1 週間以上更新なし |
| `In Review` | 3 | レビュー中のまま 3 日以上更新なし |

- `Backlog` と `Done` はデフォルトで検知対象外
- 閾値は環境変数で上書き可能（`STALE_DAYS_TODO`, `STALE_DAYS_IN_PROGRESS`, `STALE_DAYS_IN_REVIEW`）

### 3.2 判定ロジック

```
滞留 = (現在日時 - コンテンツ更新日時) > ステータス別閾値
```

判定フロー:

1. プロジェクトアイテムを全件取得（ページネーション対応）
2. DraftIssue を除外
3. 各アイテムの Status フィールド値を取得
4. 除外ステータス（Done 等）・除外ラベル（on-hold 等）に該当するアイテムを除外
5. コンテンツの `updatedAt` と現在日時の差分を計算
6. ステータス別閾値を超過したアイテムを「滞留」と判定
7. ステータス別に分類してレポート出力

## 📊 4. レポート出力フォーマット

### 4.1 Workflow Summary（Markdown）

```markdown
# 滞留アイテムレポート

- **Project:** プロジェクト名 (#番号)
- **実行日時:** 2026-03-16T09:00:00Z
- **検知件数:** 5 件

## In Review（3 日以上）: 1 件

| # | タイトル | リポジトリ | アサイン | 最終更新 | 経過日数 |
|---|---------|-----------|---------|---------|---------|
| [#42](url) | タイトル | owner/repo | user1 | 2026-03-10 | 6 |

## In Progress（7 日以上）: 2 件

| # | タイトル | リポジトリ | アサイン | 最終更新 | 経過日数 |
|---|---------|-----------|---------|---------|---------|
| [#15](url) | タイトル | owner/repo | user2 | 2026-03-05 | 11 |
| [#28](url) | タイトル | owner/repo | user3 | 2026-03-01 | 15 |

## Todo（14 日以上）: 2 件

| # | タイトル | リポジトリ | アサイン | 最終更新 | 経過日数 |
|---|---------|-----------|---------|---------|---------|
| [#8](url) | タイトル | owner/repo | user4 | 2026-02-20 | 24 |
| [#12](url) | タイトル | owner/repo | - | 2026-02-15 | 29 |
```

### 4.2 Artifact（JSON）

```json
{
  "project": {
    "title": "プロジェクト名",
    "number": 1
  },
  "executed_at": "2026-03-16T09:00:00Z",
  "thresholds": {
    "Todo": 14,
    "In Progress": 7,
    "In Review": 3
  },
  "summary": {
    "total_stale": 5,
    "by_status": {
      "In Review": 1,
      "In Progress": 2,
      "Todo": 2
    }
  },
  "stale_items": [
    {
      "type": "Issue",
      "number": 42,
      "title": "タイトル",
      "url": "https://github.com/...",
      "status": "In Review",
      "repository": "owner/repo",
      "assignees": ["user1"],
      "labels": ["bug"],
      "updated_at": "2026-03-10T12:00:00Z",
      "days_stale": 6
    }
  ]
}
```

## ⚙️ 5. ワークフロー設計

### 5.1 入力パラメータ

| パラメータ | 必須 | デフォルト | 説明 |
|---|---|---|---|
| `PROJECT_OWNER` | Yes | `github.repository_owner` | Project の所有者（`workflow_dispatch` 時は `inputs`、`schedule` 時は `github.repository_owner` をデフォルトとする） |
| `PROJECT_NUMBER` | Yes | - | 対象 Project の Number |
| `STALE_DAYS_TODO` | No | `14` | Todo の滞留閾値（日） |
| `STALE_DAYS_IN_PROGRESS` | No | `7` | In Progress の滞留閾値（日） |
| `STALE_DAYS_IN_REVIEW` | No | `3` | In Review の滞留閾値（日） |
| `EXCLUDE_LABELS` | No | `on-hold,blocked` | 除外ラベル（カンマ区切り） |
| `INCLUDE_BACKLOG` | No | `false` | Backlog を検知対象に含めるか |
| `STALE_DAYS_BACKLOG` | No | `30` | Backlog の滞留閾値（日、INCLUDE_BACKLOG=true 時のみ有効） |

### 5.2 ワークフロー構成

```yaml
name: "⑥ 滞留アイテム検知"

on:
  schedule:
    - cron: '0 9 * * 1'  # 毎週月曜 9:00 UTC
  workflow_dispatch:
    inputs:
      project-owner:
        description: "Project の所有者"
        required: true
      project-number:
        description: "Project の Number"
        required: true
      stale-days-todo:
        description: "Todo の滞留閾値（日）"
        default: "14"
      stale-days-in-progress:
        description: "In Progress の滞留閾値（日）"
        default: "7"
      stale-days-in-review:
        description: "In Review の滞留閾値（日）"
        default: "3"
      exclude-labels:
        description: "除外ラベル（カンマ区切り）"
        default: "on-hold,blocked"
      include-backlog:
        description: "Backlog を検知対象に含めるか"
        type: boolean
        default: false

jobs:
  detect-stale-items:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6.0.2
      - name: 滞留アイテム検知
        env:
          GH_TOKEN: ${{ secrets.PROJECT_PAT }}
          PROJECT_OWNER: ${{ inputs.project-owner || github.repository_owner }}
          PROJECT_NUMBER: ${{ inputs.project-number || vars.PROJECT_NUMBER }}
          STALE_DAYS_TODO: ${{ inputs.stale-days-todo || '14' }}
          STALE_DAYS_IN_PROGRESS: ${{ inputs.stale-days-in-progress || '7' }}
          STALE_DAYS_IN_REVIEW: ${{ inputs.stale-days-in-review || '3' }}
          EXCLUDE_LABELS: ${{ inputs.exclude-labels || 'on-hold,blocked' }}
          INCLUDE_BACKLOG: ${{ inputs.include-backlog || 'false' }}
        run: |
          chmod +x scripts/detect-stale-items.sh
          bash scripts/detect-stale-items.sh

  workflow-summary-failure:
    needs: [detect-stale-items]
    if: failure()
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6.0.2
      - uses: ./.github/actions/workflow-summary
        with:
          status: failure
          project-owner: ${{ github.repository_owner }}
          project-number: ${{ inputs.project-number || vars.PROJECT_NUMBER }}
          job-results: |
            {"detect-stale-items": "${{ needs.detect-stale-items.result }}"}

  workflow-summary-success:
    needs: [detect-stale-items]
    if: success()
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6.0.2
      - uses: ./.github/actions/workflow-summary
        with:
          status: success
          project-owner: ${{ github.repository_owner }}
          project-number: ${{ inputs.project-number || vars.PROJECT_NUMBER }}
          job-results: |
            {"detect-stale-items": "${{ needs.detect-stale-items.result }}"}
```

### 5.3 スクリプト処理概要

`scripts/detect-stale-items.sh` の処理フロー:

1. 環境変数バリデーション（`validate_common_project_env` + 閾値の数値チェック）
2. プロジェクトアイテム取得（ページネーション対応、Status フィールド値を含む）
3. フィルタリング（DraftIssue 除外、除外ステータス・ラベル適用）
4. 滞留判定（ステータス別閾値との比較）
5. レポート生成（Workflow Summary 用 Markdown + Artifact 用 JSON）
6. コンソールサマリー出力

## 🚀 6. 今後の拡張候補

- Slack / Teams 通知連携（Artifact JSON を入力として webhook 送信）
- Issue コメントへの自動投稿オプション
- 滞留アイテムへの自動ラベル付与（`stale` ラベル）
- トレンドレポート（前回実行との差分表示）
