# 📜 setup-project-status.sh

Project の `Status Field` にカラムを設定するスクリプトです。
既存の `Status Field` に対して、定義済みのカラムを追加・更新します。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-%E7%92%B0%E5%A2%83%E5%A4%89%E6%95%B0">🔧 環境変数</a></li>

<li><a href="#-%E8%A8%AD%E5%AE%9A%E3%81%95%E3%82%8C%E3%82%8B-status-%E3%82%AB%E3%83%A9%E3%83%A0">📋 設定される Status カラム</a></li>

<li><a href="#-%E5%87%A6%E7%90%86%E3%83%95%E3%83%AD%E3%83%BC">📊 処理フロー</a></li>

<li><a href="#-%E5%87%A6%E7%90%86%E8%A9%B3%E7%B4%B0">📝 処理詳細</a></li>

<li><a href="#-api-%E3%83%AA%E3%83%95%E3%82%A1%E3%83%AC%E3%83%B3%E3%82%B9">📚 API リファレンス</a></li>

<li><a href="#-%E4%BD%BF%E7%94%A8-workflow">🔄 使用 Workflow</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 🔧 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | `Project` の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 `Project` の Number（数値） | ✅ |

## 📋 設定される Status カラム

Status カラム定義は `scripts/config/project-status-options.json` に外部化されています。
デフォルトでは以下のカラムが設定されます:

| カラム名 | カラー | 説明 | 用途 |
|---------|--------|------|------|
| Backlog | GRAY | バックログ | 優先度未確定・いつかやるタスク |
| Todo | BLUE | 着手予定 | 今スプリントで着手するタスク |
| In Progress | YELLOW | 作業中 | 現在作業中のタスク |
| In Review | ORANGE | レビュー中 | PR レビュー待ち・レビュー中のタスク |
| Done | GREEN | 完了 | 作業完了したタスク |

## 📊 処理フロー

```mermaid
flowchart TD
    A["開始"] --> B["環境変数バリデーション"]
    B --> C["オーナータイプ判定"]
    C --> D["Status定義ファイル読み込み\n（config/project-status-options.json）"]
    D --> E["GraphQL で Project ID・\nStatus Field ID を一括取得"]

    E --> F{"Status Field\nが見つかる?"}
    F -- "No" --> G["エラー終了"]
    F -- "Yes" --> H["設定するカラム定義を構築\n（Backlog, Todo, In Progress,\nIn Review, Done）"]

    H --> I["updateProjectV2Field\nで一括更新"]
    I --> J{"GraphQL エラー?"}
    J -- "Yes" --> G
    J -- "No" --> K["更新後のカラムを表示"]
    K --> L["サマリー出力"]
    L --> M["完了"]
```

## 📝 処理詳細

| ステップ | 処理内容 | 使用コマンド / API |
|---------|---------|-------------------|
| オーナータイプ判定 | `detect_owner_type` で `Organization` / `User` を判別 | `gh api users/{owner}` |
| Status 定義ファイル読み込み | `scripts/config/project-status-options.json` から Status カラム定義を読み込み | `cat` |
| `Status` Field 取得 | GraphQL クエリで `Project` ID と `Status` Field ID を一括取得し、現在のカラム一覧を表示 | `gh api graphql` — `projectV2.fields(first: 100)` |
| カラム更新 | `singleSelectOptions` に Backlog（GRAY）・ Todo（BLUE）・ In Progress（YELLOW）・ In Review（ORANGE）・ Done（GREEN）を指定して一括更新 | `gh api graphql` — `updateProjectV2Field` mutation |
| サマリー出力 | カラム構成（`Backlog → Todo → In Progress → In Review → Done`）をコンソールと `GITHUB_STEP_SUMMARY` に出力 | — |

## 📚 API リファレンス

| API / コマンド | 用途 | リファレンス |
|---------------|------|-------------|
| `ProjectV2SingleSelectField` (GraphQL) | `Status` Field 情報の取得 | [ProjectV2SingleSelectField](https://docs.github.com/en/graphql/reference/objects#projectv2singleselectfield) |
| `updateProjectV2Field` (GraphQL Mutation) | Status カラムの一括更新 | [updateProjectV2Field](https://docs.github.com/en/graphql/reference/mutations#updateprojectv2field) |

### API バージョン要件

REST API バージョン `2022-11-28` を使用します。共通ライブラリ（`lib/common.sh`）がオーナータイプ判定時に `X-GitHub-Api-Version: 2022-11-28` ヘッダを自動付与します。

### パラメータ上限

| パラメータ | 現在の値 | 備考 |
|-----------|---------|------|
| `fields(first: N)` | 100 | `Status` Field 検索用（ビルトイン＋カスタム Field を取得） |

## 🔄 使用 Workflow

- [① GitHub Project 新規作成](../workflows/01-create-project.md)
- [② GitHub Project 拡張](../workflows/02-extend-project.md)
