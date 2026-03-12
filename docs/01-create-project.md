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

## 処理フロー

<details>
<summary>フローチャートを表示</summary>

```mermaid
flowchart TD
    A["workflow_dispatch\n（タイトル・公開範囲）"] --> B["create-project ジョブ"]
    B --> C["setup-github-project.sh\nProject を作成"]
    C --> D["project_number を出力"]

    D --> E["extend-project ジョブ\n（_reusable-extend-project.yml）"]
    E --> F["setup-project-fields.sh\nカスタムフィールドを作成"]
    F --> G["setup-status-columns.sh\nステータスカラムを設定"]
    G --> H["create-project-views.sh\nView を作成"]
    H --> I["完了"]
```

</details>
