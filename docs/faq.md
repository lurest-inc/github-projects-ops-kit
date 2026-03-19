# ❓ よくある質問（FAQ）

Workflow 利用時につまづきやすいポイントをまとめています。

> **ヒント:** トークンの権限設定については [認証・トークンガイド](guide/auth-tokens)、入力値の確認方法については [入力値ガイド](guide/input-values)、カンバン運用については [運用ルール](guide/kanban-rules)、 Label 運用については [Label 運用ルール](guide/label-rules) をご覧ください。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-q1-fork-%E5%BE%8C%E3%81%AB-github-actions-%E3%81%8C%E5%8B%95%E3%81%8D%E3%81%BE%E3%81%9B%E3%82%93">💡 Q1. Fork 後に GitHub Actions が動きません</a></li>

<li><a href="#-q2-%E6%A8%A9%E9%99%90%E3%82%A8%E3%83%A9%E3%83%BC%E3%81%A7-workflow-%E3%81%8C%E5%A4%B1%E6%95%97%E3%81%97%E3%81%BE%E3%81%99">💡 Q2. 権限エラーで Workflow が失敗します</a></li>

<li><a href="#-q3-%E6%97%A2%E5%AD%98%E3%81%AE-project-%E3%81%AB%E5%AF%BE%E3%81%97%E3%81%A6-workflow-%E2%91%A0-%E3%82%92%E5%AE%9F%E8%A1%8C%E3%81%97%E3%81%A6%E3%81%97%E3%81%BE%E3%81%84%E3%81%BE%E3%81%97%E3%81%9F">💡 Q3. 既存の Project に対して Workflow ① を実行してしまいました</a></li>

<li><a href="#-q4-workflow-%E2%91%A3-%E3%81%A7%E7%95%B0%E3%81%AA%E3%82%8B-organization-%E3%81%AE-repository-%E3%82%92%E6%8C%87%E5%AE%9A%E3%81%A7%E3%81%8D%E3%81%BE%E3%81%99%E3%81%8B">💡 Q4. Workflow ④ で異なる Organization の Repository を指定できますか？</a></li>

<li><a href="#-q5-%E5%90%8C%E3%81%98-issuepr-%E3%82%92%E8%A4%87%E6%95%B0%E5%9B%9E%E8%BF%BD%E5%8A%A0%E3%81%97%E3%81%A6%E3%81%97%E3%81%BE%E3%81%84%E3%81%BE%E3%81%9B%E3%82%93%E3%81%8B">💡 Q5. 同じ Issue/PR を複数回追加してしまいませんか？</a></li>

<li><a href="#-q6-%E3%82%A8%E3%82%AF%E3%82%B9%E3%83%9D%E3%83%BC%E3%83%88%E3%81%97%E3%81%9F%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB%E3%81%AF%E3%81%A9%E3%81%93%E3%81%8B%E3%82%89%E3%83%80%E3%82%A6%E3%83%B3%E3%83%AD%E3%83%BC%E3%83%89%E3%81%A7%E3%81%8D%E3%81%BE%E3%81%99%E3%81%8B">💡 Q6. エクスポートしたファイルはどこからダウンロードできますか？</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 💡 Q1. Fork 後に GitHub Actions が動きません

A. Fork した Repository では `GitHub Actions` がデフォルトで無効になっています。`Actions` タブから有効化してください。

→ 詳しい手順は [トラブルシューティング](troubleshooting#fork-後に-github-actions-が動かない) を参照

---

## 💡 Q2. 権限エラーで Workflow が失敗します

A. PAT の権限設定が不足している可能性があります。

→ [トラブルシューティング > 権限エラーが発生する](troubleshooting#権限エラーが発生する) を参照

---

## 💡 Q3. 既存の Project に対して Workflow ① を実行してしまいました

A. Workflow ① は新規 Project を作成するものです。既存 Project に Field や Status を追加したい場合は、 Workflow ②（[GitHub Project 拡張](workflows/02-extend-project)）を使用してください。

> **Note:** Workflow ① を実行した場合、新しい Project が別途作成されます。不要な場合は GitHub 上で手動削除してください。

---

## 💡 Q4. Workflow ④ で異なる Organization の Repository を指定できますか？

A. `Fine-grained token` は 1 つの Organization（または個人用アカウント）にしか紐づけられません。異なる Organization の Repository を対象にする場合は、`Classic token` を使用してください。

→ 詳しくは [認証・トークンガイド > Fine-grained token の制約事項](guide/auth-tokens#fine-grained-token-の制約事項) を参照

---

## 💡 Q5. 同じ Issue/PR を複数回追加してしまいませんか？

A. Workflow ⑤（[Issue/PR 一括紐付け](workflows/05-add-items-to-project)）は既に Project に追加済みの Item を自動的にスキップします。同じ Workflow を何度実行しても重複追加は発生しません。

---

## 💡 Q6. エクスポートしたファイルはどこからダウンロードできますか？

A. Workflow ⑥（[統合プロジェクト分析](workflows/06-analyze-project)）の実行完了後、`Actions` タブの該当 Workflow 実行ページにある **Artifacts** セクションからダウンロードできます。保持期間は `retention_days` パラメータで指定した日数（デフォルト: 7 日）です。

→ Artifact の削除方法については [Artifact の手動削除ガイド](guide/delete-artifacts) を参照
