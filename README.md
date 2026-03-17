# GitHub Projects Starter Kit

[![Pages Deploy](https://github.com/mabubu0203/github-projects-starter-kit/actions/workflows/pages/pages-build-deployment/badge.svg)](https://github.com/mabubu0203/github-projects-starter-kit/actions/workflows/pages/pages-build-deployment)
[![TOC Generator](https://github.com/mabubu0203/github-projects-starter-kit/actions/workflows/toc.yml/badge.svg)](https://github.com/mabubu0203/github-projects-starter-kit/actions/workflows/toc.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Platform: macOS/Windows](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-blue.svg)

GitHub Projects の初期セットアップを GitHub Actions で自動実行するためのスターターキットです。
本リポジトリを fork し、GitHub Actions を手動実行することで、GitHub Project の作成から分析までを一貫して行えます。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [🚀 このキットでできること](#-%E3%81%93%E3%81%AE%E3%82%AD%E3%83%83%E3%83%88%E3%81%A7%E3%81%A7%E3%81%8D%E3%82%8B%E3%81%93%E3%81%A8)
- [✅ セットアップ後にできること](#-%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97%E5%BE%8C%E3%81%AB%E3%81%A7%E3%81%8D%E3%82%8B%E3%81%93%E3%81%A8)
- [📖 ドキュメント](#-%E3%83%89%E3%82%AD%E3%83%A5%E3%83%A1%E3%83%B3%E3%83%88)
- [📋 更新履歴](#-%E6%9B%B4%E6%96%B0%E5%B1%A5%E6%AD%B4)
- [📄 ライセンス](#-%E3%83%A9%E3%82%A4%E3%82%BB%E3%83%B3%E3%82%B9)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 🚀 このキットでできること

- **GitHub Project の新規作成・拡張**: カスタムフィールド・ステータス・ビューを一括セットアップ
- **Issue ラベルの一括管理**: リポジトリへのラベル定義を一括作成
- **Issue/PR の一括紐付け**: リポジトリの Issue や PR を Project に一括追加
- **プロジェクト分析・レポート生成**:
  - アイテムのエクスポート（JSON/Markdown/CSV/TSV）
  - 滞留アイテムの検知（ステータス別閾値で判定）
  - サマリーレポート（ステータス別・担当者別・ラベル別集計）
  - 工数レポート（見積もり・実績の集計と乖離分析）
  - ベロシティレポート（直近 8 週間の完了アイテム推移）

## ✅ セットアップ後にできること

| ワークフロー | 概要 |
|---|---|
| ① GitHub Project 新規作成 | Project を作成し、フィールド・ステータス・ビューを一括セットアップ |
| ② GitHub Project 拡張 | 既存 Project にフィールド・ステータス・ビューを追加 |
| ③ Issue ラベル一括追加 | 指定リポジトリにラベルを一括作成 |
| ④ Issue/PR 一括紐付け | Issue や PR を Project に一括追加（種別・状態・ラベルでフィルタ可能） |
| ⑤ 統合プロジェクト分析 | エクスポート・滞留検知・各種レポートを生成（アーティファクトとしてダウンロード可能） |

すべてのワークフローは GitHub Actions の手動実行（`workflow_dispatch`）で利用できます。

## 📖 ドキュメント

導入手順や使い方の詳細は GitHub Pages をご参照ください。

📄 **ドキュメント（HTML版）**: [https://mabubu0203.github.io/github-projects-starter-kit/](https://mabubu0203.github.io/github-projects-starter-kit/)

## 📋 更新履歴

詳細な更新履歴は [CHANGELOG.md](CHANGELOG.md) をご覧ください。

---

## 📄 ライセンス

MIT ライセンスです。詳しくは [LICENSE](LICENSE) をご確認ください。
