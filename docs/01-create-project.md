# ① GitHub Project 新規作成

新しい Project を作成し、カスタムフィールド・ステータスカラム・View を一括でセットアップします。

## 使い方

1. `Actions` タブを開く
2. `① GitHub Project 新規作成` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

## パラメータ

| パラメータ | 説明 | 必須 | 例 |
|------------|------|:----:|-----|
| `project_title` | Project のタイトル | ✅ | `My Project Board` |
| `visibility` | Project の公開範囲 | ✅ | `PRIVATE`（デフォルト） / `PUBLIC` |

> **Note:** Project の Owner はリポジトリの Owner から自動取得されます。
> カスタムフィールド・ステータスカラム・View の定義は各スクリプト内に固定されています。カスタマイズする場合はスクリプトを直接編集してください。

## ワークフロー構成

```
01-create-project.yml
  ├── create-project ジョブ
  │   └── scripts/setup-github-project.sh   # Project 作成
  └── extend-project ジョブ（_reusable-extend-project.yml）
      ├── scripts/setup-project-fields.sh    # カスタムフィールド作成
      ├── scripts/setup-status-columns.sh    # ステータスカラム設定
      └── scripts/create-project-views.sh    # View 作成
```

## スクリプト詳細

| スクリプト | 概要 |
|-----------|------|
| [setup-github-project.sh](scripts/setup-github-project.md) | Owner 種別を自動判定し、Project を新規作成する |
| [setup-project-fields.sh](scripts/setup-project-fields.md) | Priority・Estimate・Category・Due Date のカスタムフィールドを作成する |
| [setup-status-columns.sh](scripts/setup-status-columns.md) | Todo・In Progress・Done のステータスカラムを設定する |
| [create-project-views.sh](scripts/create-project-views.md) | Table・Board・Roadmap の 3 種類の View を作成する |
