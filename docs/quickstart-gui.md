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
<summary>Fork ボタンのスクリーンショットを表示（ここをクリック→）</summary>

> **参考画像:** リポジトリページ右上に「Fork」ボタンが表示されています。
>
> <img src="images/quickstart-fork-button.png" alt="Fork ボタンの位置" width="30%">
>
> <img src="images/quickstart-fork-page.png" alt="Fork ボタンが表示されたリポジトリページ" width="80%">

</details>

## 2. PAT を作成する

GitHub の [Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens) から PAT を作成します。

<details>
<summary>PAT 作成画面のスクリーンショットを表示（ここをクリック→）</summary>

> **参考画像:** Settings > Developer settings > Personal access tokens 画面
>
> <img src="images/quickstart-pat.png" alt="PAT 作成画面" width="80%">

</details>

必要な権限の詳細は [FAQ > Q1. PAT にはどの権限が必要ですか？](faq#q1-pat-にはどの権限が必要ですか) を参照してください。Fine-grained token の制約事項については [Q3](faq#q3-fine-grained-token-の制約事項はありますか) も合わせてご確認ください。

## 3. Secrets を設定する

fork 先リポジトリの `Settings > Secrets and variables > Actions` で以下を追加します。

<!-- TODO: Secrets 設定画面のスクリーンショットを追加 (quickstart-secrets.png) -->

| Secret 名 | 説明 |
|------------|------|
| `PROJECT_PAT` | 作成した PAT |

## 4. GitHub Actions を有効化する

フォークしたリポジトリでは GitHub Actions がデフォルトで無効になっています。

1. fork 先リポジトリの **Actions** タブを開く
2. 「I understand my workflows, go ahead and enable them」ボタンをクリックする

<!-- TODO: Actions 有効化画面のスクリーンショットを追加 (quickstart-enable-actions.png) -->

> **Note:** 詳しくは [FAQ > Q4. フォーク後に GitHub Actions が動きません](faq#q4-フォーク後に-github-actions-が動きません) を参照してください。

## 5. ワークフローを実行する

fork 先リポジトリの `Actions` タブからワークフローを選択し、`Run workflow` をクリックして実行します。

<!-- TODO: ワークフロー実行画面のスクリーンショットを追加 (quickstart-run-workflow.png) -->

各ワークフローの詳細は個別ページをご参照ください。

- [① GitHub Project 新規作成](workflows/01-create-project)
- [② GitHub Project 拡張](workflows/02-extend-project)
- [③ Issue/PR 一括紐付け](workflows/03-add-items-to-project)
- [④ Project アイテム エクスポート](workflows/04-export-project-items)
