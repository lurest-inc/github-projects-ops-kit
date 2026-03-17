# 📜 generate-summary-report.sh

<!-- START doctoc -->
<!-- END doctoc -->

指定した GitHub Project のアイテムを走査し、ステータス別・担当者別・ラベル別の集計レポートを生成するスクリプトです。
カスタムフィールド（工数・期日）が設定されている場合は、工数サマリーと期日超過アイテムの集計も行います。

## 🔧 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 読み取り権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |
| `ITEM_TYPE` | 対象アイテムの種別（`all` / `issues` / `prs`、デフォルト: `all`） | — |
| `ITEM_STATE` | 対象アイテムの状態（`open` / `closed` / `all`、デフォルト: `all`） | — |
| `OUTPUT_FORMAT` | 出力形式（`json` / `markdown` / `csv` / `tsv`、デフォルト: `json`） | — |

## 📊 集計項目

### 必須項目

| # | 集計項目 | 説明 |
|---|---------|------|
| 1 | **概要サマリー** | 総アイテム数、Issue/PR 別件数、OPEN/CLOSED 別件数 |
| 2 | **ステータス別件数** | 各ステータス（Backlog〜Done）の件数と割合 |
| 3 | **担当者別件数** | 各担当者のアイテム数（未アサイン含む） |
| 4 | **ラベル別件数** | 各ラベルのアイテム数（ラベルなし含む） |

### オプション項目（カスタムフィールド使用時）

| # | 集計項目 | 説明 |
|---|---------|------|
| 5 | **工数サマリー** | ステータス別の見積もり工数合計・実績工数合計 |
| 6 | **期日超過アイテム** | 終了期日を過ぎた未完了アイテムの一覧 |

> **Note:** カスタムフィールドが設定されていないプロジェクトでは、オプション項目のセクションは自動的に非表示となります。

## 📊 処理フロー

```mermaid
flowchart TD
    A["開始"] --> B["環境変数バリデーション\nGH_TOKEN / PROJECT_OWNER / PROJECT_NUMBER"]
    B --> C["オーナータイプ判定"]
    C --> D["GraphQL で Project アイテム取得\n（100件ずつページネーション、フィールド値含む）"]
    D --> E{"次ページあり?"}
    E -- "Yes" --> D
    E -- "No" --> F["DraftIssue を除外\nアイテムを正規化"]

    F --> G["type フィルタリング\n（ITEM_TYPE に応じて Issue/PR を絞り込み）"]
    G --> H["state フィルタリング\n（ITEM_STATE に応じて open/closed を絞り込み）"]
    H --> I["集計処理"]
    I --> J["ステータス別集計"]
    I --> K["担当者別集計"]
    I --> L["ラベル別集計"]
    I --> M["工数集計\n（カスタムフィールドがある場合）"]
    I --> N["期日超過判定\n（カスタムフィールドがある場合）"]
    J & K & L & M & N --> O["レポート生成"]
    O --> P["Workflow Summary\n（Markdown + Mermaid チャート）"]
    O --> Q["Artifact\n（JSON ファイル）"]
    P & Q --> R["完了"]
```

## 📝 処理詳細

| ステップ | 処理内容 | 使用コマンド / API |
|---------|---------|-------------------|
| オーナータイプ判定 | `detect_owner_type` で Organization / User を判別 | `gh api users/{owner}` |
| アイテム取得・正規化 | 共通ライブラリの `fetch_all_project_items` で Project の全アイテムをページネーション付きで取得（100件/ページ、最大 50 ページ）。`DraftIssue` を除外し、Issue・PR の基本情報に加え、Status・見積もり工数(h)・実績工数(h)・終了期日のフィールド値を含む統一フォーマットに正規化 | `fetch_all_project_items` — `projectV2.items(first: 100)` |
| type フィルタリング | `ITEM_TYPE` に応じて Issue / PR を絞り込み | `filter_items_by_type` |
| state フィルタリング | `ITEM_STATE` に応じて open / closed を絞り込み | `filter_items_by_state` |
| ステータス別集計 | 各ステータスの件数と割合を計算 | `jq` |
| 担当者別集計 | 各担当者のアイテム数と In Progress / In Review の内訳を集計。未アサインアイテムも含む | `jq` |
| ラベル別集計 | 各ラベルのアイテム数を集計。ラベルなしアイテムも含む | `jq` |
| 工数集計 | ステータス別の見積もり工数合計・実績工数合計を算出（カスタムフィールドが設定されている場合のみ） | `jq` |
| 期日超過判定 | 終了期日を過ぎた未完了（Done 以外の）アイテムを検出し超過日数を計算（カスタムフィールドが設定されている場合のみ） | `jq` |
| レポート出力 | `OUTPUT_FORMAT` に応じて Markdown / CSV / TSV / JSON 形式のレポートファイルを生成。Markdown 形式では Mermaid 円グラフを含む | `jq` + bash |
| Workflow Summary 出力 | Markdown 形式のレポートを `$GITHUB_STEP_SUMMARY` に追記 | — |

## 📚 API リファレンス

| API / コマンド | 用途 | リファレンス |
|---------------|------|-------------|
| `projectV2.items` (GraphQL) | Project アイテムの取得 | [ProjectV2](https://docs.github.com/en/graphql/reference/objects#projectv2) |
| `ProjectV2ItemFieldSingleSelectValue` (GraphQL) | Status フィールド値の取得 | [ProjectV2ItemFieldSingleSelectValue](https://docs.github.com/en/graphql/reference/objects#projectv2itemfieldsingleselect) |
| `ProjectV2ItemFieldNumberValue` (GraphQL) | 数値フィールド値の取得 | [ProjectV2ItemFieldNumberValue](https://docs.github.com/en/graphql/reference/objects#projectv2itemfieldnumbervalue) |
| `ProjectV2ItemFieldDateValue` (GraphQL) | 日付フィールド値の取得 | [ProjectV2ItemFieldDateValue](https://docs.github.com/en/graphql/reference/objects#projectv2itemfielddatevalue) |
| GraphQL ページネーション | カーソルベースのページ送り | [Using pagination in the GraphQL API](https://docs.github.com/en/graphql/guides/using-pagination-in-the-graphql-api) |

### API バージョン要件

REST API バージョン `2022-11-28` を使用します。共通ライブラリ（`lib/common.sh`）がオーナータイプ判定時に `X-GitHub-Api-Version: 2022-11-28` ヘッダを自動付与します。

### パラメータ上限

| パラメータ | 現在の値 | 備考 |
|-----------|---------|------|
| `items(first: N)` | 100 | 1ページあたりの取得件数 |
| `max_pages` | 50 | ページネーション上限（最大 5,000 件まで取得可能） |
| `fieldValues(first: N)` | 20 | 1アイテムあたりのフィールド値取得数 |
| `assignees(first: N)` | 100 | 1アイテムあたりのアサイン取得数 |
| `labels(first: N)` | 100 | 1アイテムあたりのラベル取得数 |

## 🔄 使用ワークフロー

- [⑤ 統合プロジェクト分析](../workflows/05-analyze-project)
