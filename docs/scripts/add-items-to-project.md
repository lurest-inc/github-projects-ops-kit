# add-items-to-project.sh

リポジトリの `Issue`/`PR` を `Project` に一括追加するスクリプトです。
既に `Project` に追加済みのアイテムは自動的にスキップされます。

## 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | `Project` の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 `Project` の Number（数値） | ✅ |
| `TARGET_REPO` | 対象リポジトリ（owner/repo 形式） | ✅ |
| `ITEM_TYPE` | 対象アイテムの種別（`all`/`issues`/`prs`） | ❌（デフォルト: `all`） |
| `ITEM_STATE` | 取得するアイテムの状態（`open`/`closed`/`all`） | ❌（デフォルト: `open`） |
| `ITEM_LABEL` | 絞り込みラベル | ❌ |

## 処理フロー

```mermaid
flowchart TD
    A["開始"] --> B["環境変数バリデーション"]
    B --> C["オーナータイプ判定"]
    C --> D["GraphQL で Project ID・\nStatus フィールド ID・\nOption ID を一括取得"]
    D --> E["GraphQL で Project の\n既存アイテム URL 一覧を取得\n（ページネーション対応）"]

    E --> F{"ITEM_TYPE に\nIssue を含む?"}
    F -- "Yes" --> G["fetch_and_add_items\n（Issue）"]
    F -- "No" --> H{"ITEM_TYPE に\nPR を含む?"}
    G --> M
    V --> H

    H -- "Yes" --> I["fetch_and_add_items\n（PR）"]
    H -- "No" --> J["サマリー出力"]
    I --> M
    V --> J
    J --> K["完了"]

    subgraph L["fetch_and_add_items 関数"]
        M["gh issue/pr list で\nアイテム一覧を取得"] --> N["各アイテムをループ"]
        N --> O{"既存アイテムに\n含まれる?"}
        O -- "Yes" --> P["スキップ"]
        O -- "No" --> Q["gh project item-add\nで追加"]
        Q --> R{"Done 対象の\nstate?"}
        R -- "Yes" --> S["ステータス: Done"]
        R -- "No" --> T["ステータス: Backlog"]
        P & S & T --> U{"次のアイテム\nあり?"}
        U -- "Yes" --> N
        U -- "No" --> V["件数サマリー出力"]
    end
```

## 処理詳細

| ステップ | 処理内容 | 使用コマンド / API |
|---------|---------|-------------------|
| オーナータイプ判定 | `detect_owner_type` で `Organization` / `User` を判別 | `gh api users/{owner}` |
| `Status` フィールド取得 | GraphQL で `Project` ID・`Status` フィールド ID・各ステータスの Option ID を一括抽出 | `gh api graphql` — `projectV2.fields` |
| 既存アイテム取得 | GraphQL クエリで `Project` に紐づく全アイテムの URL をページネーション付きで取得。重複防止に使用 | `gh api graphql` — `projectV2.items(first: 100)` |
| アイテム取得・追加 | `fetch_and_add_items` 関数で `Issue` / `PR` を共通処理。`ITEM_STATE`・`ITEM_LABEL` で絞り込んで一覧を取得し、重複チェック・追加・ステータス設定を実行（`Issue` / `PR` 各種別ごとに最大 100 件、1件ごとに 1秒の sleep） | `gh issue list` / `gh pr list`・`gh project item-add`・`updateProjectV2ItemFieldValue` |
| ステータス設定 | 追加したアイテムにステータスを自動付与。open → Backlog、closed/merged → Done | `gh api graphql` — `updateProjectV2ItemFieldValue` |
| サマリー出力 | `Issue`・`PR` それぞれの追加・スキップ・失敗件数をコンソールと `GITHUB_STEP_SUMMARY` に出力 | — |

## API リファレンス

| API / コマンド | 用途 | リファレンス |
|---------------|------|-------------|
| `projectV2.items` (GraphQL) | 既存アイテム URL の取得（重複防止） | [ProjectV2](https://docs.github.com/en/graphql/reference/objects#projectv2) |
| `gh issue list` | `Issue` 一覧の取得 | [gh issue list](https://cli.github.com/manual/gh_issue_list) |
| `gh pr list` | `PR` 一覧の取得 | [gh pr list](https://cli.github.com/manual/gh_pr_list) |
| `gh project item-add` | アイテムの `Project` への追加 | [gh project item-add](https://cli.github.com/manual/gh_project_item-add) |
| `projectV2.fields` (GraphQL) | `Status` フィールド ID・Option ID の取得 | [ProjectV2SingleSelectField](https://docs.github.com/en/graphql/reference/objects#projectv2singleselectfield) |
| `updateProjectV2ItemFieldValue` (GraphQL) | アイテムのステータス設定 | [updateProjectV2ItemFieldValue](https://docs.github.com/en/graphql/reference/mutations#updateprojectv2itemfieldvalue) |

### API バージョン要件

REST API バージョン `2022-11-28` を使用します。共通ライブラリ（`lib/common.sh`）がオーナータイプ判定時に `X-GitHub-Api-Version: 2022-11-28` ヘッダを自動付与します。

### パラメータ上限

| パラメータ | 現在の値 | 備考 |
|-----------|---------|------|
| `items(first: N)` | 100 | 既存アイテム取得のページサイズ |
| `--limit` | 100 | `gh issue list` / `gh pr list` の最大取得件数 |
| `sleep` | 1秒 | アイテム追加間のレート制限回避待機時間 |

## 使用ワークフロー

- [③ Issue/PR 一括紐付け](../workflows/03-add-items-to-project)
