# setup-project-fields.sh

`Project` にカスタムフィールドを自動作成するスクリプトです。
既に同名のフィールドが存在する場合は自動的にスキップされます。

## 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | `Project` の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 `Project` の Number（数値） | ✅ |

## 作成されるフィールド

フィールド定義は `scripts/config/field-definitions.json` に外部化されています。
デフォルトでは以下のフィールドが作成されます:

| フィールド名 | データ型 | 選択肢 |
|-------------|---------|--------|
| 見積もり工数(h) | NUMBER | - |
| 開始予定 | DATE | - |
| 終了予定 | DATE | - |
| 実績工数(h) | NUMBER | - |
| 開始実績 | DATE | - |
| 終了実績 | DATE | - |
| 終了期日 | DATE | - |
| 依頼元 | TEXT | - |

## フィールド構成図

```mermaid
graph TD
    Project["Project"] --> EstimateHours["見積もり工数(h)\n(NUMBER)"]
    Project --> StartPlanned["開始予定\n(DATE)"]
    Project --> EndPlanned["終了予定\n(DATE)"]
    Project --> ActualHours["実績工数(h)\n(NUMBER)"]
    Project --> StartActual["開始実績\n(DATE)"]
    Project --> EndActual["終了実績\n(DATE)"]
    Project --> Deadline["終了期日\n(DATE)"]
    Project --> Requester["依頼元\n(TEXT)"]
```

## 処理フロー

```mermaid
flowchart TD
    A["開始"] --> B["環境変数バリデーション"]
    B --> C["オーナータイプ判定"]
    C --> D["フィールド定義ファイル読み込み\n（config/field-definitions.json）"]
    D --> E["GraphQL で既存フィールド一覧を取得"]
    E --> F{"取得成功?"}
    F -- "No" --> G["エラー出力"]
    G --> H["異常終了"]

    F -- "Yes" --> I["フィールド定義をループ"]
    I --> J{"同名フィールド\n既に存在?"}
    J -- "Yes" --> K["スキップ"]
    J -- "No" --> L["GraphQL createProjectV2Field\nでフィールド作成"]
    L --> M{"作成成功?"}
    M -- "Yes" --> N["作成カウント +1"]
    M -- "No" --> O["失敗カウント +1"]

    K & N & O --> P{"次のフィールド\nあり?"}
    P -- "Yes" --> I
    P -- "No" --> Q["サマリー出力"]
    Q --> R{"失敗あり?"}
    R -- "Yes" --> H
    R -- "No" --> S["完了"]
```

## 処理詳細

| ステップ | 処理内容 | 使用コマンド / API |
|---------|---------|-------------------|
| オーナータイプ判定 | `detect_owner_type` で `Organization` / `User` を判別し、GraphQL クエリのフィールド名を決定 | `gh api users/{owner}` |
| フィールド定義ファイル読み込み | `scripts/config/field-definitions.json` からフィールド定義を読み込み | `cat` |
| 既存フィールド取得 | GraphQL クエリで `Project` ID と全フィールド（名前・データ型・選択肢）を一括取得 | `gh api graphql` — `projectV2.fields(first: 100)` |
| 重複チェック | 既存フィールド名リストと定義済みフィールド名を `grep -Fqx` で完全一致比較 | — |
| フィールド作成 | データ型に応じてフィールドを作成（`SINGLE_SELECT` の場合は `singleSelectOptions` で選択肢を付与） | `gh api graphql` — `createProjectV2Field` mutation |
| サマリー出力 | 作成・スキップ・失敗の件数をコンソールと `GITHUB_STEP_SUMMARY` に出力 | — |

## API リファレンス

| API / コマンド | 用途 | リファレンス |
|---------------|------|-------------|
| `projectV2.fields` (GraphQL) | 既存フィールド一覧の取得 | [ProjectV2](https://docs.github.com/en/graphql/reference/objects#projectv2) |
| `createProjectV2Field` (GraphQL) | カスタムフィールドの作成 | [createProjectV2Field](https://docs.github.com/en/graphql/reference/mutations#createprojectv2field) |

### API バージョン要件

REST API バージョン `2022-11-28` を使用します。共通ライブラリ（`lib/common.sh`）がオーナータイプ判定時に `X-GitHub-Api-Version: 2022-11-28` ヘッダを自動付与します。

### パラメータ上限

| パラメータ | 現在の値 | 備考 |
|-----------|---------|------|
| `fields(first: N)` | 100 | GitHub GraphQL API の `first` パラメータ上限 |

## 使用ワークフロー

- [① GitHub Project 新規作成](../workflows/01-create-project)
- [② GitHub Project 拡張](../workflows/02-extend-project)
