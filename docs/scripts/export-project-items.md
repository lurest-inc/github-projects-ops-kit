# 📜 export-project-items.sh

<!-- START doctoc -->
<!-- END doctoc -->

指定した GitHub Project に紐づく Issue / Pull Request の一覧を取得し、エクスポートするスクリプトです。
DraftIssue は出力対象外となります。

## 🔧 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 読み取り権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |
| `OUTPUT_FORMAT` | 出力形式（`markdown`/`csv`/`tsv`/`json`） | ❌（デフォルト: `markdown`） |
| `ITEM_TYPE` | 対象アイテムの種別（`all`/`issues`/`prs`） | ❌（デフォルト: `all`） |
| `ITEM_STATE` | 取得するアイテムの状態（`open`/`closed`/`all`） | ❌（デフォルト: `all`） |

## 📊 処理フロー

```mermaid
flowchart TD
    A["開始"] --> B["環境変数バリデーション\nOUTPUT_FORMAT / ITEM_TYPE / ITEM_STATE チェック"]
    B --> C["オーナータイプ判定"]
    C --> D["GraphQL で Project アイテム取得\n（100件ずつページネーション）"]
    D --> E{"次ページあり?"}
    E -- "Yes" --> D
    E -- "No" --> F["DraftIssue を除外\nアイテムを正規化"]

    F --> G["type / state フィルタリング\n（ITEM_TYPE, ITEM_STATE）"]
    G --> H{"OUTPUT_FORMAT"}
    H -- "markdown" --> I["Markdown テーブル形式\n（Issue / PR 別セクション）"]
    H -- "csv" --> J["CSV 形式\n（@csv フィルタ）"]
    H -- "tsv" --> K["TSV 形式\n（@tsv フィルタ）"]
    H -- "json" --> L["JSON 形式\n（整形出力）"]

    I & J & K & L --> M["ファイルに出力\nexport-{number}-items.{ext}"]
    M --> N["完了"]
```

## 📝 処理詳細

| ステップ | 処理内容 | 使用コマンド / API |
|---------|---------|-------------------|
| オーナータイプ判定 | `detect_owner_type` で Organization / User を判別 | `gh api users/{owner}` |
| アイテム取得 | GraphQL クエリで Project の全アイテムをページネーション付きで取得（100件/ページ、最大 50 ページ）。Issue・PR の `number`・`title`・`url`・`state`・`author`・`assignees`・`labels` 等を取得 | `gh api graphql` — `projectV2.items(first: 100)` |
| データ正規化 | `DraftIssue`（`__typename` が null）を除外し、各アイテムを統一フォーマットの JSON オブジェクトに変換 | `jq` |
| type / state フィルタリング | `ITEM_TYPE` による種別フィルタ、`ITEM_STATE` による状態フィルタ（`closed` は `CLOSED` + `MERGED` を含む）を適用 | `jq` |
| Markdown 出力 | Issue と PR を別セクションに分け、テーブル形式で出力。タイトル・ラベル・アサイン内の Markdown 特殊文字をエスケープ。エスケープには共通ライブラリの `JQ_MD_ESCAPE` を使用 | `format_markdown` 関数 |
| CSV / TSV 出力 | jq の `@csv` / `@tsv` フィルタで変換 | `format_csv` / `format_tsv` 関数 |
| JSON 出力 | jq で整形して出力 | `format_json` 関数 |

## 📚 API リファレンス

| API / コマンド | 用途 | リファレンス |
|---------------|------|-------------|
| `projectV2.items` (GraphQL) | Project アイテムの取得 | [ProjectV2](https://docs.github.com/en/graphql/reference/objects#projectv2) |
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
| `markdown` | なし | `\`, `` ` ``, `*`, `_`, `[`, `]`, `<`, `>`, `~`, `|` | タイトル・ラベル・アサインの各フィールドに適用（例: `|` → `\|`） |
| `csv` | `"` で囲む | `"` → `""` | jq `@csv`（RFC 4180 準拠）により自動処理 |
| `tsv` | なし | タブ → `\t`, 改行 → `\n`, `\` → `\\` | jq `@tsv` により自動処理 |
| `json` | `"` で囲む | JSON 標準のエスケープ | jq により自動処理 |

## 🔄 使用ワークフロー

- [⑩ 統合プロジェクト分析](../workflows/10-analyze-project)（`report_types: export`）
