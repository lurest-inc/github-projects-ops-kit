# 📊 workflow-summary アクション

<!-- START doctoc -->
<!-- END doctoc -->

ワークフローの実行結果（成功・失敗）に応じたサマリーレポートを GitHub Actions の Job Summary に出力する複合アクションです。
全4ワークフローの終了時ジョブで共通的に使用されています。

## 📋 概要

- 成功・失敗に応じたアイコン付きサマリーテーブルを出力
- 各ジョブの結果を JSON からパースして表示
- フォークリポジトリの検出と upstream 同期案内（失敗時）
- 失敗時の Issue / Discussion 起票リンクの表示

## ⚙️ Inputs

| Input | 説明 | 必須 | デフォルト |
|-------|------|:----:|-----------|
| `status` | ワークフローの結果ステータス（`success` / `failure`） | ✅ | - |
| `job-results` | 各ジョブの結果（JSON 形式、複数ジョブ時に使用） | - | `''` |
| `project-owner` | Project の所有者 | - | `''` |
| `project-number` | 対象 Project の Number | - | `''` |

## 📤 出力内容

### 共通項目（成功・失敗共通）

| 項目 | 内容 |
|------|------|
| ワークフロー名 | 実行されたワークフロー名 |
| ブランチ | トリガーされたブランチ名 |
| コミット | コミット SHA（先頭7文字） |
| 実行者 | ワークフローを実行したユーザー（プロフィールリンク付き） |
| 実行URL | Actions Run へのリンク |
| gh バージョン | 使用された `gh` CLI のバージョン |
| jq バージョン | 使用された `jq` のバージョン |
| Project Owner | Project の所有者（指定時のみ） |
| Project Number | Project の Number（指定時のみ） |

### ジョブ結果セクション（`job-results` 指定時）

`job-results` に JSON を渡すと、各ジョブの名前と結果をテーブル形式で表示します。

### 失敗時の追加セクション

- **フォーク検出:** リポジトリがフォークの場合、upstream との同期案内メッセージを表示
- **次のアクション:** Issue / Discussion の起票リンクを表示（フォーク時はフォーク元リポジトリへのリンク）

## 💡 使用例

### ① 新規作成ワークフロー（project-number なし・複数ジョブ）

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

### ②③④ 既存 Project 操作ワークフロー（project-number あり・単一ジョブ）

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

## 🔄 使用ワークフロー

- [① GitHub Project 新規作成](../workflows/01-create-project)
- [② GitHub Project 拡張](../workflows/02-extend-project)
- [③ Issue ラベル一括追加](../workflows/03-setup-repository-labels)
- [④ Issue/PR 一括紐付け](../workflows/04-add-items-to-project)
