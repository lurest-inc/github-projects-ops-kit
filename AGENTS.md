# AGENTS.md

このファイルは、AI コーディングアシスタント (Claude Code, GitHub Copilot, Cursor 等) がこのリポジトリで作業する際のガイダンスを提供します。

## プロジェクト概要

GitHub Projects の初期構築・運用分析を自動化する Bash スクリプトツールキット。
GitHub Actions の `workflow_dispatch` 経由で手動実行する設計。個人アカウントと Organization の両方に対応。

## 言語・技術スタック

- **主要言語**: Bash (すべてのスクリプトは `#!/usr/bin/env bash`)
- **依存ツール**: GitHub CLI (`gh`)、`jq`
- **CI/CD**: GitHub Actions (ubuntu-latest)
- **リリース管理**: release-please (Conventional Commits ベースの自動バージョニング)

## リポジトリ構成

```
scripts/
  lib/common.sh             # 全スクリプト共通の関数ライブラリ (source して使用)
  config/                   # JSON 定義ファイル群 (フィールド・ステータス・ラベル等)
  setup-*.sh                # プロジェクト構築系スクリプト
  create-special-repos.sh   # 特殊 Repository 一括作成 (Workflow 03 から呼び出し)
  add-items-to-project.sh   # Issue/PR 一括追加
  detect-stale-items.sh     # 停滞アイテム検出
  export-project-items.sh   # データエクスポート
  generate-*-report.sh      # レポート生成系

.github/workflows/
  01-create-project.yml          # 新規プロジェクト作成
  02-extend-project.yml          # 既存プロジェクト拡張
  _reusable-extend-project.yml   # 再利用可能ワークフロー
  03-create-special-repos.yml    # 特殊 Repository 一括作成
  04-setup-repository-labels.yml # Issue Label 一括作成
  05-setup-repository-files.yml  # 初期ファイル一括作成
  06-setup-repository-rulesets.yml # Repository Ruleset 一括作成
  07-add-items-to-project.yml    # Issue/PR 一括紐付け
  08-analyze-project.yml         # 統合分析 (エクスポート・停滞検出・レポート)
```

## アーキテクチャ上の重要ポイント

- `scripts/lib/common.sh` は全スクリプトが `source` する共通ライブラリ。環境変数チェック (`require_env`)、コマンド存在確認 (`require_command`)、ワークフローコマンドインジェクション防止 (`sanitize_for_workflow_command`) 等を提供
- `scripts/config/` 配下の JSON ファイルがプロジェクトのフィールド定義・ステータス・ラベル等の設定を保持。スクリプトはこれらを `jq` で読み取って GitHub API を呼び出す
- ワークフローは番号付きで実行順序を示す (01 → 02 → ... → 08)
- すべてのワークフローは `PROJECT_PAT` シークレット (GitHub Personal Access Token) を必要とする
- `.github/actions/workflow-summary/` にワークフロー実行結果のサマリー表示用カスタムアクションがある

## コミット規約

Conventional Commits 形式を使用:
```
feat: 新機能の説明
fix: バグ修正の説明
docs: ドキュメントの修正
style: フォーマット修正
refactor: リファクタリング
```

## ブランチ命名規則

`issues/#<Issue番号>` 形式 (例: `issues/#123`)

## PR・マージ方針

- Squash and Merge を使用
- メンテナーの承認が必要
