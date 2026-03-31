# ⚙️ Workflow リファレンス

GitHub Actions の `workflow_dispatch` で実行する各 Workflow の詳細ドキュメントです。番号順に実行することを推奨します。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#%E3%83%9A%E3%83%BC%E3%82%B8%E4%B8%80%E8%A6%A7">ページ一覧</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## ページ一覧

### 🏗️ 構築系

| Workflow | 内容 |
|----------|------|
| [① GitHub Project 新規作成](01-create-project.md) | Project の作成 & Field・Status・View を一括セットアップ |
| [② GitHub Project 拡張](02-extend-project.md) | 既存 Project に Field・Status・View を追加 |
| [③ 特殊 Repository 一括作成](03-create-special-repos.md) | プロフィール README・GitHub Pages・dotfiles 等の特殊 Repository を一括作成 |
| [④ Issue Label 一括追加](04-setup-repository-labels.md) | 設定ファイルで定義した Issue Label を Repository に一括作成 |
| [⑤ Issue/PR 一括紐付け](05-add-items-to-project.md) | Project に Repository の Issue/PR を一括追加 |
| [⑦ Community Health Files 一括登録](07-setup-repository-health-files.md) | Community Health Files を Repository に一括登録 |

### 📈 分析系

| Workflow | 内容 |
|----------|------|
| [⑥ 統合 Project 分析](06-analyze-project.md) | エクスポート・滞留検出・サマリー・工数・ベロシティレポートを生成 |
