# GitHub Projects Ops Kit

![Platform: macOS/Windows](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-blue.svg)
![GitHub Top Language](https://img.shields.io/github/languages/top/lurest-inc/github-projects-ops-kit)
[![GitHub Release](https://img.shields.io/github/v/release/lurest-inc/github-projects-ops-kit)](https://github.com/lurest-inc/github-projects-ops-kit/releases)
[![GitHub Release Date](https://img.shields.io/github/release-date/lurest-inc/github-projects-ops-kit)](https://github.com/lurest-inc/github-projects-ops-kit/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[![GitHub Stars](https://img.shields.io/github/stars/lurest-inc/github-projects-ops-kit)](https://github.com/lurest-inc/github-projects-ops-kit/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/lurest-inc/github-projects-ops-kit)](https://github.com/lurest-inc/github-projects-ops-kit/forks)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/lurest-inc/github-projects-ops-kit)](https://github.com/lurest-inc/github-projects-ops-kit/commits)
[![Issues Welcome](https://img.shields.io/badge/Issues-welcome-brightgreen)](https://github.com/lurest-inc/github-projects-ops-kit/issues)
[![Discussions Welcome](https://img.shields.io/badge/Discussions-welcome-brightgreen)](https://github.com/lurest-inc/github-projects-ops-kit/discussions)

[![TOC Generator](https://github.com/lurest-inc/github-projects-ops-kit/actions/workflows/toc.yml/badge.svg)](https://github.com/lurest-inc/github-projects-ops-kit/actions/workflows/toc.yml)
[![Pages Deploy](https://github.com/lurest-inc/github-projects-ops-kit/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/lurest-inc/github-projects-ops-kit/actions/workflows/pages/pages-build-deployment)
[![release-please](https://github.com/lurest-inc/github-projects-ops-kit/actions/workflows/release-please.yml/badge.svg)](https://github.com/lurest-inc/github-projects-ops-kit/actions/workflows/release-please.yml)

**GitHub Projects の初期構築から運用分析までを GitHub Actions で半自動化する運用キットです。**
Fork して Workflow を実行するだけで、Project の作成・分析・レポート生成を一気通貫で行えます。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-%E5%AF%BE%E8%B1%A1%E3%83%A6%E3%83%BC%E3%82%B6%E3%83%BC">👤 対象ユーザー</a></li>

<li><a href="#-%E4%B8%BB%E3%81%AA%E6%A9%9F%E8%83%BD">🚀 主な機能</a></li>

<li><a href="#-%E3%82%AF%E3%82%A4%E3%83%83%E3%82%AF%E3%82%B9%E3%82%BF%E3%83%BC%E3%83%88">⚡ クイックスタート</a></li>

<li><a href="#-workflow-%E4%B8%80%E8%A6%A7">📦 Workflow 一覧</a></li>

<li><a href="#-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88">📖 ドキュメント</a></li>

<li><a href="#-contributing--community">🤝 Contributing / Community</a></li>

<li><a href="#-%E6%9B%B4%E6%96%B0%E5%B1%A5%E6%AD%B4">📋 更新履歴</a></li>

<li><a href="#-%E3%83%A9%E3%82%A4%E3%82%BB%E3%83%B3%E3%82%B9">📄 ライセンス</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 👤 対象ユーザー

| セグメント | こんな方に |
|---|---|
| **個人開発者** | GitHub Projects の初期設定が面倒、運用の型を自分で作るのが大変と感じている方 |
| **OSS メンテナー / 小規模チーム** | コントリビュータ増加に伴い、運用ルールや Project 構成を標準化したい方 |
| **Organization 管理者 / PM / EM** | 複数リポジトリ・プロジェクトの横断管理や、レポート作成を効率化したい方 |

## 🚀 主な機能

- **即時セットアップ** — Workflow を 1 回実行するだけで、Project の作成から Field・Status・View の設定まで完了
- **構成のコード管理** — JSON 定義ファイルでプロジェクト構成を管理し、再現性と標準化を実現
- **運用分析の自動化** — 滞留検知・サマリー・工数・ベロシティレポートを自動生成
- **GitHub 完結** — 外部ツール不要。GitHub Actions と GitHub CLI だけで動作
- **個人にもチームにも** — 個人開発者の手軽な管理から、Organization の本格運用まで対応

## ⚡ クイックスタート

3 ステップで始められます。

### GUI（GitHub Actions）で始める場合

1. **Fork** — このリポジトリを Fork する
2. **PAT 設定** — Fork 先の Settings > Secrets に `PROJECT_PAT`（`project` スコープ付き Personal Access Token）を登録
3. **Workflow 実行** — Actions タブから `01 Create Project` を手動実行

### CLI で始める場合

```bash
gh repo fork lurest-inc/github-projects-ops-kit --clone
cd github-projects-ops-kit
gh secret set PROJECT_PAT
gh workflow run 01-create-project.yml
```

> 詳しい導入手順は [ドキュメント（GitHub Pages）](https://lurest-inc.github.io/github-projects-ops-kit/) をご覧ください。

## 📦 Workflow 一覧

### 構築系

| Workflow | 概要 |
|---|---|
| [① GitHub Project 新規作成](.github/workflows/01-create-project.yml) | Project を作成し、Field・Status・View を一括セットアップ |
| [② GitHub Project 拡張](.github/workflows/02-extend-project.yml) | 既存 Project に Field・Status・View を追加 |
| [③ 特殊 Repository 一括作成](.github/workflows/03-create-special-repos.yml) | プロフィール README・GitHub Pages 等の特殊命名 Repository を一括作成 |
| [④ Issue Label 一括追加](.github/workflows/04-setup-repository-labels.yml) | 指定 Repository に Issue Label を一括作成 |
| [⑤ 初期ファイル一括登録](.github/workflows/05-setup-repository-files.yml) | Community Health Files・Scaffold ファイルを Repository に一括登録 |
| [⑥ Issue/PR 一括紐付け](.github/workflows/06-add-items-to-project.yml) | Issue や PR を Project に一括追加（種別・状態・ラベルでフィルタ可能） |

### 運用・分析系

| Workflow | 概要 |
|---|---|
| [⑦ 統合 Project 分析](.github/workflows/07-analyze-project.yml) | エクスポート・滞留検知・各種レポートを生成（Artifact としてダウンロード可能） |

すべての Workflow は `GitHub Actions` の手動実行（`workflow_dispatch`）で利用できます。

## 📖 ドキュメント

導入手順・使い方の詳細は GitHub Pages をご参照ください。

📄 **[GitHub Projects Ops Kit ドキュメント](https://lurest-inc.github.io/github-projects-ops-kit/)**

## 🤝 Contributing / Community

- 💬 **[Discussions](https://github.com/lurest-inc/github-projects-ops-kit/discussions)** — 質問・アイデア・使い方の共有はこちら
- 🐛 **[Issues](https://github.com/lurest-inc/github-projects-ops-kit/issues)** — バグ報告や機能リクエストを歓迎します
- ⭐ **Star** — このプロジェクトが役に立ったら Star をお願いします

## 📋 更新履歴

詳細な更新履歴は [CHANGELOG.md](CHANGELOG.md) をご覧ください。

---

## 📄 ライセンス

MIT ライセンスです。詳しくは [LICENSE](LICENSE) をご確認ください。
