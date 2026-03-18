# 📜 detect-stale-items.sh

指定した GitHub Project の Item を走査し、 Status 別の閾値に基づいて滞留 Item を検知するスクリプトです。
DraftIssue 、 Done / Backlog Status 、除外 Label 付き Item は検知対象外となります。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-%E7%92%B0%E5%A2%83%E5%A4%89%E6%95%B0">🔧 環境変数</a></li>

<li><a href="#-%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E5%86%85%E5%AE%9A%E6%95%B0">📊 スクリプト内定数</a></li>

<li><a href="#-%E5%87%A6%E7%90%86%E3%83%95%E3%83%AD%E3%83%BC">📊 処理フロー</a></li>

<li><a href="#-%E5%87%A6%E7%90%86%E8%A9%B3%E7%B4%B0">📝 処理詳細</a></li>

<li><a href="#-api-%E3%83%AA%E3%83%95%E3%82%A1%E3%83%AC%E3%83%B3%E3%82%B9">📚 API リファレンス</a></li>

<li><a href="#-%E4%BD%BF%E7%94%A8-workflow">🔄 使用 Workflow</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 🔧 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 読み取り権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |
| `ITEM_TYPE` | 対象 Item の種別（`all` / `issues` / `prs`、デフォルト: `all`） | — |
| `ITEM_STATE` | 対象 Item の状態（`open` / `closed` / `all`、デフォルト: `all`） | — |
| `OUTPUT_FORMAT` | 出力形式（`json` / `markdown` / `csv` / `tsv`、デフォルト: `json`） | — |

## 📊 スクリプト内定数

以下の値はスクリプト内で定義されています。変更が必要な場合はスクリプトを直接編集してください。

| 定数 | デフォルト値 | 説明 |
|------|:-----------:|------|
| `STALE_DAYS_TODO` | `14` | Todo の滞留閾値（日） |
| `STALE_DAYS_IN_PROGRESS` | `7` | In Progress の滞留閾値（日） |
| `STALE_DAYS_IN_REVIEW` | `3` | In Review の滞留閾値（日） |
| `EXCLUDE_LABELS` | `on-hold,blocked` | 除外 Label（カンマ区切り） |

## 📊 処理フロー

```mermaid
flowchart TD
    A["開始"] --> B["環境変数バリデーション\nGH_TOKEN / PROJECT_OWNER / PROJECT_NUMBER"]
    B --> C["オーナータイプ判定"]
    C --> D["GraphQL で Project Item取得\n（100件ずつページネーション、Status Field値含む）"]
    D --> E{"次ページあり?"}
    E -- "Yes" --> D
    E -- "No" --> F["DraftIssue を除外\nItemを正規化"]

    F --> G["type / state フィルタリング\n（ITEM_TYPE / ITEM_STATE に応じて絞り込み）"]
    G --> H["フィルタリング\n（除外Status: Done, Backlog）\n（除外Label: on-hold, blocked）"]
    H --> I["滞留判定\n（Status別閾値との比較）"]
    I --> J["レポート生成"]
    J --> K["Workflow Summary\n（Markdown テーブル）"]
    J --> L["Artifact\n（JSON ファイル）"]
    K & L --> M["完了"]
```

## 📝 処理詳細

| ステップ | 処理内容 | 使用コマンド / API |
|---------|---------|-------------------|
| オーナータイプ判定 | `detect_owner_type` で Organization / User を判別 | `gh api users/{owner}` |
| Item 取得・正規化 | 共通ライブラリの `fetch_all_project_items` で Project の全 Item をページネーション付きで取得（100件/ページ、最大 50 ページ）。`DraftIssue` を除外し、 Issue ・ PR の `number`・`title`・`url`・`state`・`updatedAt`・`assignees`・`labels` および Status Field 値を含む統一フォーマットに正規化 | `fetch_all_project_items` — `projectV2.items(first: 100)` |
| type / state フィルタリング | `ITEM_TYPE` による種別フィルタ、`ITEM_STATE` による状態フィルタを1回の jq 呼び出しで一括適用 | `filter_items` |
| 除外フィルタリング | 除外 Status（`Done`・`Backlog`）および除外 Label（`on-hold`・`blocked`）に該当する Item を除外 | `jq` |
| 滞留判定 | 各 Item の `updatedAt` と現在日時の差分を計算し、 Status 別閾値を超過した Item を「滞留」と判定 | `jq`（`strptime`・`mktime` で日付計算） |
| レポート出力 | `OUTPUT_FORMAT` に応じて Markdown / CSV / TSV / JSON 形式のレポートファイルを生成。 CSV / TSV 形式では共通ライブラリの `format_items_csv()` / `format_items_tsv()` に委譲。 Markdown 形式では Status 別テーブル・`JQ_MD_ESCAPE` によるエスケープを適用 | `format_items_csv` / `format_items_tsv` + `jq` + bash |
| Workflow Summary 出力 | Markdown 形式のレポートを `$GITHUB_STEP_SUMMARY` に追記。`OUTPUT_FORMAT=markdown` の場合は出力ファイルを再利用 | `append_to_workflow_summary` |

## 📚 API リファレンス

| API / コマンド | 用途 | リファレンス |
|---------------|------|-------------|
| `projectV2.items` (GraphQL) | Project Item の取得 | [ProjectV2](https://docs.github.com/en/graphql/reference/objects#projectv2) |
| `ProjectV2ItemFieldSingleSelectValue` (GraphQL) | Status Field 値の取得 | [ProjectV2ItemFieldSingleSelectValue](https://docs.github.com/en/graphql/reference/objects#projectv2itemfieldsingleselect) |
| GraphQL ページネーション | カーソルベースのページ送り | [Using pagination in the GraphQL API](https://docs.github.com/en/graphql/guides/using-pagination-in-the-graphql-api) |

### API バージョン要件

REST API バージョン `2022-11-28` を使用します。共通ライブラリ（`lib/common.sh`）がオーナータイプ判定時に `X-GitHub-Api-Version: 2022-11-28` ヘッダを自動付与します。

### パラメータ上限

| パラメータ | 現在の値 | 備考 |
|-----------|---------|------|
| `items(first: N)` | 100 | 1ページあたりの取得件数 |
| `max_pages` | 50 | ページネーション上限（最大 5,000 件まで取得可能） |
| `fieldValues(first: N)` | 20 | 1Item あたりの Field 値取得数 |

## 🔄 使用 Workflow

- [⑥ 統合プロジェクト分析](../workflows/06-analyze-project)
