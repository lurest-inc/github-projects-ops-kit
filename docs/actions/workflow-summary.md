# 📊 workflow-summary アクション

Workflow の実行結果（成功・失敗）に応じたサマリーレポートを `GitHub Actions` の Job Summary に出力する複合アクションです。
全4 Workflow の終了時 Job で共通的に使用されています。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-%E6%A6%82%E8%A6%81">📋 概要</a></li>

<li><a href="#-inputs">⚙️ Inputs</a></li>

<li><a href="#-%E5%87%BA%E5%8A%9B%E5%86%85%E5%AE%B9">📤 出力内容</a></li>

<li><a href="#-%E4%BD%BF%E7%94%A8%E4%BE%8B">💡 使用例</a></li>

<li><a href="#-%E4%BD%BF%E7%94%A8-workflow">🔄 使用 Workflow</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## 📋 概要

- 成功・失敗に応じたアイコン付きサマリーテーブルを出力
- 各 Job の結果を JSON からパースして表示
- Fork Repository の検出と upstream 同期案内（失敗時）
- 失敗時の Issue / Discussion 起票リンクの表示

## ⚙️ Inputs

| Input | 説明 | 必須 | デフォルト |
|-------|------|:----:|-----------|
| `status` | Workflow の結果 Status（`success` / `failure`） | ✅ | - |
| `job-results` | 各 Job の結果（JSON 形式、複数 Job 時に使用） | - | `''` |
| `project-owner` | Project の所有者 | - | `''` |
| `project-number` | 対象 Project の Number | - | `''` |

## 📤 出力内容

### 共通項目（成功・失敗共通）

| 項目 | 内容 |
|------|------|
| Workflow 名 | 実行された Workflow 名 |
| ブランチ | トリガーされた Branch 名 |
| コミット | Commit SHA（先頭7文字） |
| 実行者 | Workflow を実行したユーザー（プロフィールリンク付き） |
| 実行 URL | Actions Run へのリンク |
| gh バージョン | 使用された `gh` CLI のバージョン |
| jq バージョン | 使用された `jq` のバージョン |
| Project Owner | Project の所有者（指定時のみ） |
| Project Number | Project の Number（指定時のみ） |

### Job 結果セクション（`job-results` 指定時）

`job-results` に JSON を渡すと、各 Job の名前と結果をテーブル形式で表示します。

### 失敗時の追加セクション

- **Fork 検出:** Repository が Fork の場合、 upstream との同期案内メッセージを表示
- **次のアクション:** Issue / Discussion の起票リンクを表示（Fork 時は Fork 元 Repository へのリンク）

## 💡 使用例

### ① 新規作成 Workflow（project-number なし・複数 Job）

```yaml
- name: 成功サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: success
    project-owner: ${{ github.repository_owner }}
    job-results: |
      {"create-project": "${{ needs.create-project.result }}", "extend-project": "${{ needs.extend-project.result }}"}

- name: 失敗サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: failure
    project-owner: ${{ github.repository_owner }}
    job-results: |
      {"create-project": "${{ needs.create-project.result }}", "extend-project": "${{ needs.extend-project.result }}"}
```

### ②③④ 既存 Project 操作 Workflow（project-number あり・単一 Job）

```yaml
- name: 成功サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: success
    project-owner: ${{ github.repository_owner }}
    project-number: ${{ inputs.project_number }}
    job-results: |
      {"extend-project": "${{ needs.extend-project.result }}"}

- name: 失敗サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: failure
    project-owner: ${{ github.repository_owner }}
    project-number: ${{ inputs.project_number }}
    job-results: |
      {"extend-project": "${{ needs.extend-project.result }}"}
```

## 🔄 使用 Workflow

- [① GitHub Project 新規作成](../workflows/01-create-project)
- [② GitHub Project 拡張](../workflows/02-extend-project)
- [③ Issue Label 一括追加](../workflows/03-setup-repository-labels)
- [④ Issue/PR 一括紐付け](../workflows/04-add-items-to-project)
