# ③ Issue/PR 一括紐付け

リポジトリの Issue/PR を Project に一括追加します。

## 使い方

1. `Actions` タブを開く
2. `③ Issue/PR 一括紐付け` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

## パラメータ

| パラメータ | 説明 | 必須 | 例 |
|------------|------|:----:|-----|
| `project_number` | 対象 Project の Number | ✅ | `1` |
| `target_repo` | 対象リポジトリ（owner/repo 形式） | ✅ | `myorg/myrepo` |
| `include_issues` | Issue を追加対象にする | ✅ | `true`（デフォルト） |
| `include_prs` | Pull Request を追加対象にする | ✅ | `true`（デフォルト） |
| `item_state` | 取得するアイテムの状態 | - | `open`（デフォルト） |
| `item_label` | 絞り込みラベル（指定ラベルのみ追加） | - | `bug` |

> **Note:** 既に Project に追加済みのアイテムは自動的にスキップされます。

## 処理フロー

<details>
<summary>フローチャートを表示</summary>

```mermaid
flowchart TD
    A["workflow_dispatch"] --> B["パラメータ取得"]
    B --> C{"include_issues?"}

    C -- true --> D["Issue 一覧を取得"]
    C -- false --> E{"include_prs?"}

    D --> F{"item_label 指定あり?"}
    F -- あり --> G["ラベルで絞り込み"]
    F -- なし --> H["item_state で絞り込み"]
    G --> H

    H --> I["各 Issue をループ"]
    I --> J{"Project に追加済み?"}
    J -- Yes --> K["スキップ"]
    J -- No --> L["Project に追加"]
    K --> I
    L --> I

    I -- "完了" --> E

    E -- true --> M["PR 一覧を取得"]
    E -- false --> N["サマリー出力"]

    M --> O{"item_label 指定あり?"}
    O -- あり --> P["ラベルで絞り込み"]
    O -- なし --> Q["item_state で絞り込み"]
    P --> Q

    Q --> R["各 PR をループ"]
    R --> S{"Project に追加済み?"}
    S -- Yes --> T["スキップ"]
    S -- No --> U["Project に追加"]
    T --> R
    U --> R

    R -- "完了" --> N
```

</details>
