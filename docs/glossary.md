# 📖 用語集

本ドキュメントで使用する GitHub 関連の専門用語をまとめています。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-github-%E7%B5%84%E7%B9%94%E3%83%BB%E3%82%A2%E3%82%AB%E3%82%A6%E3%83%B3%E3%83%88%E7%94%A8%E8%AA%9E">👥 GitHub 組織・アカウント用語</a></li>

<li><a href="#-%E8%AA%8D%E8%A8%BC%E3%83%BB%E3%83%88%E3%83%BC%E3%82%AF%E3%83%B3%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E">🔑 認証・トークン関連用語</a></li>

<li><a href="#-github-projects-%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E">📋 GitHub Projects 関連用語</a></li>

<li><a href="#-github-repositories-%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E">📦 GitHub Repositories 関連用語</a></li>

<li><a href="#-github-actions-%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E">⚡ GitHub Actions 関連用語</a></li>

<li><a href="#-git-%E5%9F%BA%E6%9C%AC%E7%94%A8%E8%AA%9E">🔀 Git 基本用語</a></li>

<li><a href="#-cli-%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E">⌨️ CLI 関連用語</a></li>

<li><a href="#-%E3%81%9D%E3%81%AE%E4%BB%96%E3%81%AE%E7%94%A8%E8%AA%9E">📌 その他の用語</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 👥 GitHub 組織・アカウント用語

| 用語 | 説明 |
|------|------|
| **Organization**<br>（オーガニゼーション） | 複数の Repository やメンバーをグループとして管理するための単位。チームや企業での利用に適している |
| **owner**<br>（オーナー） | Repository や Organization の所有者。URL 内の `{owner}` 部分に対応する |
| **`owner/repo` 形式** | Repository を一意に指定する形式（例: `octocat/my-app`） |

---

## 🔑 認証・トークン関連用語

| 用語 | 説明 |
|------|------|
| **PAT** | `Personal Access Token` の略。GitHub API や Workflow から GitHub の機能にアクセスするための認証トークン |
| **`Fine-grained token`** | 必要な権限だけを細かく設定できる新しいタイプの PAT。GitHub が推奨している |
| **`Classic token`** | 従来型の PAT。Scope 単位で権限を設定する。`Fine-grained token` より権限の粒度が粗い |
| **Secrets**<br>（シークレット） | Repository に安全に保存できる暗号化された環境変数。PAT などの機密情報を Workflow から参照する際に使用する |
| **Scope**<br>（スコープ） | `Classic token` で設定する権限の範囲（例: `project`、`read:org`、`repo`） |
| **`GH_TOKEN`** | `GitHub CLI` が認証に使用する環境変数。Workflow 内で Secrets に保存した PAT を `GH_TOKEN` として渡すことで、`gh` コマンドが認証済みの状態で実行される |

---

## 📋 GitHub Projects 関連用語

| 用語 | 説明 |
|------|------|
| **`GitHub Projects`** | Issue や Pull Request をボード形式やテーブル形式で管理できるプロジェクト管理ツール。GitHub に組み込まれている |
| **Project**<br>（プロジェクト） | `GitHub Projects` で作成する管理ボード。複数の Repository の Issue/PR をまとめて管理できる |
| **`project_number`** | 各 Project に割り当てられる一意の番号。Project の URL 末尾に表示される |
| **View**<br>（ビュー） | Project 内のアイテム一覧の表示方法。`Table`（テーブル）、`Board`（ボード）、`Roadmap`（ロードマップ）の 3 種類がある |
| **Board View**<br>（ボードビュー） | カンバン形式でアイテムをステータスごとに列で表示する View 。 |
| **Table View**<br>（テーブルビュー） | スプレッドシートのように行と列でアイテムを表示する View 。 |
| **Roadmap View**<br>（ロードマップビュー） | 時間軸に沿ってアイテムをガントチャート風に表示する View 。 |
| **Field**<br>（フィールド） | Project のアイテムに追加できる属性（カスタムフィールド）。日付・数値・選択肢などの型がある。 |
| **Status**<br>（ステータス） | アイテムの進捗状態を示す Field 。本キットでは `Backlog` → `Todo` → `In Progress` → `In Review` → `Done` の 5 段階 |
| **Item**<br>（アイテム） | Project に追加された Issue や Pull Request のこと |
| **DraftIssue**<br>（ドラフトイシュー） | Project 内で作成できる下書き状態の Issue 。Repository には紐付かず、Project 内でのみ管理される。分析 Workflow では集計対象から除外される。 |

---

## 📦 GitHub Repositories 関連用語

| 用語 | 説明 |
|------|------|
| **`GitHub Repositories`** | GitHub が提供するソースコードホスティングサービス。Repository の作成・管理・共有を行うための基盤 |
| **Repository**<br>（リポジトリ） | ソースコードやファイルを管理する保管場所。Project ごとに最低1つ以上作成するのが一般的 |
| **Issue**<br>（イシュー） | バグ報告・機能要望・タスクなどを記録するチケット。Repository 単位で管理される |
| **Pull Request**<br>（プルリクエスト / PR） | コードの変更をレビュー・マージするための仕組み。変更内容を他のメンバーに確認してもらう際に使用する |
| **Fork**<br>（フォーク） | 他の Repository を自分のアカウントにコピーすること。コピー先で自由に変更を加えられる |
| **Label**<br>（ラベル） | Issue や Pull Request に付与する分類タグ。優先度・種別・ステータスなどの分類に使用する |
| **Milestone**<br>（マイルストーン） | Issue や Pull Request をグループ化して進捗を追跡する仕組み。リリース計画などの管理に使用する |
| **GitHub Release**<br>（リリース） | Repository の特定時点のスナップショットを公開する仕組み。Tag と紐付けてリリースノートやバイナリを配布できる。 |
| **Upstream Repository**<br>（アップストリーム） | Fork 元のオリジナル Repository。Fork 先から変更を取り込む際の参照元となる。 |
| **`GitHub Pages`** | Repository から直接静的な Web サイトを公開できる GitHub のホスティングサービス。ドキュメントやプロジェクトサイトの公開に使用する。 |

---

## ⚡ GitHub Actions 関連用語

| 用語 | 説明 |
|------|------|
| **`GitHub Actions`** | GitHub に組み込まれた CI/CD（自動化）プラットフォーム。Workflow を定義して自動実行できる |
| **Workflow**<br>（ワークフロー） | `GitHub Actions` で実行される自動化処理の定義。YAML ファイルで記述する |
| **`workflow_dispatch`** | Workflow を手動で実行するためのトリガー。`Actions` タブから「Run workflow」ボタンで起動する |
| **Job**<br>（ジョブ） | Workflow 内の実行単位。1 つの Workflow に複数の Job を定義できる |
| **Step**<br>（ステップ） | Job 内で順番に実行される個々の処理単位。シェルコマンドの実行や Action の呼び出しを行う |
| **Artifact**<br>（アーティファクト） | Workflow の実行結果として出力されるファイル。エクスポートしたデータのダウンロードなどに使用する |
| **Reusable Workflow**<br>（再利用可能ワークフロー） | `workflow_call` トリガーを使用して他の Workflow から呼び出せる Workflow。本キットでは `_reusable-*.yml` ファイルとして定義されている。 |
| **`Actions` タブ** | Repository ページ上部にあるタブ。Workflow の実行・監視・管理を行う画面 |

---

## 🔀 Git 基本用語

| 用語 | 説明 |
|------|------|
| **Clone**<br>（クローン） | リモートリポジトリをローカル環境にコピーすること。作業を開始する際の最初のステップ |
| **Branch**<br>（ブランチ） | リポジトリ内でコードの変更を分離して管理する仕組み。メインのコードに影響を与えずに作業できる |
| **Pull**<br>（プル） | リモートリポジトリの変更をローカルリポジトリに取得・統合すること |
| **Commit**<br>（コミット） | ファイルの変更履歴を記録すること。変更内容にメッセージを添えて保存する |
| **Push**<br>（プッシュ） | ローカルリポジトリの変更をリモートリポジトリに送信すること |
| **Merge**<br>（マージ） | ブランチの変更をメインのコードに統合すること |
| **Tag**<br>（タグ） | 特定のコミットに名前を付けて記録する仕組み。リリースバージョンの管理などに使用する |

---

## ⌨️ CLI 関連用語

| 用語 | 説明 |
|------|------|
| **CLI** | `Command Line Interface` の略。ターミナル（コマンドライン）から操作するインターフェース |
| **`GitHub CLI` (`gh`)** | GitHub 公式のコマンドラインツール。ターミナルから GitHub の操作を実行できる |
| **`GraphQL API`** | GitHub が提供する高度なデータ取得 API。`GitHub Projects` の操作に使用される |

---

## 📌 その他の用語

| 用語 | 説明 |
|------|------|
| **カンバン** | タスクをステータスごとの列に分けて管理する手法。`GitHub Projects` の `Board View` で実現できる |
| **`visibility`**<br>（公開範囲） | Project やリポジトリの公開設定。`PRIVATE`（非公開）または `PUBLIC`（公開）を選択できる |
| **`MIT` ライセンス** | オープンソースソフトウェアで広く使用される許容的なライセンス。商用利用・改変・再配布が自由に行える。本キットもこのライセンスを採用している |
