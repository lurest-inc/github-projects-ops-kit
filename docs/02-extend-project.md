# ② GitHub Project 拡張

既存の Project にカスタムフィールド・ステータスカラム・View を追加します。
[① GitHub Project 新規作成](01-create-project) を実行していない既存 Project 向けです。

## 使い方

1. `Actions` タブを開く
2. `② GitHub Project 拡張` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

## パラメータ

| パラメータ | 説明 | 必須 | 例 |
|------------|------|:----:|-----|
| `project_number` | 対象 Project の Number | ✅ | `1` |

## ワークフロー構成

```
02-extend-project.yml
  └── extend-project ジョブ（_reusable-extend-project.yml）
      ├── scripts/setup-project-fields.sh    # カスタムフィールド作成
      ├── scripts/setup-status-columns.sh    # ステータスカラム設定
      └── scripts/create-project-views.sh    # View 作成
```

## スクリプト詳細

| スクリプト | 概要 |
|-----------|------|
| [setup-project-fields.sh](scripts/setup-project-fields) | Priority・Estimate・Category・Due Date のカスタムフィールドを作成する |
| [setup-status-columns.sh](scripts/setup-status-columns) | Todo・In Progress・Done のステータスカラムを設定する |
| [create-project-views.sh](scripts/create-project-views) | Table・Board・Roadmap の 3 種類の View を作成する |
