# ① GitHub Project 新規作成

新しい Project を作成し、カスタムフィールド・ステータスカラム・View を一括でセットアップします。

## 使い方

1. `Actions` タブを開く
2. `① GitHub Project 新規作成` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

## パラメータ

| パラメータ | 説明 | 必須 | タイプ | 例 |
|------------|------|:----:|--------|-----|
| `project_title` | Project のタイトル | ✅ | `string` | `My Project Board` |
| `visibility` | Project の公開範囲 | ✅ | `choice` | `PRIVATE`（デフォルト） / `PUBLIC` |

## 処理フロー

```mermaid
flowchart TD
    A["workflow_dispatch\n（タイトル・公開範囲）"] --> B["create-project ジョブ\nProject を新規作成し project_number を出力"]
    B --> C["extend-project ジョブ\nフィールド・ステータス・View を一括セットアップ"]
    C --> D["完了\nproject_number を出力"]
```
