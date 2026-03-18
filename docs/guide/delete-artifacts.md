# 🗑️ Artifact の手動削除ガイド

Workflow で生成された Artifact を手動で削除する方法を説明します。

> **Note:** Artifact の公開範囲に関する注意事項は [⑥ 統合プロジェクト分析](../workflows/06-analyze-project.md#%EF%B8%8F-artifact-%E3%81%AE%E5%85%AC%E9%96%8B%E7%AF%84%E5%9B%B2%E3%81%AB%E9%96%A2%E3%81%99%E3%82%8B%E6%B3%A8%E6%84%8F%E4%BA%8B%E9%A0%85) を参照してください。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-%E6%B3%A8%E6%84%8F%E4%BA%8B%E9%A0%85">⚠️ 注意事項</a></li>

<li><a href="#-gui-%E3%81%A7%E5%89%8A%E9%99%A4%E3%81%99%E3%82%8B">🖥️ GUI で削除する</a></li>

<li><a href="#-cli--api-%E3%81%A7%E5%89%8A%E9%99%A4%E3%81%99%E3%82%8B">💻 CLI / API で削除する</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## ⚠️ 注意事項

- 一度削除した Artifact は **復元できません**
- 削除には Repository への **Write（書き込み）アクセス** が必要です

---

## 🖥️ GUI で削除する

1. Repository の **`Actions`** タブを開く
2. 左サイドバーから対象の Workflow を選択する
3. 対象の Workflow 実行（run）をクリックしてサマリーページを開く
4. ページ下部の **Artifacts** セクションを確認する
5. 削除したい Artifact の横にある **🗑️（ゴミ箱アイコン）** をクリックする
6. 確認ダイアログで削除を承認する

---

## 💻 CLI / API で削除する

### GitHub CLI で Artifact を個別削除する

```bash
# 1. Workflow 実行の一覧を取得する
gh run list --workflow="06-analyze-project.yml"

# 2. 特定の run に紐づく Artifact を確認する
gh api repos/{owner}/{repo}/actions/runs/{run_id}/artifacts

# 3. Artifact を削除する
gh api -X DELETE repos/{owner}/{repo}/actions/runs/{run_id}/artifacts/{artifact_id}
```

### Workflow 実行ごと削除する

Workflow 実行を削除すると、紐づく Artifact も全て削除されます。

```bash
gh run delete {run_id}
```

### REST API で削除する

```
DELETE /repos/{owner}/{repo}/actions/artifacts/{artifact_id}
```

成功時のレスポンス: `204 No Content`

> **参考:** [REST API endpoints for GitHub Actions artifacts - GitHub Docs](https://docs.github.com/en/rest/actions/artifacts)
