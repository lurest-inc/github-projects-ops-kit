# add-items-to-project.sh

リポジトリの Issue/PR を Project に一括追加するスクリプトです。
既に Project に追加済みのアイテムは自動的にスキップされます。

## 環境変数

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |
| `TARGET_REPO` | 対象リポジトリ（owner/repo 形式） | ✅ |
| `INCLUDE_ISSUES` | Issue を追加対象にする（`true`/`false`） | ❌（デフォルト: `true`） |
| `INCLUDE_PRS` | PR を追加対象にする（`true`/`false`） | ❌（デフォルト: `true`） |
| `ITEM_STATE` | 取得するアイテムの状態（`open`/`closed`/`all`） | ❌（デフォルト: `open`） |
| `ITEM_LABEL` | 絞り込みラベル | ❌ |

## 使用ワークフロー

- [③ Issue/PR 一括紐付け](../03-add-items-to-project)
