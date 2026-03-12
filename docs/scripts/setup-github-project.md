# setup-github-project.sh

GitHub Projects V2 の Project を新規作成するスクリプトです。
Owner の種別（Organization / User）を自動判定し、適切な GraphQL ミューテーションで Project を作成します。

## 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_TITLE` | 作成する Project のタイトル | ✅ |
| `PROJECT_VISIBILITY` | Project の公開範囲（`PUBLIC` / `PRIVATE`） | ❌（デフォルト: `PRIVATE`） |

## 使用ワークフロー

- [① GitHub Project 新規作成](../01-create-project.md)
