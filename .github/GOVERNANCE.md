# ガバナンスポリシー

本ドキュメントでは、プロジェクトの意思決定プロセスとロールを定義します。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#%E3%83%AD%E3%83%BC%E3%83%AB">ロール</a></li>

<li><a href="#%E6%84%8F%E6%80%9D%E6%B1%BA%E5%AE%9A%E3%83%97%E3%83%AD%E3%82%BB%E3%82%B9">意思決定プロセス</a></li>

<li><a href="#%E3%83%AC%E3%83%93%E3%83%A5%E3%83%BC%E3%81%A8%E3%83%9E%E3%83%BC%E3%82%B8">レビューとマージ</a></li>

<li><a href="#%E3%83%AA%E3%83%AA%E3%83%BC%E3%82%B9">リリース</a></li>

<li><a href="#%E3%83%9D%E3%83%AA%E3%82%B7%E3%83%BC%E3%81%AE%E5%A4%89%E6%9B%B4">ポリシーの変更</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## ロール

| ロール | 概要 |
|--------|------|
| **メンテナー** | リポジトリへの書き込み権限を持ち、Issue のトリアージ・PR のレビューとマージ・リリースを行う。行動規範の執行責任は [行動規範](CODE_OF_CONDUCT.md#責任) を参照 |
| **コントリビューター** | Issue の起票や Pull Request を通じてプロジェクトに貢献する。コントリビューションの手順は [コントリビューションガイド](CONTRIBUTING.md) を参照 |

## 意思決定プロセス

- 機能追加や設計変更は Issue または [Discussions](https://github.com/lurest-inc/github-starter-kit/discussions) で提案し、メンテナーの承認を経て実施する
- 軽微な修正（タイポ、ドキュメント更新など）は直接 Pull Request を作成できる

## レビューとマージ

- Pull Request のマージにはメンテナーによるレビュー承認が必要
- レビューでは機能の妥当性・コード品質・既存機能への影響を確認する
- マージは Squash and Merge を基本とする

## リリース

リリースは [release-please](https://github.com/googleapis/release-please) によって自動管理される。Conventional Commits に基づき、バージョニングとリリースノートが自動生成される。

## ポリシーの変更

本ガバナンスポリシーの変更は Pull Request を通じて提案し、メンテナーの承認を経て適用する。
