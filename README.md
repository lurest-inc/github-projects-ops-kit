# github-projects-starter-kit

GitHub Projects Starter Kit

## 概要

GitHub Projects の初期セットアップを GitHub Actions で自動実行するためのスターターキットです。
本リポジトリを fork し、GitHub Actions を手動実行することで、GitHub Project を作成できます。

## セットアップ手順

### 1. リポジトリを fork する

本リポジトリを自分のアカウントまたは Organization に fork してください。

### 2. Personal Access Token (PAT) を作成する

GitHub の [Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens) から PAT を作成してください。

#### 必要な権限

- **Fine-grained token** の場合:
  - `Organization permissions` > `Projects` > `Read and write`（Organization の場合）
  - `Account permissions` > `Projects` > `Read and write`（個人の場合）

- **Classic token** の場合:
  - `project` スコープ

### 3. Secrets を設定する

fork したリポジトリの `Settings > Secrets and variables > Actions` で以下の Secret を追加してください。

| Secret 名 | 説明 |
|------------|------|
| `PROJECT_PAT` | 上記で作成した PAT |

### 4. GitHub Actions を実行する

1. リポジトリの `Actions` タブを開く
2. 左メニューから `Setup GitHub Project` を選択
3. `Run workflow` をクリック
4. 以下のパラメータを入力して実行

| パラメータ | 説明 | 例 |
|------------|------|-----|
| `project_title` | Project のタイトル | `My Project Board` |

> **Note:** Project の Owner はリポジトリの Owner（個人アカウントまたは Organization）から自動取得されます。

## Issue/PR を Project に一括追加する

既存のリポジトリにある Issue や Pull Request を GitHub Project に一括で追加できます。

1. リポジトリの `Actions` タブを開く
2. 左メニューから `Add Items to Project` を選択
3. `Run workflow` をクリック
4. 以下のパラメータを入力して実行

| パラメータ | 説明 | 必須 | 例 |
|------------|------|:----:|-----|
| `project_number` | 対象 Project の Number | ✅ | `1` |
| `target_repo` | 対象リポジトリ（owner/repo 形式） | ✅ | `myorg/myrepo` |
| `include_issues` | Issue を追加対象にする | ✅ | `true`（デフォルト） |
| `include_prs` | Pull Request を追加対象にする | ✅ | `true`（デフォルト） |
| `item_state` | 取得するアイテムの状態 | - | `open`（デフォルト） |
| `item_label` | 絞り込みラベル（指定ラベルのみ追加） | - | `bug` |

> **Note:** 既に Project に追加済みのアイテムは自動的にスキップされます。

## ライセンス

[MIT License](LICENSE)
