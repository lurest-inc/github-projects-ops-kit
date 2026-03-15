# トラブルシューティング

ワークフロー実行時に発生しやすい問題と対処法をまとめています。

---

## フォーク後に GitHub Actions が動かない

フォークしたリポジトリでは、セキュリティ上の理由により **GitHub Actions がデフォルトで無効** になっています。以下の手順で有効化してください。

### 有効化手順（GUI）

1. フォーク先リポジトリの **Actions** タブを開く
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

## 権限エラーが発生する

ワークフロー実行時に権限関連のエラーが出る場合は、以下を確認してください。

### チェックリスト

- [ ] PAT に必要な権限が設定されているか（→ [認証・トークンガイド](guide/auth-tokens) で確認）
- [ ] PAT がリポジトリの Secrets に正しく登録されているか（Secret 名: `PROJECT_PAT`）
- [ ] Fine-grained token の場合、対象リポジトリへのアクセスが許可されているか
- [ ] Classic token の場合、`read:org` スコープが含まれているか

### よくあるエラーメッセージ

| エラー | 原因 | 対処 |
|--------|------|------|
| `unknown owner type` | `read:org` スコープが不足している | Classic token に `read:org` を追加する |
| `Resource not accessible by personal access token` | PAT の権限が不足している | [認証・トークンガイド](guide/auth-tokens) を参照して権限を見直す |
| `Could not resolve to a ProjectV2` | `project_number` が正しくない、または PAT に Project 権限がない | [入力値ガイド](guide/input-values) で `project_number` を確認する |

---

## ワークフローが見つからない

Actions タブにワークフローが表示されない場合は、以下を確認してください。

- フォーク後に Actions を有効化しているか（上記「フォーク後に GitHub Actions が動かない」を参照）
- リポジトリの `.github/workflows/` ディレクトリにワークフローファイルが存在するか
- デフォルトブランチ（`main`）にワークフローファイルがあるか
