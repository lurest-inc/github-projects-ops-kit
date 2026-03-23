# GitHub Projects Ops Kit

![Platform: macOS/Windows](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-blue.svg)
![GitHub Top Language](https://img.shields.io/github/languages/top/lurest-inc/github-starter-kit)
[![GitHub Release](https://img.shields.io/github/v/release/lurest-inc/github-starter-kit)](https://github.com/lurest-inc/github-starter-kit/releases)
[![GitHub Release Date](https://img.shields.io/github/release-date/lurest-inc/github-starter-kit)](https://github.com/lurest-inc/github-starter-kit/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
  
[![GitHub Stars](https://img.shields.io/github/stars/lurest-inc/github-starter-kit)](https://github.com/lurest-inc/github-starter-kit/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/lurest-inc/github-starter-kit)](https://github.com/lurest-inc/github-starter-kit/forks)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/lurest-inc/github-starter-kit)](https://github.com/lurest-inc/github-starter-kit/commits)
[![Issues Welcome](https://img.shields.io/badge/Issues-welcome-brightgreen)](https://github.com/lurest-inc/github-starter-kit/issues)
[![Discussions Welcome](https://img.shields.io/badge/Discussions-welcome-brightgreen)](https://github.com/lurest-inc/github-starter-kit/discussions)
  
[![TOC Generator](https://github.com/lurest-inc/github-starter-kit/actions/workflows/toc.yml/badge.svg)](https://github.com/lurest-inc/github-starter-kit/actions/workflows/toc.yml)
[![Pages Deploy](https://github.com/lurest-inc/github-starter-kit/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/lurest-inc/github-starter-kit/actions/workflows/pages/pages-build-deployment)
[![release-please](https://github.com/lurest-inc/github-starter-kit/actions/workflows/release-please.yml/badge.svg)](https://github.com/lurest-inc/github-starter-kit/actions/workflows/release-please.yml)

`GitHub Projects` の初期構築から運用分析までを `GitHub Actions` で半自動実行するための運用キットです。
本 Repository を Fork し、Workflow を手動実行することで、Project の作成から分析までを一気通貫して行えます。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-%E3%81%93%E3%81%AE%E3%82%AD%E3%83%83%E3%83%88%E3%81%A7%E3%81%A7%E3%81%8D%E3%82%8B%E3%81%93%E3%81%A8">🚀 このキットでできること</a></li>

<li><a href="#-%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97%E5%BE%8C%E3%81%AB%E3%81%A7%E3%81%8D%E3%82%8B%E3%81%93%E3%81%A8">✅ セットアップ後にできること</a></li>

<li><a href="#-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88">📖 ドキュメント</a></li>

<li><a href="#-%E6%9B%B4%E6%96%B0%E5%B1%A5%E6%AD%B4">📋 更新履歴</a></li>

<li><a href="#-%E3%83%A9%E3%82%A4%E3%82%BB%E3%83%B3%E3%82%B9">📄 ライセンス</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 🚀 このキットでできること

- **GitHub Project の新規作成・拡張**: Field・Status・View を一括セットアップ
- **Issue ラベルの一括管理**: Repository への Label 定義を一括作成
- **Issue/PR の一括紐付け**: Repository の Issue や PR を Project に一括追加
- **プロジェクト分析・レポート生成**:
  - Item のエクスポート（JSON/Markdown/CSV/TSV）
  - 滞留 Item の検知（Status 別閾値で判定）
  - サマリーレポート（Status 別・担当者別・Label 別集計）
  - 工数レポート（見積もり・実績の集計と乖離分析）
  - ベロシティレポート（直近 8 週間の完了 Item 推移）

## ✅ セットアップ後にできること

| Workflow | 概要 |
|---|---|
| ① GitHub Project 新規作成 | Project を作成し、Field・Status・View を一括セットアップ |
| ② GitHub Project 拡張 | 既存 Project に、Field・Status・View を追加 |
| ③ 特殊 Repository 一括作成 | GitHub の特殊命名規則 Repository（プロフィール README、`GitHub Pages` 等）を一括作成 |
| ④ Issue Label 一括追加 | 指定 Repository に Issue Label を一括作成 |
| ⑤ Issue/PR 一括紐付け | Issue や PR を Project に一括追加（種別・状態・ラベルでフィルタ可能） |
| ⑥ 統合 Project 分析 | エクスポート・滞留検知・各種レポートを生成（ Artifact としてダウンロード可能） |

すべての Workflow は `GitHub Actions` の手動実行（`workflow_dispatch`）で利用できます。

## 📖 ドキュメント

導入手順や使い方の詳細は `GitHub Pages` をご参照ください。

📄 **ドキュメント（HTML版）**: [GitHub Projects Ops Kit ドキュメント](https://lurest-inc.github.io/github-starter-kit/)

## 📋 更新履歴

詳細な更新履歴は [CHANGELOG.md](CHANGELOG.md) をご覧ください。

---

## 📄 ライセンス

MIT ライセンスです。詳しくは [LICENSE](LICENSE) をご確認ください。
