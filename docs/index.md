# GitHub Projects Starter Kit ドキュメント

GitHub Projects の初期セットアップを GitHub Actions で自動実行するための **スターターキット** です。

## ワークフロー一覧

| ワークフロー | 説明 | トリガー |
|------------|------|---------|
| Setup GitHub Project | GitHub Project を1件作成する | `workflow_dispatch`（手動実行） |
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

> **Note:** Project の Owner はリポジトリの Owner から自動取得されます。

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
  └── add-items-to-project.yml    # アイテム一括追加ワークフロー
scripts/
  ├── setup-github-project.sh     # Project 作成スクリプト
  └── add-items-to-project.sh     # アイテム一括追加スクリプト
```

## リポジトリ

- GitHub: [mabubu0203/github-projects-starter-kit](https://github.com/mabubu0203/github-projects-starter-kit)
