# 📜 export-project-items.sh

指定した GitHub Project に紐づく Issue / Pull Request の一覧を取得し、エクスポートするスクリプトです。
DraftIssue は出力対象外となります。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-%E7%92%B0%E5%A2%83%E5%A4%89%E6%95%B0">🔧 環境変数</a></li>

<li><a href="#-%E5%87%A6%E7%90%86%E3%83%95%E3%83%AD%E3%83%BC">📊 処理フロー</a></li>

<li><a href="#-%E5%87%A6%E7%90%86%E8%A9%B3%E7%B4%B0">📝 処理詳細</a></li>

<li><a href="#-api-%E3%83%AA%E3%83%95%E3%82%A1%E3%83%AC%E3%83%B3%E3%82%B9">📚 API リファレンス</a></li>

<li><a href="#-%E5%87%BA%E5%8A%9B%E5%BD%A2%E5%BC%8F%E3%81%94%E3%81%A8%E3%81%AE%E3%82%A8%E3%82%B9%E3%82%B1%E3%83%BC%E3%83%97%E4%BB%95%E6%A7%98">📝 出力形式ごとのエスケープ仕様</a></li>

<li><a href="#-%E4%BD%BF%E7%94%A8-workflow">🔄 使用 Workflow</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 🔧 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 読み取り権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |
| `OUTPUT_FORMAT` | 出力形式（`markdown`/`csv`/`tsv`/`json`） | ❌（デフォルト: `markdown`） |
| `ITEM_TYPE` | 対象 Item の種別（`all`/`issues`/`prs`） | ❌（デフォルト: `all`） |
| `ITEM_STATE` | 取得する Item の状態（`open`/`closed`/`all`） | ❌（デフォルト: `all`） |

## 📊 処理フロー

```mermaid
flowchart TD
    A["開始"] --> B["環境変数バリデーション\nOUTPUT_FORMAT / ITEM_TYPE / ITEM_STATE チェック"]
    B --> C["オーナータイプ判定"]
    C --> D["GraphQL で Project Item取得\n（100件ずつページネーション）"]
    D --> E{"次ページあり?"}
    E -- "Yes" --> D
    E -- "No" --> F["DraftIssue を除外\nItemを正規化"]

    F --> G["type / state フィルタリング\n（ITEM_TYPE, ITEM_STATE）"]
    G --> H{"OUTPUT_FORMAT"}
    H -- "markdown" --> I["Markdown テーブル形式\n（Issue / PR 別セクション）"]
    H -- "csv" --> J["CSV 形式\n（format_items_csv）"]
    H -- "tsv" --> K["TSV 形式\n（format_items_tsv）"]
    H -- "json" --> L["JSON 形式\n（整形出力）"]

    I & J & K & L --> M["ファイルに出力\nexport-{number}-items.{ext}"]
    M --> N["完了"]
```

## 📝 処理詳細

| ステップ | 処理内容 | 使用コマンド / API |
|---------|---------|-------------------|
| オーナータイプ判定 | `detect_owner_type` で Organization / User を判別 | `gh api users/{owner}` |
| Item 取得・正規化 | 共通ライブラリの `fetch_all_project_items` で Project の全 Item をページネーション付きで取得（100件/ページ、最大 50 ページ）。`DraftIssue` を除外し、 Issue ・ PR の `number`・`title`・`url`・`state`・`author`・`assignees`・`labels` 等を含む統一フォーマットに正規化 | `fetch_all_project_items` — `projectV2.items(first: 100)` |
| type / state フィルタリング | `ITEM_TYPE` による種別フィルタ、`ITEM_STATE` による状態フィルタ（`closed` は `CLOSED` + `MERGED` を含む）を1回の jq 呼び出しで一括適用 | `filter_items` |
| Markdown 出力 | Issue と PR を別セクションに分け、テーブル形式で出力。タイトル・ Label ・アサイン内の Markdown 特殊文字をエスケープ。エスケープには共通ライブラリの `JQ_MD_ESCAPE` を使用 | `format_markdown` 関数 |
| CSV / TSV 出力 | 共通ライブラリの `format_items_csv()` / `format_items_tsv()` に委譲し、ヘッダー行付きで `@csv` / `@tsv` フィルタで変換 | `format_items_csv` / `format_items_tsv` |
| JSON 出力 | jq で整形して出力 | `jq '.'` |
| 出力ファイル構築 | `build_output_filename` で出力ファイルパスを構築 | `build_output_filename` |

## 📚 API リファレンス

| API / コマンド | 用途 | リファレンス |
|---------------|------|-------------|
| `projectV2.items` (GraphQL) | Project Item の取得 | [ProjectV2](https://docs.github.com/en/graphql/reference/objects#projectv2) |
| GraphQL ページネーション | カーソルベースのページ送り | [Using pagination in the GraphQL API](https://docs.github.com/en/graphql/guides/using-pagination-in-the-graphql-api) |

### API バージョン要件

REST API バージョン `2022-11-28` を使用します。共通ライブラリ（`lib/common.sh`）がオーナータイプ判定時に `X-GitHub-Api-Version: 2022-11-28` ヘッダを自動付与します。

### パラメータ上限

| パラメータ | 現在の値 | 備考 |
|-----------|---------|------|
| `items(first: N)` | 100 | 1ページあたりの取得件数 |
| `max_pages` | 50 | ページネーション上限（最大 5,000 件まで取得可能） |

## 📝 出力形式ごとのエスケープ仕様

| 出力形式 | クォート | エスケープ対象 | 備考 |
|----------|----------|---------------|------|
| `markdown` | なし | `\`, `` ` ``, `*`, `_`, `[`, `]`, `<`, `>`, `~`, `|` | タイトル・Label・アサインの各Fieldに適用（例: `|` → `\|`） |
| `csv` | `"` で囲む | `"` → `""` | jq `@csv`（RFC 4180 準拠）により自動処理 |
| `tsv` | なし | タブ → `\t`, 改行 → `\n`, `\` → `\\` | jq `@tsv` により自動処理 |
| `json` | `"` で囲む | JSON 標準のエスケープ | jq により自動処理 |

## 🔄 使用 Workflow

- [⑥ 統合プロジェクト分析](../workflows/06-analyze-project.md)（`report_types: export`）
