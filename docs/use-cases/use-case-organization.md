# 🏢 Organization のための GitHub Projects 活用ガイド

チームのプロジェクト管理を `GitHub Projects` に一元化しませんか？
**GitHub Starter Kit** を使えば、統一されたプロジェクト運用をすぐに立ち上げられます。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-github-projects-%E3%81%8C-organization-%E3%81%AB%E5%90%91%E3%81%84%E3%81%A6%E3%81%84%E3%82%8B%E7%90%86%E7%94%B1">🏗️ GitHub Projects が Organization に向いている理由</a></li>

<li><a href="#-%E3%81%93%E3%81%AE%E3%83%AA%E3%83%9D%E3%82%B8%E3%83%88%E3%83%AA%E3%81%8C%E8%A7%A3%E6%B1%BA%E3%81%99%E3%82%8B%E8%AA%B2%E9%A1%8C">🛠️ このリポジトリが解決する課題</a></li>

<li><a href="#-%E3%81%93%E3%82%93%E3%81%AA%E3%83%81%E3%83%BC%E3%83%A0%E3%81%AB%E3%81%8A%E3%81%99%E3%81%99%E3%82%81">🎯 こんなチームにおすすめ</a></li>

<li><a href="#-%E3%81%AF%E3%81%98%E3%82%81%E6%96%B9">🚀 はじめ方</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 🏗️ GitHub Projects が Organization に向いている理由

### 🔗 GitHub 上で開発とプロジェクト管理を一元化できる

コードレビュー・`Issue` 管理・プロジェクト進捗の把握がすべて GitHub 上で完結します。開発チームが普段使っている環境にプロジェクト管理を統合できるため、ワークフローの切り替えコストがなくなります。

### 💰 外部ツール不要でコスト削減・学習コスト低減

外部のプロジェクト管理ツールを契約する必要がありません。GitHub を使い慣れたメンバーであれば追加の学習コストも最小限です。

### 🔀 複数リポジトリを横断した管理が可能

Organization 配下の複数リポジトリにまたがる `Issue` や `PR` を、1 つの `Project` ボードで横断的に管理できます。チーム全体の進捗を俯瞰するのに最適です。

---

## 🛠️ このリポジトリが解決する課題

### 📋 チーム全体で統一されたプロジェクト運用を始めたい

メンバーごとに Project の構成がバラバラだと、進捗の把握やレポート作成が困難になります。

**GitHub Starter Kit なら:** JSON 定義ファイルで `Field`・`Status`・`View` を標準化できます。チーム共通の構成をコードとして管理し、誰が作っても同じ構成の `Project` を構築できます。

→ [Workflow ① GitHub Project 新規作成](../workflows/01-create-project)

### ⚙️ 新規プロジェクトのたびにセットアップ工数がかかる

新しいプロジェクトを立ち上げるたびに、`Project` の作成・`Field` 定義・`View` 設定・`Label` 追加を手作業で行うのは非効率です。

**GitHub Starter Kit なら:** Workflow を実行するだけで、`Project` の作成から構成の適用まで自動化できます。セットアップ工数を大幅に削減し、プロジェクトの立ち上げを即座に完了できます。

→ [Workflow ② GitHub Project 拡張](../workflows/02-extend-project)

### 📊 滞留タスクの検知やベロシティの把握が難しい

チームの生産性を可視化するには、定期的なデータ集計とレポート作成が欠かせません。手作業での集計は時間がかかり、継続が難しくなります。

**GitHub Starter Kit なら:** 分析 Workflow で滞留タスクの自動検知、サマリーレポート・工数レポート・ベロシティレポートの生成を一括で実行できます。定期チェックの仕組みとして活用できます。

→ [Workflow ⑥ 統合 Project 分析](../workflows/06-analyze-project)

### 📦 特殊リポジトリの作成も一括対応

Organization のプロフィール README（`.github`）や `GitHub Pages` 用リポジトリなど、特殊な命名規則を持つリポジトリの作成も自動化できます。

→ [Workflow ③ 特殊 Repository 一括作成](../workflows/03-create-special-repos)

---

## 🎯 こんなチームにおすすめ

- 新規プロジェクトの立ち上げ頻度が高いチーム
- プロジェクト管理のフォーマットを統一したいチーム
- 外部ツールへの依存を減らし、GitHub に集約したいチーム
- チームの生産性を定量的に把握したいマネージャー

---

## 🚀 はじめ方

1. [このリポジトリを Fork する](https://github.com/lurest-inc/github-starter-kit/fork)
2. [クイックスタート（GUI）](../getting-started/quickstart-gui) または [クイックスタート（CLI）](../getting-started/quickstart-cli) に沿ってセットアップ
3. Workflow を実行して Project を自動構築
