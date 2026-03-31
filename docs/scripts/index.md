# 📜 スクリプトリファレンス

各 Bash スクリプトの仕様・パラメータ・使用方法の詳細ドキュメントです。Workflow をカスタマイズしたい方や開発者向けの情報です。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#%E3%83%9A%E3%83%BC%E3%82%B8%E4%B8%80%E8%A6%A7">ページ一覧</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## ページ一覧

### 🏗️ セットアップ系

| スクリプト | 内容 |
|-----------|------|
| [setup-github-project.sh](setup-github-project.md) | 新規 GitHub Project を作成 |
| [setup-project-fields.sh](setup-project-fields.md) | カスタムフィールドを自動作成 |
| [setup-project-status.sh](setup-project-status.md) | ステータスカラムを設定 |
| [setup-project-views.sh](setup-project-views.md) | ビューを自動作成 |
| [setup-repository-labels.sh](setup-repository-labels.md) | Repository に Label を一括作成 |
| [create-special-repos.sh](create-special-repos.md) | 特殊 Repository を一括作成 |
| [setup-repository-health-files.sh](setup-repository-health-files.md) | Community Health Files を Repository に一括登録 |
| [setup-repository-scaffold-files.sh](setup-repository-scaffold-files.md) | Scaffold ファイル（IDE・AI ツール設定など）を Repository に一括登録 |

### 📥 データ操作系

| スクリプト | 内容 |
|-----------|------|
| [add-items-to-project.sh](add-items-to-project.md) | Issue/PR を Project に一括追加 |
| [export-project-items.sh](export-project-items.md) | Project の Issue/PR 一覧をエクスポート |

### 📊 分析・レポート系

| スクリプト | 内容 |
|-----------|------|
| [detect-stale-items.sh](detect-stale-items.md) | 指定日数以上動きのないアイテムを検出 |
| [generate-summary-report.sh](generate-summary-report.md) | Status 別・担当者別・Label 別の集計レポート |
| [generate-effort-report.sh](generate-effort-report.md) | 工数集計・分析レポート |
| [generate-velocity-report.sh](generate-velocity-report.md) | 週次ベロシティレポート |
