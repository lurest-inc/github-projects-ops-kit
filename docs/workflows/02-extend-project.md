# ② GitHub Project 拡張

既存の Project にカスタムフィールド・ステータスカラム・View を追加します。
[① GitHub Project 新規作成](01-create-project) を実行していない既存 Project 向けです。

## 使い方

1. `Actions` タブを開く
2. `② GitHub Project 拡張` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

## パラメータ

| パラメータ | 説明 | 必須 | タイプ | 例 |
|------------|------|:----:|--------|-----|
| `project_number` | 対象 Project の Number | ✅ | `string` | `1` |

## 処理フロー

```mermaid
flowchart TD
    A["workflow_dispatch\n（project_number）"] --> B["extend-project ジョブ\n既存 Project にフィールド・ステータス・View を追加"]
    B --> C["完了"]
```
