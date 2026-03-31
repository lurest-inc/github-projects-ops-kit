# 📜 スクリプトリファレンス

各 Bash スクリプトの仕様・パラメータ・使用方法の詳細ドキュメントです。Workflow をカスタマイズしたい方や開発者向けの情報です。

## ページ一覧

### 🏗️ セットアップ系

| スクリプト | 内容 |
|-----------|------|
| [setup-github-project.sh](setup-github-project) | 新規 GitHub Project を作成 |
| [setup-project-fields.sh](setup-project-fields) | カスタムフィールドを自動作成 |
| [setup-project-status.sh](setup-project-status) | ステータスカラムを設定 |
| [setup-project-views.sh](setup-project-views) | ビューを自動作成 |
| [setup-repository-labels.sh](setup-repository-labels) | Repository に Label を一括作成 |

### 📥 データ操作系

| スクリプト | 内容 |
|-----------|------|
| [add-items-to-project.sh](add-items-to-project) | Issue/PR を Project に一括追加 |
| [export-project-items.sh](export-project-items) | Project の Issue/PR 一覧をエクスポート |

### 📊 分析・レポート系

| スクリプト | 内容 |
|-----------|------|
| [detect-stale-items.sh](detect-stale-items) | 指定日数以上動きのないアイテムを検出 |
| [generate-summary-report.sh](generate-summary-report) | Status 別・担当者別・Label 別の集計レポート |
| [generate-effort-report.sh](generate-effort-report) | 工数集計・分析レポート |
| [generate-velocity-report.sh](generate-velocity-report) | 週次ベロシティレポート |
