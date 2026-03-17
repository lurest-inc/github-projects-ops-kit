# 🗑️ アーティファクトの手動削除ガイド

<!-- START doctoc -->
<!-- END doctoc -->

ワークフローで生成されたアーティファクトを手動で削除する方法を説明します。

> **Note:** アーティファクトの公開範囲に関する注意事項は [⑤ 統合プロジェクト分析](../workflows/05-analyze-project.md#️-アーティファクトの公開範囲に関する注意事項) を参照してください。

---

## ⚠️ 注意事項

- 一度削除したアーティファクトは **復元できません**
- 削除にはリポジトリへの **Write（書き込み）アクセス** が必要です

---

## 🖥️ GUI で削除する

1. リポジトリの **Actions** タブを開く
2. 左サイドバーから対象のワークフローを選択する
3. 対象のワークフロー実行（run）をクリックしてサマリーページを開く
4. ページ下部の **Artifacts** セクションを確認する
5. 削除したいアーティファクトの横にある **🗑️（ゴミ箱アイコン）** をクリックする
6. 確認ダイアログで削除を承認する

---

## 💻 CLI / API で削除する

### GitHub CLI でアーティファクトを個別削除する

```bash
# 1. ワークフロー実行の一覧を取得する
gh run list --workflow="05-analyze-project.yml"

# 2. 特定の run に紐づくアーティファクトを確認する
gh api repos/{owner}/{repo}/actions/runs/{run_id}/artifacts

# 3. アーティファクトを削除する
gh api -X DELETE repos/{owner}/{repo}/actions/runs/{run_id}/artifacts/{artifact_id}
```

### ワークフロー実行ごと削除する

ワークフロー実行を削除すると、紐づくアーティファクトも全て削除されます。

```bash
gh run delete {run_id}
```

### REST API で削除する

```
DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}
```

成功時のレスポンス: `204 No Content`

> **参考:** [REST API endpoints for GitHub Actions artifacts - GitHub Docs](https://docs.github.com/en/rest/actions/artifacts)
