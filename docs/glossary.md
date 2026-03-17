# 📖 用語集

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [🔀 Git 基本用語](#-git-%E5%9F%BA%E6%9C%AC%E7%94%A8%E8%AA%9E)
- [📦 GitHub Repository 関連用語](#-github-repository-%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E)
- [👥 GitHub 組織・アカウント用語](#-github-%E7%B5%84%E7%B9%94%E3%83%BB%E3%82%A2%E3%82%AB%E3%82%A6%E3%83%B3%E3%83%88%E7%94%A8%E8%AA%9E)
- [📋 GitHub Projects 関連用語](#-github-projects-%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E)
- [🔑 認証・トークン関連用語](#-%E8%AA%8D%E8%A8%BC%E3%83%BB%E3%83%88%E3%83%BC%E3%82%AF%E3%83%B3%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E)
- [⚡ GitHub Actions 関連用語](#-github-actions-%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E)
- [⌨️ CLI 関連用語](#-cli-%E9%96%A2%E9%80%A3%E7%94%A8%E8%AA%9E)
- [📌 その他の用語](#-%E3%81%9D%E3%81%AE%E4%BB%96%E3%81%AE%E7%94%A8%E8%AA%9E)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

本ドキュメントで使用する GitHub 関連の専門用語をまとめています。

---

## 🔀 Git 基本用語

| 用語 | 説明 |
|------|------|
| **Clone（クローン）** | リモートリポジトリをローカル環境にコピーすること。作業を開始する際の最初のステップ |
| **Commit（コミット）** | ファイルの変更履歴を記録すること。変更内容にメッセージを添えて保存する |
| **Branch（ブランチ）** | リポジトリ内でコードの変更を分離して管理する仕組み。メインのコードに影響を与えずに作業できる |
| **Merge（マージ）** | ブランチの変更をメインのコードに統合すること |
| **Push（プッシュ）** | ローカルリポジトリの変更をリモートリポジトリに送信すること |
| **Pull（プル）** | リモートリポジトリの変更をローカルリポジトリに取得・統合すること |
| **Tag（タグ）** | 特定のコミットに名前を付けて記録する仕組み。リリースバージョンの管理などに使用する |

---

## 📦 GitHub Repository 関連用語

| 用語 | 説明 |
|------|------|
| **Repository（リポジトリ）** | ソースコードやファイルを管理する保管場所。プロジェクトごとに 1 つ作成するのが一般的 |
| **Issue（イシュー）** | バグ報告・機能要望・タスクなどを記録するチケット。リポジトリ単位で管理される |
| **Pull Request（プルリクエスト / PR）** | コードの変更をレビュー・マージするための仕組み。変更内容を他のメンバーに確認してもらう際に使用する |
| **Fork（フォーク）** | 他のリポジトリを自分のアカウントにコピーすること。コピー先で自由に変更を加えられる |
| **Label（ラベル）** | Issue や Pull Request に付与する分類タグ。優先度・種別・ステータスなどの分類に使用する |
| **Milestone（マイルストーン）** | Issue や Pull Request をグループ化して進捗を追跡する仕組み。リリース計画などの管理に使用する |

---

## 👥 GitHub 組織・アカウント用語

| 用語 | 説明 |
|------|------|
| **Organization（オーガニゼーション）** | 複数のリポジトリやメンバーをグループとして管理するための単位。チームや企業での利用に適している |
| **owner（オーナー）** | リポジトリや Organization の所有者。URL 内の `{owner}` 部分に対応する |
| **`owner/repo` 形式** | リポジトリを一意に指定する形式（例: `octocat/my-app`） |

---

## 📋 GitHub Projects 関連用語

| 用語 | 説明 |
|------|------|
| **GitHub Projects** | Issue や Pull Request をボード形式やテーブル形式で管理できるプロジェクト管理ツール。GitHub に組み込まれている |
| **Project（プロジェクト）** | GitHub Projects で作成する管理ボード。複数のリポジトリの Issue/PR をまとめて管理できる |
| **Project Number** | 各 Project に割り当てられる一意の番号。Project の URL 末尾に表示される |
| **View（ビュー）** | Project 内のアイテム一覧の表示方法。`Table`（テーブル）、`Board`（ボード）、`Roadmap`（ロードマップ）の 3 種類がある |
| **Board View（ボードビュー）** | カンバン形式でアイテムをステータスごとに列で表示する View |
| **Table View（テーブルビュー）** | スプレッドシートのように行と列でアイテムを表示する View |
| **Roadmap View（ロードマップビュー）** | 時間軸に沿ってアイテムをガントチャート風に表示する View |
| **Field（フィールド）** | Project のアイテムに追加できる属性（カスタムフィールド）。日付・数値・選択肢などの型がある |
| **Status（ステータス）** | アイテムの進捗状態を示すフィールド。本キットでは `Backlog` → `Todo` → `In Progress` → `In Review` → `Done` の 5 段階 |
| **Item（アイテム）** | Project に追加された Issue や Pull Request のこと |

---

## 🔑 認証・トークン関連用語

| 用語 | 説明 |
|------|------|
| **PAT（Personal Access Token）** | GitHub API やワークフローから GitHub の機能にアクセスするための認証トークン |
| **Fine-grained token** | 必要な権限だけを細かく設定できる新しいタイプの PAT。GitHub が推奨している |
| **Classic token** | 従来型の PAT。スコープ単位で権限を設定する。Fine-grained token より権限の粒度が粗い |
| **Secrets（シークレット）** | リポジトリに安全に保存できる暗号化された環境変数。PAT などの機密情報をワークフローから参照する際に使用する |
| **Scope（スコープ）** | Classic token で設定する権限の範囲（例: `project`、`read:org`、`repo`） |

---

## ⚡ GitHub Actions 関連用語

| 用語 | 説明 |
|------|------|
| **GitHub Actions** | GitHub に組み込まれた CI/CD（自動化）プラットフォーム。ワークフローを定義して自動実行できる |
| **Workflow（ワークフロー）** | GitHub Actions で実行される自動化処理の定義。YAML ファイルで記述する |
| **workflow_dispatch** | ワークフローを手動で実行するためのトリガー。Actions タブから「Run workflow」ボタンで起動する |
| **Job（ジョブ）** | ワークフロー内の実行単位。1 つのワークフローに複数のジョブを定義できる |
| **Artifact（アーティファクト）** | ワークフローの実行結果として出力されるファイル。エクスポートしたデータのダウンロードなどに使用する |
| **Actions タブ** | リポジトリページ上部にあるタブ。ワークフローの実行・監視・管理を行う画面 |

---

## ⌨️ CLI 関連用語

| 用語 | 説明 |
|------|------|
| **CLI（Command Line Interface）** | ターミナル（コマンドライン）から操作するインターフェース |
| **GitHub CLI (`gh`)** | GitHub 公式のコマンドラインツール。ターミナルから GitHub の操作を実行できる |
| **GraphQL API** | GitHub が提供する高度なデータ取得 API。GitHub Projects の操作に使用される |

---

## 📌 その他の用語

| 用語 | 説明 |
|------|------|
| **カンバン** | タスクをステータスごとの列に分けて管理する手法。GitHub Projects の Board View で実現できる |
| **Visibility（公開範囲）** | Project やリポジトリの公開設定。`PRIVATE`（非公開）または `PUBLIC`（公開）を選択できる |
