# 命名規則

本プロジェクトの名称に関する命名規則を定義します。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#名称一覧">名称一覧</a></li>

<li><a href="#使い分けガイド">使い分けガイド</a></li>

<li><a href="#旧名称からの移行チェックリスト">旧名称からの移行チェックリスト</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 名称一覧

| 種別 | 表記 |
|------|------|
| **物理名（リポジトリ名）** | `github-projects-ops-kit` |
| **論理名（英語）** | GitHub Projects Ops Kit |
| **論理名（日本語）** | GitHub Projects 運用キット |
| **短縮表記** | Ops Kit |

### 命名の意図

| 要素 | 意味 |
|------|------|
| `GitHub Projects` | 対象が GitHub Projects であることを明示（複数形は GitHub の正式機能名に準拠） |
| `Ops` | 初期構築だけでなく、運用・分析・レポートまで含む価値を表現 |
| `Kit` | ツール群をまとめたパッケージであることを表現 |

## 使い分けガイド

| 場面 | 使用する表記 | 例 |
|------|------------|-----|
| README タイトル | 論理名（英語） | `# GitHub Projects Ops Kit` |
| ドキュメントサイト（タイトル） | 論理名（英語） | `title: GitHub Projects Ops Kit` |
| 説明文（日本語） | 論理名（日本語） | `GitHub Projects 運用キット` |
| CLI コマンド / パス | 物理名 | `gh repo fork lurest-inc/github-projects-ops-kit` |
| ドキュメント内の短い参照 | 短縮表記 | `本 Ops Kit では...` |
| コード内コメント | 物理名 | `# github-projects-ops-kit` |

## 旧名称からの移行チェックリスト

### 本 PR で対応済み

- [x] README.md のタイトル・見出し・説明文
- [x] docs/ 配下のドキュメントタイトル・説明文
- [x] `docs/_config.yml` の title / description
- [x] `.github/SUPPORT.md` の表記
- [x] `.github/CONTRIBUTING.md` 内の説明文
- [x] `docs/use-cases/` のユースケースドキュメント

### リポジトリ名変更後に対応が必要

- [ ] GitHub URL 内の `github-starter-kit` を `github-projects-ops-kit` に一括置換
- [ ] GitHub Pages URL の変更（`lurest-inc.github.io/github-projects-ops-kit/`）
- [ ] バッジ URL の更新（README.md / docs/index.md）
- [ ] `gh repo fork` / `gh secret set` コマンド例の更新（quickstart-cli.md）
- [ ] `.github/ISSUE_TEMPLATE/config.yml` の URL 更新
- [ ] GitHub Discussions / Issues のリンク更新
- [ ] Qiita 記事内のリンク更新（公開済みコンテンツ）
- [ ] CLAUDE.md のプロジェクト説明更新
