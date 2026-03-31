# 📜 generate-velocity-report.sh

指定した GitHub Project の Done Item を週別に集計し、ベロシティ（完了数・完了工数）の推移を可視化するレポートを生成するスクリプトです。
担当者別のベロシティ集計も行います。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-%E7%92%B0%E5%A2%83%E5%A4%89%E6%95%B0">🔧 環境変数</a></li>

<li><a href="#-%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88%E5%86%85%E5%AE%9A%E6%95%B0">📊 スクリプト内定数</a></li>

<li><a href="#-%E9%9B%86%E8%A8%88%E9%A0%85%E7%9B%AE">📊 集計項目</a></li>

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

| 定数 | 値 | 説明 |
|------|---|------|
| `VELOCITY_WEEKS` | `8` | デフォルトの集計対象週数 |

## 📊 集計項目

### 必須項目

| # | 集計項目 | 説明 |
|---|---------|------|
| 1 | **概要サマリー** | 集計期間、 Done Item 数、平均ベロシティ（件/週） |
| 2 | **週別ベロシティ** | 各週の完了 Item 数（Mermaid 棒グラフ付き） |
| 3 | **担当者別ベロシティ** | 担当者ごとの完了数合計（Mermaid 円グラフ付き） |

### オプション項目（工数 Field 使用時）

| # | 集計項目 | 説明 |
|---|---------|------|
| 4 | **週別完了工数** | 各週の完了工数（Mermaid 棒グラフ付き） |
| 5 | **平均完了工数** | 平均完了工数（h/週） |
| 6 | **担当者別完了工数** | 担当者ごとの完了工数合計 |

> **Note:** 実績工数(h) Field が設定されていないプロジェクトでは、工数関連の項目は自動的に非表示となります。

## 📊 処理フロー

```mermaid
flowchart TD
    A["開始"] --> B["環境変数バリデーション\nGH_TOKEN / PROJECT_OWNER / PROJECT_NUMBER"]
    B --> C["オーナータイプ判定"]
    C --> D["GraphQL で Project Item取得\n（100件ずつページネーション、Status・工数Field含む）"]
    D --> E{"次ページあり?"}
    E -- "Yes" --> D
    E -- "No" --> F["DraftIssue を除外\nItemを正規化"]

    F --> G["type / state フィルタリング\n（ITEM_TYPE / ITEM_STATE に応じて絞り込み）"]
    G --> H["Done StatusのItemを抽出\n集計期間内のものに絞り込み"]
    H --> I["週別ベロシティ集計\n（ISO 週ベースで完了数・工数を集計）"]
    H --> J["担当者別ベロシティ集計"]
    I --> K["平均ベロシティ算出"]
    I & J & K --> L["レポート生成"]
    L --> M["Workflow Summary\n（Markdown + Mermaid チャート）"]
    L --> N["Artifact\n（JSON / Markdown / CSV / TSV ファイル）"]
    M & N --> O["完了"]
```

## 📝 処理詳細

| ステップ | 処理内容 | 使用コマンド / API |
|---------|---------|-------------------|
| オーナータイプ判定 | `detect_owner_type` で Organization / User を判別 | `gh api users/{owner}` |
| Item 取得・正規化 | 共通ライブラリの `fetch_all_project_items` で Project の全 Item をページネーション付きで取得（100件/ページ、最大 50 ページ）。`DraftIssue` を除外し、 Issue ・ PR の基本情報に加え、 Status ・実績工数(h) の Field 値を含む統一フォーマットに正規化 | `fetch_all_project_items` — `projectV2.items(first: 100)` |
| type / state フィルタリング | `ITEM_TYPE` による種別フィルタ、`ITEM_STATE` による状態フィルタを1回の jq 呼び出しで一括適用 | `filter_items` |
| Done Item 抽出 | Status が `Done` の Item を抽出し、集計期間内（ProjectV2Item の `updatedAt` ベース）のものに絞り込み | `jq` |
| 集計期間の計算 | ISO 週ベースで `VELOCITY_WEEKS` 週間の開始日・終了日を `jq` で算出（macOS/Linux 互換） | `jq` |
| 週別集計 | 各週にマッチする Done Item の完了数・完了工数を集計 | `jq` |
| 担当者別集計 | 担当者ごとの完了数・完了工数合計を算出。複数担当者の Item は各担当者に計上。未アサインの Item は「(未アサイン)」として集計 | `jq` |
| 平均ベロシティ算出 | 集計週数で完了数・完了工数を除算 | `jq` |
| レポート出力 | `build_output_filename` で出力ファイルパスを構築し、`OUTPUT_FORMAT` に応じて Markdown / CSV / TSV / JSON 形式のレポートファイルを生成。 CSV / TSV 形式では共通ライブラリの `format_items_csv()` / `format_items_tsv()` に委譲。 Markdown 形式では Mermaid 棒グラフ・円グラフを含む | `build_output_filename` + `format_items_csv` / `format_items_tsv` + `jq` + bash |
| Workflow Summary 出力 | Markdown 形式のレポートを `$GITHUB_STEP_SUMMARY` に追記。`OUTPUT_FORMAT=markdown` の場合は出力ファイルを再利用 | `append_to_workflow_summary` |

## 📚 API リファレンス

| API / コマンド | 用途 | リファレンス |
|---------------|------|-------------|
| `projectV2.items` (GraphQL) | Project Item の取得 | [ProjectV2](https://docs.github.com/en/graphql/reference/objects#projectv2) |
| `ProjectV2ItemFieldSingleSelectValue` (GraphQL) | Status Field 値の取得 | [ProjectV2ItemFieldSingleSelectValue](https://docs.github.com/en/graphql/reference/objects#projectv2itemfieldsingleselect) |
| `ProjectV2ItemFieldNumberValue` (GraphQL) | 数値 Field 値の取得 | [ProjectV2ItemFieldNumberValue](https://docs.github.com/en/graphql/reference/objects#projectv2itemfieldnumbervalue) |
| GraphQL ページネーション | カーソルベースのページ送り | [Using pagination in the GraphQL API](https://docs.github.com/en/graphql/guides/using-pagination-in-the-graphql-api) |

### API バージョン要件

REST API バージョン `2022-11-28` を使用します。共通ライブラリ（`lib/common.sh`）がオーナータイプ判定時に `X-GitHub-Api-Version: 2022-11-28` ヘッダを自動付与します。

### パラメータ上限

| パラメータ | 現在の値 | 備考 |
|-----------|---------|------|
| `items(first: N)` | 100 | 1ページあたりの取得件数 |
| `max_pages` | 50 | ページネーション上限（最大 5,000 件まで取得可能） |
| `fieldValues(first: N)` | 20 | 1Item あたりの Field 値取得数 |
| `assignees(first: N)` | 100 | 1Item あたりのアサイン取得数 |

## 🔄 使用 Workflow

- [⑥ 統合プロジェクト分析](../workflows/06-analyze-project.md)
