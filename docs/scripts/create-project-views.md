# create-project-views.sh

Project に View を自動作成するスクリプトです。
既に同名の View が存在する場合は自動的にスキップされます。

## 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |

## 作成される View

- `Table`（TABLE_LAYOUT）
- `Board`（BOARD_LAYOUT）
- `Roadmap`（ROADMAP_LAYOUT）

## 使用ワークフロー

- [① GitHub Project 新規作成](../01-create-project)
- [② GitHub Project 拡張](../02-extend-project)
