# 🔍 トラブルシューティング

Workflow 実行時に発生しやすい問題と対処法をまとめています。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-fork-%E5%BE%8C%E3%81%AB-github-actions-%E3%81%8C%E5%8B%95%E3%81%8B%E3%81%AA%E3%81%84">⚠️ Fork 後に GitHub Actions が動かない</a></li>

<li><a href="#-%E6%A8%A9%E9%99%90%E3%82%A8%E3%83%A9%E3%83%BC%E3%81%8C%E7%99%BA%E7%94%9F%E3%81%99%E3%82%8B">🔐 権限エラーが発生する</a></li>

<li><a href="#-workflow-%E3%81%8C%E8%A6%8B%E3%81%A4%E3%81%8B%E3%82%89%E3%81%AA%E3%81%84">🔎 Workflow が見つからない</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## ⚠️ Fork 後に GitHub Actions が動かない

Fork した Repository では、セキュリティ上の理由により **`GitHub Actions` がデフォルトで無効** になっています。以下の手順で有効化してください。

### 有効化手順（GUI）

1. Fork 先 Repository の **`Actions`** タブを開く
2. 「 I understand my workflows, go ahead and enable them 」ボタンをクリックする

### 有効化手順（CLI）

```bash
gh api repos/<owner>/github-projects-ops-kit/actions/permissions \
  --method PUT \
  --field enabled=true \
  --field allowed_actions="all"
```

> **Note:** この操作は Repository ごとに**1**回だけ必要です。有効化後は Workflow を通常通り実行できます。

---

## 🔐 権限エラーが発生する

Workflow 実行時に権限関連のエラーが出る場合は、以下を確認してください。

### チェックリスト

- [ ] PAT に必要な権限が設定されているか（→ [認証・トークンガイド](../guide/auth-tokens.md) で確認）
- [ ] PAT が Repository の Secrets に正しく登録されているか（Secret 名: `PROJECT_PAT`）
- [ ] `Fine-grained token` の場合、対象 Repository へのアクセスが許可されているか
- [ ] `Classic token` の場合、`read:org` Scope が含まれているか

### よくあるエラーメッセージ

| エラー | 原因 | 対処 |
|--------|------|------|
| `unknown owner type` | `read:org` Scope が不足している | Classic token に `read:org` を追加する |
| `Resource not accessible by personal access token` | PAT の権限が不足している | [認証・トークンガイド](../guide/auth-tokens.md) を参照して権限を見直す |
| `Could not resolve to a ProjectV2` | `project_number` が正しくない、または PAT に Project 権限がない | [入力値ガイド](../guide/input-values.md) で `project_number` を確認する |

---

## 🔎 Workflow が見つからない

`Actions` タブに Workflow が表示されない場合は、以下を確認してください。

- Fork 後に `GitHub Actions` を有効化しているか（上記「 Fork 後に GitHub Actions が動かない」を参照）
- Repository の `.github/workflows/` ディレクトリに Workflow ファイルが存在するか
- DefaultBranch（`main`）に Workflow ファイルがあるか
