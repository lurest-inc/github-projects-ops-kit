# GitHub Projects Starter Kit ドキュメント

GitHub Projects の初期セットアップを GitHub Actions で自動実行するための **スターターキット** です。

## ワークフロー一覧

| ワークフロー | 説明 | トリガー |
|------------|------|---------|
| Setup GitHub Project | GitHub Project を1件作成する | `workflow_dispatch`（手動実行） |
| ~~Setup Status Columns~~ | ~~Project の Status カラムをテンプレートで設定する~~ | スクリプト直接実行 |
| Add Items to Project | リポジトリの Issue/PR を Project に一括追加する | `workflow_dispatch`（手動実行） |

## クイックスタート

### 1. リポジトリを fork する

本リポジトリを自分のアカウントまたは Organization に fork してください。

### 2. PAT を作成する

GitHub の [Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens) から PAT を作成します。

**Fine-grained token の場合:**

- `Organization permissions` > `Projects` > `Read and write`（Organization）
- `Account permissions` > `Projects` > `Read and write`（個人）

**Classic token の場合:**

- `project` スコープ

### 3. Secrets を設定する

fork 先リポジトリの `Settings > Secrets and variables > Actions` で以下を追加します。

| Secret 名 | 説明 |
|------------|------|
| `PROJECT_PAT` | 作成した PAT |

### 4. ワークフローを実行する

1. `Actions` タブを開く
2. `Setup GitHub Project` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

| パラメータ | 説明 | 例 |
|------------|------|-----|
| `project_title` | Project のタイトル | `My Project Board` |
| `visibility` | Project の公開範囲 | `PRIVATE`（デフォルト） / `PUBLIC` |

> **Note:** Project の Owner はリポジトリの Owner から自動取得されます。

### Status カラムを設定する

スクリプト `scripts/setup-status-columns.sh` を直接実行して、Project の Status カラムを任意の構成に設定できます。

```bash
export GH_TOKEN="your-pat"
export PROJECT_OWNER="your-owner"
export PROJECT_NUMBER="1"
export STATUS_OPTIONS='[
  {"name": "Todo", "color": "BLUE", "description": "未着手のアイテム"},
  {"name": "In Progress", "color": "YELLOW", "description": "作業中のアイテム"},
  {"name": "Done", "color": "GREEN", "description": "完了したアイテム"}
]'
bash scripts/setup-status-columns.sh
```

| 環境変数 | 説明 | 必須 |
|----------|------|:----:|
| `GH_TOKEN` | GitHub PAT（Projects 操作権限が必要） | ✅ |
| `PROJECT_OWNER` | Project の所有者 | ✅ |
| `PROJECT_NUMBER` | 対象 Project の Number（数値） | ✅ |
| `STATUS_OPTIONS` | ステータスカラム定義（JSON 配列） | ✅ |

**対応カラー:** `GRAY`, `BLUE`, `GREEN`, `YELLOW`, `ORANGE`, `RED`, `PINK`, `PURPLE`

> **Note:** ビルトインの Status フィールドのカラムを上書きします。GraphQL API を使用するため、PAT に Projects の Read and write 権限が必要です。

### Issue/PR を Project に一括追加する

1. `Actions` タブを開く
2. `Add Items to Project` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

| パラメータ | 説明 | 必須 | 例 |
|------------|------|:----:|-----|
| `project_number` | 対象 Project の Number | ✅ | `1` |
| `target_repo` | 対象リポジトリ（owner/repo 形式） | ✅ | `myorg/myrepo` |
| `include_issues` | Issue を追加対象にする | ✅ | `true`（デフォルト） |
| `include_prs` | Pull Request を追加対象にする | ✅ | `true`（デフォルト） |
| `item_state` | 取得するアイテムの状態 | - | `open`（デフォルト） |
| `item_label` | 絞り込みラベル（指定ラベルのみ追加） | - | `bug` |

> **Note:** 既に Project に追加済みのアイテムは自動的にスキップされます。

## 構成ファイル

```
.github/workflows/
  ├── setup-github-project.yml    # Project 作成ワークフロー
  │                                 # (setup-status-columns.yml は廃止)
  └── add-items-to-project.yml    # アイテム一括追加ワークフロー
scripts/
  ├── setup-github-project.sh     # Project 作成スクリプト
  ├── setup-status-columns.sh     # ステータスカラム設定スクリプト
  └── add-items-to-project.sh     # アイテム一括追加スクリプト
```

## リポジトリ

- GitHub: [mabubu0203/github-projects-starter-kit](https://github.com/mabubu0203/github-projects-starter-kit)
