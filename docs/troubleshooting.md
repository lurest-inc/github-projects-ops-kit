# 🔍 トラブルシューティング

ワークフロー実行時に発生しやすい問題と対処法をまとめています。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [⚠️ フォーク後に GitHub Actions が動かない](#-%E3%83%95%E3%82%A9%E3%83%BC%E3%82%AF%E5%BE%8C%E3%81%AB-github-actions-%E3%81%8C%E5%8B%95%E3%81%8B%E3%81%AA%E3%81%84)
  - [有効化手順（GUI）](#%E6%9C%89%E5%8A%B9%E5%8C%96%E6%89%8B%E9%A0%86gui)
  - [有効化手順（CLI）](#%E6%9C%89%E5%8A%B9%E5%8C%96%E6%89%8B%E9%A0%86cli)
- [🔐 権限エラーが発生する](#-%E6%A8%A9%E9%99%90%E3%82%A8%E3%83%A9%E3%83%BC%E3%81%8C%E7%99%BA%E7%94%9F%E3%81%99%E3%82%8B)
  - [チェックリスト](#%E3%83%81%E3%82%A7%E3%83%83%E3%82%AF%E3%83%AA%E3%82%B9%E3%83%88)
  - [よくあるエラーメッセージ](#%E3%82%88%E3%81%8F%E3%81%82%E3%82%8B%E3%82%A8%E3%83%A9%E3%83%BC%E3%83%A1%E3%83%83%E3%82%BB%E3%83%BC%E3%82%B8)
- [🔎 ワークフローが見つからない](#-%E3%83%AF%E3%83%BC%E3%82%AF%E3%83%95%E3%83%AD%E3%83%BC%E3%81%8C%E8%A6%8B%E3%81%A4%E3%81%8B%E3%82%89%E3%81%AA%E3%81%84)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## ⚠️ フォーク後に GitHub Actions が動かない

フォークしたリポジトリでは、セキュリティ上の理由により **`GitHub Actions` がデフォルトで無効** になっています。以下の手順で有効化してください。

### 有効化手順（GUI）

1. フォーク先リポジトリの **`Actions`** タブを開く
2. 「I understand my workflows, go ahead and enable them」ボタンをクリックする

### 有効化手順（CLI）

```bash
gh api repos/<owner>/github-projects-starter-kit/actions/permissions \
  --method PUT \
  --field enabled=true \
  --field allowed_actions="all"
```

> **Note:** この操作はリポジトリごとに 1 回だけ必要です。有効化後はワークフローを通常通り実行できます。

---

## 🔐 権限エラーが発生する

ワークフロー実行時に権限関連のエラーが出る場合は、以下を確認してください。

### チェックリスト

- [ ] PAT に必要な権限が設定されているか（→ [認証・トークンガイド](guide/auth-tokens) で確認）
- [ ] PAT がリポジトリの Secrets に正しく登録されているか（Secret 名: `PROJECT_PAT`）
- [ ] `Fine-grained token` の場合、対象リポジトリへのアクセスが許可されているか
- [ ] `Classic token` の場合、`read:org` スコープが含まれているか

### よくあるエラーメッセージ

| エラー | 原因 | 対処 |
|--------|------|------|
| `unknown owner type` | `read:org` スコープが不足している | Classic token に `read:org` を追加する |
| `Resource not accessible by personal access token` | PAT の権限が不足している | [認証・トークンガイド](guide/auth-tokens) を参照して権限を見直す |
| `Could not resolve to a ProjectV2` | `project_number` が正しくない、または PAT に Project 権限がない | [入力値ガイド](guide/input-values) で `project_number` を確認する |

---

## 🔎 ワークフローが見つからない

`Actions` タブにワークフローが表示されない場合は、以下を確認してください。

- フォーク後に `GitHub Actions` を有効化しているか（上記「フォーク後に GitHub Actions が動かない」を参照）
- リポジトリの `.github/workflows/` ディレクトリにワークフローファイルが存在するか
- デフォルトブランチ（`main`）にワークフローファイルがあるか
