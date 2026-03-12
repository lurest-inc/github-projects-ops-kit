# setup-status-columns.sh

Project の Status フィールドにカラムを設定するスクリプトです。
既存の Status フィールドに対して、定義済みのカラムを追加・更新します。

## 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |

## 設定されるステータスカラム

| カラム名 | カラー | 説明 |
|---------|--------|------|
| Todo | BLUE | 未着手 |
| In Progress | YELLOW | 作業中 |
| Done | GREEN | 完了 |

## 使用ワークフロー

- [① GitHub Project 新規作成](../01-create-project)
- [② GitHub Project 拡張](../02-extend-project)
