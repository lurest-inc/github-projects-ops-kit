# よくある質問（FAQ）

ワークフロー利用時につまづきやすいポイントをまとめています。

> **ヒント:** トークンの権限設定については [認証・トークンガイド](guide/auth-tokens)、入力値の確認方法については [入力値ガイド](guide/input-values)、カンバン運用については [運用ルール](guide/kanban-rules) をご覧ください。

---

## Q1. フォーク後に GitHub Actions が動きません

フォークしたリポジトリでは GitHub Actions がデフォルトで無効になっています。Actions タブから有効化してください。

→ 詳しい手順は [トラブルシューティング](troubleshooting#フォーク後に-github-actions-が動かない) を参照

---

## Q2. 権限エラーでワークフローが失敗します

PAT の権限設定が不足している可能性があります。

→ [トラブルシューティング > 権限エラーが発生する](troubleshooting#権限エラーが発生する) を参照

---

## Q3. 既存の Project に対してワークフロー ① を実行してしまいました

ワークフロー ① は新規 Project を作成するものです。既存 Project にフィールドやステータスを追加したい場合は、ワークフロー ②（[GitHub Project 拡張](workflows/02-extend-project)）を使用してください。

> **Note:** ワークフロー ① を実行した場合、新しい Project が別途作成されます。不要な場合は GitHub 上で手動削除してください。

---

## Q4. ワークフロー ③ で異なる Organization のリポジトリを指定できますか？

`Fine-grained token` は 1 つの Organization（または個人用アカウント）にしか紐づけられません。異なる Organization のリポジトリを対象にする場合は、`Classic token` を使用してください。

→ 詳しくは [認証・トークンガイド > Fine-grained token の制約事項](guide/auth-tokens#fine-grained-token-の制約事項) を参照

---

## Q5. エクスポートしたファイルはどこからダウンロードできますか？

ワークフロー ④ の実行完了後、Actions タブの該当ワークフロー実行ページにある **Artifacts** セクションからダウンロードできます。保持期間は 7 日間です。

---

## Q6. 同じ Issue/PR を複数回追加してしまいませんか？

ワークフロー ③ は既に Project に追加済みのアイテムを自動的にスキップします。同じワークフローを何度実行しても重複追加は発生しません。
