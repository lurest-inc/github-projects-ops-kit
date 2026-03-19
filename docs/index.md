# 📖 GitHub Starter Kit ドキュメント

![Platform: macOS/Windows](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-blue.svg)
![GitHub Top Language](https://img.shields.io/github/languages/top/lurest-inc/github-starter-kit)
[![GitHub Release](https://img.shields.io/github/v/release/lurest-inc/github-starter-kit)](https://github.com/lurest-inc/github-starter-kit/releases)
[![GitHub Release Date](https://img.shields.io/github/release-date/lurest-inc/github-starter-kit)](https://github.com/lurest-inc/github-starter-kit/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/lurest-inc/github-starter-kit/blob/main/LICENSE)

[![GitHub Stars](https://img.shields.io/github/stars/lurest-inc/github-starter-kit)](https://github.com/lurest-inc/github-starter-kit/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/lurest-inc/github-starter-kit)](https://github.com/lurest-inc/github-starter-kit/forks)
[![Issues Welcome](https://img.shields.io/badge/Issues-welcome-brightgreen)](https://github.com/lurest-inc/github-starter-kit/issues)
[![Discussions Welcome](https://img.shields.io/badge/Discussions-welcome-brightgreen)](https://github.com/lurest-inc/github-starter-kit/discussions)

`GitHub Projects` の初期セットアップを `GitHub Actions` で自動実行するための **スターターキット** です。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-%E3%81%AF%E3%81%98%E3%82%81%E3%81%A6%E3%81%AE%E6%96%B9%E3%81%B8">🚀 はじめての方へ</a></li>

<li><a href="#-%E3%82%84%E3%82%8A%E3%81%9F%E3%81%84%E3%81%93%E3%81%A8%E5%88%A5%E3%82%AC%E3%82%A4%E3%83%89">📋 やりたいこと別ガイド</a></li>

<li><a href="#-%E5%9B%B0%E3%81%A3%E3%81%9F%E3%81%A8%E3%81%8D%E3%81%AF">🔧 困ったときは</a></li>

<li><a href="#-%E3%82%B3%E3%83%9F%E3%83%A5%E3%83%8B%E3%83%86%E3%82%A3%E3%81%AB%E5%8F%82%E5%8A%A0%E3%81%99%E3%82%8B">🤝 コミュニティに参加する</a></li>

<li><a href="#-%E8%A9%B3%E3%81%97%E3%81%8F%E7%9F%A5%E3%82%8A%E3%81%9F%E3%81%84%E6%96%B9%E3%81%B8">📚 詳しく知りたい方へ</a></li>

<li><a href="#-%E9%96%8B%E7%99%BA%E8%80%85%E5%90%91%E3%81%91">👨‍💻 開発者向け</a></li>

<li><a href="#-repository">🏠 Repository</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 💡 ユースケース別ガイド

ターゲットに合わせた活用方法を紹介しています。

| 対象 | ページ |
|------|--------|
| 個人開発者・OSS メンテナー | [個人アカウント向け活用ガイド](use-case-personal) |
| チームリーダー・マネージャー | [Organization 向け活用ガイド](use-case-organization) |

---

## 🚀 はじめての方へ

`GitHub Projects` を使ったプロジェクト管理をすぐに始められます。以下のステップで進めてください。

```mermaid
flowchart LR
    A["1. Fork"] --> B["2. PAT 作成"]
    B --> C["3. Secrets 設定"]
    C --> D["4. Actions 有効化"]
    D --> E["5. Workflow 実行"]
```

### 🖱️ GUI で進める方（おすすめ）

GitHub の画面操作だけでセットアップできます。コマンド操作は不要です。

→ [GUI クイックスタート](quickstart-gui)

### ⌨️ CLI で進める方（上級者向け）

`gh` CLI を使ってターミナルから操作します。生成 AI へのヒントとしても活用できます。

→ [CLI クイックスタート](quickstart-cli)

---

## 📋 やりたいこと別ガイド

| やりたいこと | Workflow | 説明 |
|-------------|-------------|------|
| 新しく Project を作りたい | [① GitHub Project 新規作成](workflows/01-create-project) | Project の作成 & Field ・ Status ・ View を一括セットアップ |
| 既存の Project を整えたい | [② GitHub Project 拡張](workflows/02-extend-project) | 既存 Project に Field ・ Status ・ View を追加 |
| 特殊 Repository を一括作成したい | [③ 特殊 Repository 一括作成](workflows/03-create-special-repos) | プロフィール README・`GitHub Pages`・dotfiles 等の特殊 Repository を一括作成 |
| Repository に Issue Label を一括追加したい | [④ Issue Label 一括追加](workflows/04-setup-repository-labels) | 設定ファイルで定義した Issue Label を Repository に一括作成 |
| Issue/PR をまとめて取り込みたい | [⑤ Issue/PR 一括紐付け](workflows/05-add-items-to-project) | Project に Repository の `Issue`/`PR` を 一括追加 |
| Project の内容を一覧で出したい | [⑥ 統合 Project 分析](workflows/06-analyze-project) | Project の `Issue`/`PR` 一覧をエクスポート（`report_types: export`） |
| Project を分析したい | [⑥ 統合 Project 分析](workflows/06-analyze-project) | 滞留検知・サマリー・工数集計・エクスポートをまとめて、または個別に実行 |

---

## 🔧 困ったときは

| 状況 | 参照先 |
|------|--------|
| エラーが出る・動かない | [トラブルシューティング](troubleshooting) |
| よくある質問を確認したい | [FAQ](faq) |
| バグを報告したい | [バグ報告](https://github.com/lurest-inc/github-starter-kit/issues/new?template=bug_report.yml) |

---

## 🤝 コミュニティに参加する

| やりたいこと | 参照先 |
|-------------|--------|
| 機能リクエストをしたい | [機能リクエスト](https://github.com/lurest-inc/github-starter-kit/issues/new?template=feature_request.yml) |
| 質問したい | [Q&A](https://github.com/lurest-inc/github-starter-kit/discussions/categories/q-a) |
| アイデアを共有したい | [Ideas](https://github.com/lurest-inc/github-starter-kit/discussions/categories/ideas) |
| 雑談したい | [General](https://github.com/lurest-inc/github-starter-kit/discussions/categories/general) |
| 成果を共有したい | [Show and tell](https://github.com/lurest-inc/github-starter-kit/discussions/categories/show-and-tell) |
| コントリビュートしたい | [コントリビューションガイド](https://github.com/lurest-inc/github-starter-kit/blob/main/.github/CONTRIBUTING.md) |

---

## 📚 詳しく知りたい方へ

| トピック | 説明 |
|---------|------|
| [認証・トークンガイド](guide/auth-tokens) | PAT の権限設定、 Fine-grained / Classic token の選び方 |
| [入力値ガイド](guide/input-values) | `project_number`・`target_repo` などの確認方法 |
| [運用ルール](guide/kanban-rules) | カンバンフロー、カスタム Field 、 View 構成 |
| [Label 運用ルール](guide/label-rules) | Issue Label のカテゴリ分類、用途、付与タイミング |
| [Artifact の手動削除](guide/delete-artifacts) | Workflow で生成された Artifact の削除手順（GUI / CLI） |
| [用語集](glossary) | GitHub 関連の専門用語の解説 |

---

## 👨‍💻 開発者向け

Workflow の内部構成やスクリプトの詳細については [開発者向けドキュメント](developers) をご参照ください。

---

## 🏠 Repository

- GitHub: [lurest-inc/github-starter-kit](https://github.com/lurest-inc/github-starter-kit)
