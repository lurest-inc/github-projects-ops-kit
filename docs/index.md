# 📖 GitHub Projects Starter Kit ドキュメント

![Platform: macOS/Windows](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-blue.svg)
![GitHub Top Language](https://img.shields.io/github/languages/top/mabubu0203/github-projects-starter-kit)
[![GitHub Release](https://img.shields.io/github/v/release/mabubu0203/github-projects-starter-kit)](https://github.com/mabubu0203/github-projects-starter-kit/releases)
[![GitHub Release Date](https://img.shields.io/github/release-date/mabubu0203/github-projects-starter-kit)](https://github.com/mabubu0203/github-projects-starter-kit/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/mabubu0203/github-projects-starter-kit/blob/main/LICENSE)

[![GitHub Stars](https://img.shields.io/github/stars/mabubu0203/github-projects-starter-kit)](https://github.com/mabubu0203/github-projects-starter-kit/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/mabubu0203/github-projects-starter-kit)](https://github.com/mabubu0203/github-projects-starter-kit/forks)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](https://github.com/mabubu0203/github-projects-starter-kit/pulls)

GitHub Projects の初期セットアップを GitHub Actions で自動実行するための **スターターキット** です。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [🚀 はじめての方へ](#-%E3%81%AF%E3%81%98%E3%82%81%E3%81%A6%E3%81%AE%E6%96%B9%E3%81%B8)
  - [🖱️ GUI で進める方（おすすめ）](#-gui-%E3%81%A7%E9%80%B2%E3%82%81%E3%82%8B%E6%96%B9%E3%81%8A%E3%81%99%E3%81%99%E3%82%81)
  - [⌨️ CLI で進める方（上級者向け）](#-cli-%E3%81%A7%E9%80%B2%E3%82%81%E3%82%8B%E6%96%B9%E4%B8%8A%E7%B4%9A%E8%80%85%E5%90%91%E3%81%91)
- [📋 やりたいこと別ガイド](#-%E3%82%84%E3%82%8A%E3%81%9F%E3%81%84%E3%81%93%E3%81%A8%E5%88%A5%E3%82%AC%E3%82%A4%E3%83%89)
- [🔧 困ったときは](#-%E5%9B%B0%E3%81%A3%E3%81%9F%E3%81%A8%E3%81%8D%E3%81%AF)
- [📚 詳しく知りたい方へ](#-%E8%A9%B3%E3%81%97%E3%81%8F%E7%9F%A5%E3%82%8A%E3%81%9F%E3%81%84%E6%96%B9%E3%81%B8)
- [👨‍💻 開発者向け](#-%E9%96%8B%E7%99%BA%E8%80%85%E5%90%91%E3%81%91)
- [🏠 リポジトリ](#-%E3%83%AA%E3%83%9D%E3%82%B8%E3%83%88%E3%83%AA)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 🚀 はじめての方へ

GitHub Projects を使ったプロジェクト管理をすぐに始められます。以下のステップで進めてください。

```mermaid
flowchart LR
    A["1. Fork"] --> B["2. PAT 作成"]
    B --> C["3. Secrets 設定"]
    C --> D["4. Actions 有効化"]
    D --> E["5. ワークフロー実行"]
```

### 🖱️ GUI で進める方（おすすめ）

GitHub の画面操作だけでセットアップできます。コマンド操作は不要です。

→ [GUI クイックスタート](quickstart-gui)

### ⌨️ CLI で進める方（上級者向け）

`gh` CLI を使ってターミナルから操作します。生成 AI へのヒントとしても活用できます。

→ [CLI クイックスタート](quickstart-cli)

---

## 📋 やりたいこと別ガイド

| やりたいこと | ワークフロー | 説明 |
|-------------|-------------|------|
| 新しく Project を作りたい | [① GitHub Project 新規作成](workflows/01-create-project) | `Project` の作成・フィールド・ステータス・View を一括セットアップ |
| 既存の Project を整えたい | [② GitHub Project 拡張](workflows/02-extend-project) | 既存 `Project` にフィールド・ステータス・View を追加 |
| リポジトリにラベルを一括追加したい | [③ Issue ラベル一括追加](workflows/03-setup-repository-labels) | 設定ファイルで定義したラベルをリポジトリに一括作成 |
| Issue/PR をまとめて取り込みたい | [④ Issue/PR 一括紐付け](workflows/04-add-items-to-project) | リポジトリの `Issue`/`PR` を `Project` に一括追加 |
| Project の内容を一覧で出したい | [⑤ 統合プロジェクト分析](workflows/05-analyze-project) | `Project` の `Issue`/`PR` 一覧をエクスポート（`report_types: export`） |
| プロジェクトを分析したい | [⑤ 統合プロジェクト分析](workflows/05-analyze-project) | 滞留検知・サマリー・工数集計・エクスポートをまとめて、または個別に実行 |

---

## 🔧 困ったときは

| 状況 | 参照先 |
|------|--------|
| エラーが出る・動かない | [トラブルシューティング](troubleshooting) |
| よくある質問を確認したい | [FAQ](faq) |

---

## 📚 詳しく知りたい方へ

| トピック | 説明 |
|---------|------|
| [認証・トークンガイド](guide/auth-tokens) | PAT の権限設定、Fine-grained / Classic token の選び方 |
| [入力値ガイド](guide/input-values) | `project_number`・`target_repo` などの確認方法 |
| [運用ルール](guide/kanban-rules) | カンバンフロー、カスタムフィールド、View 構成 |
| [ラベル運用ルール](guide/label-rules) | Issue ラベルのカテゴリ分類、用途、付与タイミング |
| [アーティファクトの手動削除](guide/delete-artifacts) | ワークフローで生成されたアーティファクトの削除手順（GUI / CLI） |
| [用語集](glossary) | GitHub 関連の専門用語の解説 |

---

## 👨‍💻 開発者向け

ワークフローの内部構成やスクリプトの詳細については [開発者向けドキュメント](developers) をご参照ください。

---

## 🏠 リポジトリ

- GitHub: [mabubu0203/github-projects-starter-kit](https://github.com/mabubu0203/github-projects-starter-kit)
