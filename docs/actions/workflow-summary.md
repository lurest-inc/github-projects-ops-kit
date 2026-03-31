# 📊 workflow-summary アクション

Workflow の実行結果（成功・失敗）に応じたサマリーレポートを `GitHub Actions` の Job Summary に出力する複合アクションです。
全 Workflow の終了時 Job で共通的に使用されています。

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

### ②⑥ 既存 Project 操作 Workflow（project-number あり・主処理 Job が1つ）

② GitHub Project 拡張の例：

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

⑥ Issue/PR 一括紐付けの例：

```yaml
- name: 成功サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: success
    project-owner: ${{ github.repository_owner }}
    project-number: ${{ inputs.project_number }}
    job-results: |
      {"add-items": "${{ needs.add-items.result }}"}

- name: 失敗サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: failure
    project-owner: ${{ github.repository_owner }}
    project-number: ${{ inputs.project_number }}
    job-results: |
      {"add-items": "${{ needs.add-items.result }}"}
```

### ③④⑤ Workflow（project-number なし・主処理 Job が1つ）

③ 特殊 Repository 一括作成の例：

```yaml
- name: 成功サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: success
    project-owner: ${{ github.repository_owner }}
    job-results: |
      {"create-special-repos": "${{ needs.create-special-repos.result }}"}

- name: 失敗サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: failure
    project-owner: ${{ github.repository_owner }}
    job-results: |
      {"create-special-repos": "${{ needs.create-special-repos.result }}"}
```

④ Issue Label 一括作成の例：

```yaml
- name: 成功サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: success
    project-owner: ${{ github.repository_owner }}
    job-results: |
      {"setup-repository-labels": "${{ needs.setup-repository-labels.result }}"}

- name: 失敗サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: failure
    project-owner: ${{ github.repository_owner }}
    job-results: |
      {"setup-repository-labels": "${{ needs.setup-repository-labels.result }}"}
```

⑤ 初期ファイル一括作成の例：

```yaml
- name: 成功サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: success
    project-owner: ${{ github.repository_owner }}
    job-results: |
      {"setup-repository-health-files": "${{ needs.setup-repository-health-files.result }}", "setup-repository-scaffold-files": "${{ needs.setup-repository-scaffold-files.result }}"}

- name: 失敗サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: failure
    project-owner: ${{ github.repository_owner }}
    job-results: |
      {"setup-repository-health-files": "${{ needs.setup-repository-health-files.result }}", "setup-repository-scaffold-files": "${{ needs.setup-repository-scaffold-files.result }}"}
```

### ⑦ 統合 Project 分析 Workflow（project-number あり・複数 Job）

```yaml
- name: 成功サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: success
    project-owner: ${{ github.repository_owner }}
    project-number: ${{ inputs.project_number }}
    job-results: |
      {"generate-summary-report": "${{ needs.generate-summary-report.result }}", "generate-effort-report": "${{ needs.generate-effort-report.result }}", "generate-velocity-report": "${{ needs.generate-velocity-report.result }}", "detect-stale-items": "${{ needs.detect-stale-items.result }}", "export-items": "${{ needs.export-items.result }}"}

- name: 失敗サマリーを出力
  uses: ./.github/actions/workflow-summary
  with:
    status: failure
    project-owner: ${{ github.repository_owner }}
    project-number: ${{ inputs.project_number }}
    job-results: |
      {"generate-summary-report": "${{ needs.generate-summary-report.result }}", "generate-effort-report": "${{ needs.generate-effort-report.result }}", "generate-velocity-report": "${{ needs.generate-velocity-report.result }}", "detect-stale-items": "${{ needs.detect-stale-items.result }}", "export-items": "${{ needs.export-items.result }}"}
```

## 🔄 使用 Workflow

- [① GitHub Project 新規作成](../workflows/01-create-project.md)
- [② GitHub Project 拡張](../workflows/02-extend-project.md)
- [③ 特殊 Repository 一括作成](../workflows/03-create-special-repos.md)
- [④ Issue Label 一括作成](../workflows/04-setup-repository-labels.md)
- [⑤ 初期ファイル一括作成](../workflows/05-setup-repository-files.md)
- [⑥ Issue/PR 一括紐付け](../workflows/06-add-items-to-project.md)
- [⑦ 統合 Project 分析](../workflows/07-analyze-project.md)
