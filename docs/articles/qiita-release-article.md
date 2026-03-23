---
title: "[個人開発] GitHub Projects の初期構築・運用分析を自動化するツールキットをリリースしました"
tags: 個人開発, GitHub, GitHubActions, GitHubProjects, Bash
---

# はじめに🐱

GitHub Projects、使っていますか？

個人開発でも業務でも、Issue や PR をカンバンボードで管理できる `GitHub Projects` は非常に便利です。
ただ、新しいプロジェクトを立ち上げるたびに **Field・Status・View を手作業でポチポチ設定する**のは正直面倒ですよね。

しかも複数プロジェクトを運用していると、構成がバラバラになったり、進捗の可視化が追いつかなかったり。
「**GitHub だけで完結する、もっとラクなプロジェクト管理**」を目指して、ツールキットを作りました。

# リリースしたツールキットについて🏠

| | |
|---|---|
| リポジトリ | https://github.com/lurest-inc/github-starter-kit |
| ドキュメント | https://lurest-inc.github.io/github-starter-kit/ |
| バージョン | v1.1.2 |
| ライセンス | MIT |
| 主要言語 | Bash |
| 依存ツール | GitHub CLI (`gh`)、`jq` |

**GitHub Projects Ops Kit** は、`GitHub Projects` の初期構築から運用分析までを `GitHub Actions` で半自動実行するための運用キットです。
本リポジトリを **Fork** し、Workflow を手動実行するだけで、Project の作成から分析までを一気通貫して行えます。

# 宣伝🎟️

こんな方にぜひ使っていただきたいです。

- **個人開発者**: 複数リポジトリの Issue を一元管理したい方、プロジェクト管理ツールに費用をかけたくない方
- **チームリーダー / マネージャー**: プロジェクトの構成を統一したい方、生産性を定量的に可視化したい方
- **OSS メンテナー**: Issue/PR を効率的にトラッキングしたい方

**Fork するだけ**で使い始められます。GitHub アカウントがあれば追加コストはゼロです。
⭐ をいただけると開発のモチベーションになります！

# ツールキット作成の経緯

### GitHub Projects の「手作業の壁」

GitHub Projects は非常に優秀なツールですが、初期セットアップに関しては **API か手作業でしか構築できない** という現実があります。

新しいプロジェクトを立ち上げるたびに、こんな手作業が発生していました。

- カスタムフィールド（見積もり工数、開始予定、終了予定...）を1つずつ追加
- ステータスオプション（Backlog → Todo → In Progress → In Review → Done）を定義
- ビュー（Table / Board / Roadmap）を作成してフィルタを設定
- Issue ラベルを定義
- Issue/PR を Project に紐付け

これを **プロジェクトを立ち上げるたびに毎回やる** のはしんどいです。
さらに、複数プロジェクトを運用していると構成がバラバラになりがちで、横断的な管理が難しくなります。

### 「コードとしてのプロジェクト構成」という発想

そこで、**プロジェクト構成を JSON 定義ファイルで管理し、GitHub Actions で自動構築する** という仕組みを作りました。

一度定義を書いておけば、何度でも同じ構成を再現できます。
チーム全体で構成を統一したい場合も、定義ファイルを共有するだけで済みます。

# どんな課題を解決するのか？🔧

GitHub Projects を本格運用しようとすると、ざっくりと下記のような作業が必要になります。

1. **Project の初期構築**: Field・Status・View の設定
2. **Repository の整備**: Issue Label の定義、特殊 Repository の作成
3. **Item の管理**: Issue/PR の Project への紐付け
4. **運用分析**: 滞留タスクの検知、進捗レポートの生成、工数の集計

学校では教えてくれません。（GitHub Projects の運用ノウハウは意外と情報が少ないです）

**GitHub Projects Ops Kit** は、上記 1〜4 のすべてを **6 つの Workflow** で自動化します。

# 機能紹介💡

6 つの Workflow で、セットアップから分析まで一気通貫で実行できます。

<details>
<summary>① GitHub Project 新規作成</summary>

- Project を新規作成し、Field・Status・View を一括セットアップ
- 個人アカウント・Organization の両方に対応
- JSON 定義ファイルに基づいて構成を自動適用
- 作成後、② の拡張 Workflow を自動呼び出し
</details>

<details>
<summary>② GitHub Project 拡張</summary>

- 既存の Project に Field・Status・View を追加
- 再利用可能 Workflow（`_reusable-extend-project.yml`）として設計
- ① からの自動呼び出しにも、単体実行にも対応
</details>

<details>
<summary>③ 特殊 Repository 一括作成</summary>

GitHub には特殊な命名規則を持つ Repository があります。

**個人アカウント向け:**
- `<ユーザー名>` ... プロフィール README
- `<ユーザー名>.github.io` ... GitHub Pages
- `dotfiles` ... Codespaces パーソナライズ

**Organization 向け:**
- `.github` ... パブリックプロフィール・Community Health Files
- `.github-private` ... メンバー限定プロフィール
- `<Organization名>.github.io` ... GitHub Pages

これらを **1 回の Workflow 実行で一括作成** できます。
</details>

<details>
<summary>④ Issue Label 一括追加</summary>

- 指定 Repository に 13 種類の Issue Label を一括作成
- 種別（bug, enhancement, documentation...）、状態（on-hold, blocked...）、優先度（priority: high/low）をカバー
- JSON 定義ファイルでカスタマイズ可能
</details>

<details>
<summary>⑤ Issue/PR 一括紐付け</summary>

- Repository の Issue や PR を Project に一括追加
- **種別フィルタ**: Issue のみ / PR のみ / すべて
- **状態フィルタ**: open / closed / all
- **ラベルフィルタ**: 特定ラベルが付いた Item のみ
- 重複追加の自動回避機能付き
</details>

<details>
<summary>⑥ 統合 Project 分析</summary>

5 種類の分析・レポートを一括生成できます。

| レポート | 内容 |
|---|---|
| **サマリーレポート** | Status 別・担当者別・Label 別の集計 |
| **工数レポート** | 見積もり・実績の集計と乖離分析 |
| **ベロシティレポート** | 直近 8 週間の完了 Item 推移（トレンド分析） |
| **滞留 Item 検知** | Status 別の閾値ベースで自動判定 |
| **Item エクスポート** | JSON・Markdown・CSV・TSV の 4 形式 |

生成したレポートは **GitHub Actions の Artifact** としてダウンロード可能です。
</details>

# 使用した技術💻

## 全般

| 名称 | 用途 |
|---|---|
| GitHub | コード管理・CI/CD 基盤 |
| GitHub Actions | Workflow の実行環境（ubuntu-latest） |
| GitHub CLI (`gh`) | GitHub API の操作 |
| GitHub GraphQL API | Project V2 の操作に利用 |
| GitHub Pages | ドキュメントサイトのホスティング |

## スクリプト

| 名称 | 用途 |
|---|---|
| Bash | 全スクリプトの実装言語 |
| jq | JSON の解析・加工 |
| doctoc | Markdown の目次自動生成 |
| release-please | Conventional Commits ベースの自動バージョニング |

## セキュリティ

| 対策 | 内容 |
|---|---|
| PAT 認証 | Fine-grained / Classic の両方に対応 |
| Workflow Command Injection 対策 | `sanitize_for_workflow_command()` による入力サニタイズ |
| 入力バリデーション | PROJECT_NUMBER・TARGET_REPO・PAT 形式のチェック |
| エラーハンドリング | `set -euo pipefail` + 事前チェック関数 |

# プロジェクト構成の概要🗂️

```
github-projects-ops-kit/
├── .github/workflows/          # 6 つの自動化 Workflow
│   ├── 01-create-project.yml
│   ├── 02-extend-project.yml
│   ├── 03-create-special-repos.yml
│   ├── 04-setup-repository-labels.yml
│   ├── 05-add-items-to-project.yml
│   └── 06-analyze-project.yml
├── scripts/
│   ├── lib/common.sh           # 共通関数ライブラリ
│   ├── config/                 # JSON 定義ファイル群
│   └── *.sh                    # 各種スクリプト（12 本）
└── docs/                       # ドキュメント（GitHub Pages）
```

JSON 定義ファイルを編集するだけで、Field・Status・View・Label の構成をカスタマイズできます。

# 使い方の流れ🚀

```
1. リポジトリを Fork する
2. GitHub Personal Access Token (PAT) を発行し、Secrets に登録
3. GitHub Actions を有効化
4. Workflow を手動実行
```

GUI 操作のみでセットアップできる **[クイックスタート（GUI）](https://lurest-inc.github.io/github-starter-kit/getting-started/quickstart-gui/)** と、ターミナル操作で進める **[クイックスタート（CLI）](https://lurest-inc.github.io/github-starter-kit/getting-started/quickstart-cli/)** の 2 種類のガイドを用意しています。

# おわりに

今回は GitHub Projects の初期構築・運用分析を自動化するツールキット **GitHub Projects Ops Kit** を紹介しました。

「GitHub Projects を使いたいけどセットアップが面倒」「プロジェクトの進捗を定量的に把握したい」という方にぜひ試していただきたいです。

現在 v1.1.2 ですが、今後もエンハンスを続けていきます。

- 分析レポートの拡充（バーンダウンチャート等）
- 定期実行による自動レポート配信
- より柔軟なカスタマイズ対応

**⭐ Star や Fork をいただけると開発の励みになります！**
Issue や Discussions でのフィードバックも大歓迎です。

**よければいいね👍やフォローをお願いいたします！**

# 関連リンク📎

- **リポジトリ**: https://github.com/lurest-inc/github-starter-kit
- **ドキュメント**: https://lurest-inc.github.io/github-starter-kit/
- **CHANGELOG**: https://github.com/lurest-inc/github-starter-kit/blob/main/CHANGELOG.md
