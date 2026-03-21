# 🧑‍💻 個人開発者のための GitHub Projects 活用ガイド

個人開発や OSS メンテナンスに `GitHub Projects` を活用しませんか？
**GitHub Starter Kit** を使えば、プロジェクト管理の面倒なセットアップを Workflow 実行だけで完了できます。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-github-projects-%E3%81%8C%E5%80%8B%E4%BA%BA%E9%96%8B%E7%99%BA%E3%81%AB%E5%90%91%E3%81%84%E3%81%A6%E3%81%84%E3%82%8B%E7%90%86%E7%94%B1">🏗️ GitHub Projects が個人開発に向いている理由</a></li>

<li><a href="#-%E3%81%93%E3%81%AE%E3%83%AA%E3%83%9D%E3%82%B8%E3%83%88%E3%83%AA%E3%81%8C%E8%A7%A3%E6%B1%BA%E3%81%99%E3%82%8B%E8%AA%B2%E9%A1%8C">🛠️ このリポジトリが解決する課題</a></li>

<li><a href="#-%E3%81%93%E3%82%93%E3%81%AA%E6%96%B9%E3%81%AB%E3%81%8A%E3%81%99%E3%81%99%E3%82%81">🎯 こんな方におすすめ</a></li>

<li><a href="#-%E3%81%AF%E3%81%98%E3%82%81%E6%96%B9">🚀 はじめ方</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 🏗️ GitHub Projects が個人開発に向いている理由

### 💰 無料で使えるプロジェクト管理ツール

GitHub アカウントがあればすぐに使えます。外部ツールの契約や追加コストは不要です。

### 🔗 `Issue`/`PR` と直結しているためツール間の切り替えが不要

タスク管理と開発作業が同じ GitHub 上で完結します。`Issue` を作成すれば、そのまま `Project` のボードに反映されるため、別のツールを開く必要がありません。

### 🎨 カスタムフィールド・ビューで自分好みに管理できる

`Table`・`Board`・`Roadmap` の 3 種類のビューを切り替えられます。カスタムフィールドを追加すれば、優先度や見積もり工数など自分に必要な情報を自由に管理できます。

---

## 🛠️ このリポジトリが解決する課題

### ⚙️ Project の初期セットアップが面倒

GitHub Projects を新しく作るたびに、`Field`・`Status`・`View` を手作業で設定するのは手間がかかります。

**GitHub Starter Kit なら:** Workflow を 1 回実行するだけで、`Project` の作成から `Field`・`Status`・`View` の設定までが自動で完了します。

→ [Workflow ① GitHub Project 新規作成](../workflows/01-create-project)

### 📋 `Field`・`Status`・`View` を毎回手作業で作るのが大変

複数の個人プロジェクトを管理していると、同じ構成を何度も手作業で再現する必要があります。

**GitHub Starter Kit なら:** JSON 定義ファイルに構成を書いておけば、何度でも同じ構成を一括で構築できます。定義ファイルをカスタマイズすれば、自分専用のテンプレートとして使い回せます。

→ [Workflow ② GitHub Project 拡張](../workflows/02-extend-project)

### 📊 個人開発の進捗を可視化したい

「今どれくらい進んでいるか」「滞留しているタスクはないか」を把握するのは、個人開発でも重要です。

**GitHub Starter Kit なら:** レポート生成 Workflow で `Status` 別・担当者別の集計や、滞留タスクの検知が簡単にできます。振り返りや計画の見直しに活用できます。

→ [Workflow ⑥ 統合 Project 分析](../workflows/06-analyze-project)

---

## 🎯 こんな方におすすめ

- 個人開発で複数リポジトリの `Issue` を一元管理したい方
- OSS プロジェクトの `Issue`/`PR` を効率的にトラッキングしたい方
- プロジェクト管理ツールに費用をかけたくない方
- GitHub だけで開発フローを完結させたい方

---

## 🚀 はじめ方

1. [このリポジトリを Fork する](https://github.com/lurest-inc/github-starter-kit/fork)
2. [クイックスタート（GUI）](../getting-started/quickstart-gui) または [クイックスタート（CLI）](../getting-started/quickstart-cli) に沿ってセットアップ
3. Workflow を実行して Project を自動構築
