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

## 処理フロー

<details>
<summary>フローチャートを表示</summary>

```mermaid
flowchart TD
    A["workflow_dispatch\n（project_number）"] --> B["extend-project ジョブ\n（_reusable-extend-project.yml）\n※ Project 作成ステップなし（既存 Project を使用）"]
    B --> C["setup-project-fields.sh\nカスタムフィールドを作成"]
    C --> D["setup-status-columns.sh\nステータスカラムを設定"]
    D --> E["create-project-views.sh\nView を作成"]
    E --> F["完了"]
```

</details>
