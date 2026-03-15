# クイックスタート（GUI版）

GitHub の Web UI を使ったセットアップ手順です。

```mermaid
flowchart LR
    A["1. Fork"] --> B["2. PAT 作成"]
    B --> C["3. Secrets 設定"]
    C --> D["4. Actions 有効化"]
    D --> E["5. ワークフロー実行"]
```

## 1. リポジトリを fork する

本リポジトリを自分のアカウントまたは Organization に fork してください。

リポジトリページ右上の「Fork」ボタンをクリックします。

<details>
<summary>（ここをクリック）Fork ボタンのスクリーンショットを表示</summary>

> **参考画像:** リポジトリページ右上に「Fork」ボタンが表示されています。
>
> <img src="images/quickstart-fork-button.png" alt="Fork ボタンの位置" width="50%">
>
> <img src="images/quickstart-fork-page.png" alt="Fork ボタンが表示されたリポジトリページ" width="50%">

</details>

## 2. PAT を作成する

GitHub の [Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens) から `PAT` を作成します。

<details>
<summary>（ここをクリック）PAT 作成画面のスクリーンショットを表示</summary>

> **参考画像:** Settings > Developer settings > Personal access tokens 画面
>
> <img src="images/quickstart-pat.png" alt="PAT 作成画面" width="50%">

</details>

必要な権限の詳細は [認証・トークンガイド](guide/auth-tokens) を参照してください。`Fine-grained token` の制約事項については [Fine-grained token の制約事項](guide/auth-tokens#fine-grained-token-の制約事項) も合わせてご確認ください。

## 3. Secrets を設定する

fork 先リポジトリの `Settings > Secrets and variables > Actions` で以下を追加します。

<details>
<summary>（ここをクリック）Secrets 設定画面のスクリーンショットを表示</summary>

> **参考画像:** Settings > Secrets and variables > Actions 画面
>
> <img src="images/quickstart-secrets.png" alt="Secrets 設定画面" width="50%">
>
> <img src="images/quickstart-secrets-detail.png" alt="Secret 追加画面" width="50%">

</details>

| Secret 名 | 説明 |
|------------|------|
| `PROJECT_PAT` | 作成した PAT |

## 4. GitHub Actions を有効化する

フォークしたリポジトリでは `GitHub Actions` がデフォルトで無効になっています。

1. fork 先リポジトリの **Actions** タブを開く
2. 「I understand my workflows, go ahead and enable them」ボタンをクリックする

<details>
<summary>（ここをクリック）Actions 有効化画面のスクリーンショットを表示</summary>

> **参考画像:** Actions タブで「I understand my workflows, go ahead and enable them」ボタンが表示されている画面
>
> <img src="images/quickstart-enable-actions.png" alt="Actions 有効化画面" width="50%">

</details>

> **Note:** 詳しくは [トラブルシューティング > フォーク後に GitHub Actions が動かない](troubleshooting#フォーク後に-github-actions-が動かない) を参照してください。

## 5. ワークフローを実行する

fork 先リポジトリの `Actions` タブからワークフローを選択し、`Run workflow` をクリックして実行します。

<details>
<summary>（ここをクリック）ワークフロー実行画面のスクリーンショットを表示</summary>

> **参考画像:** Actions タブからワークフローを選択し Run workflow をクリックする画面
>
> <img src="images/quickstart-run-workflow.png" alt="ワークフロー実行画面" width="50%">
>
> <img src="images/quickstart-run-workflow-detail.png" alt="ワークフロー実行詳細画面" width="50%">

</details>

各ワークフローの詳細は個別ページをご参照ください。

- [① GitHub Project 新規作成](workflows/01-create-project)
- [② GitHub Project 拡張](workflows/02-extend-project)
- [③ Issue/PR 一括紐付け](workflows/03-add-items-to-project)
- [④ Project アイテム エクスポート](workflows/04-export-project-items)
