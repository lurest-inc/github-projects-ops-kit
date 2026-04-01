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

| Workflow | 概要 |
|----------|------|
| [① GitHub Project 新規作成](01-create-project.md) | Project を作成し、Field・Status・View を一括セットアップ |
| [② GitHub Project 拡張](02-extend-project.md) | 既存 Project に Field・Status・View を追加 |
| [③ 特殊 Repository 一括作成](03-create-special-repos.md) | 特殊命名 Repository（プロフィール README・GitHub Pages 等）を一括作成 |
| [④ Issue Label 一括作成](04-setup-repository-labels.md) | 指定 Repository に Issue Label を一括作成 |
| [⑤ 初期ファイル一括作成](05-setup-repository-files.md) | 指定 Repository に初期ファイル（Community Health Files・Scaffold）を一括作成 |
| [⑥ Repository Ruleset 一括作成](06-setup-repository-rulesets.md) | 指定 Repository に Branch Ruleset を一括作成 |
| [⑦ Issue/PR 一括紐付け](07-add-items-to-project.md) | Repository の Issue/PR を Project に一括追加（種別・状態・ラベルでフィルタ可能） |

### 📈 運用・分析系

| Workflow | 概要 |
|----------|------|
| [⑧ 統合 Project 分析](08-analyze-project.md) | エクスポート・滞留検知・各種レポートを生成（Artifact としてダウンロード可能） |
