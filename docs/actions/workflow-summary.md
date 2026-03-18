# 📊 workflow-summary アクション

ワークフローの実行結果（成功・失敗）に応じたサマリーレポートを `GitHub Actions` の Job Summary に出力する複合アクションです。
全4ワークフローの終了時ジョブで共通的に使用されています。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [📋 概要](#-%E6%A6%82%E8%A6%81)
- [⚙️ Inputs](#-inputs)
- [📤 出力内容](#-%E5%87%BA%E5%8A%9B%E5%86%85%E5%AE%B9)
  - [共通項目（成功・失敗共通）](#%E5%85%B1%E9%80%9A%E9%A0%85%E7%9B%AE%E6%88%90%E5%8A%9F%E3%83%BB%E5%A4%B1%E6%95%97%E5%85%B1%E9%80%9A)
  - [ジョブ結果セクション（`job-results` 指定時）](#%E3%82%B8%E3%83%A7%E3%83%96%E7%B5%90%E6%9E%9C%E3%82%BB%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3job-results-%E6%8C%87%E5%AE%9A%E6%99%82)
  - [失敗時の追加セクション](#%E5%A4%B1%E6%95%97%E6%99%82%E3%81%AE%E8%BF%BD%E5%8A%A0%E3%82%BB%E3%82%AF%E3%82%B7%E3%83%A7%E3%83%B3)
- [💡 使用例](#-%E4%BD%BF%E7%94%A8%E4%BE%8B)
  - [① 新規作成ワークフロー（project-number なし・複数ジョブ）](#%E2%91%A0-%E6%96%B0%E8%A6%8F%E4%BD%9C%E6%88%90%E3%83%AF%E3%83%BC%E3%82%AF%E3%83%95%E3%83%AD%E3%83%BCproject-number-%E3%81%AA%E3%81%97%E3%83%BB%E8%A4%87%E6%95%B0%E3%82%B8%E3%83%A7%E3%83%96)
  - [②③④ 既存 Project 操作ワークフロー（project-number あり・単一ジョブ）](#%E2%91%A1%E2%91%A2%E2%91%A3-%E6%97%A2%E5%AD%98-project-%E6%93%8D%E4%BD%9C%E3%83%AF%E3%83%BC%E3%82%AF%E3%83%95%E3%83%AD%E3%83%BCproject-number-%E3%81%82%E3%82%8A%E3%83%BB%E5%8D%98%E4%B8%80%E3%82%B8%E3%83%A7%E3%83%96)
- [🔄 使用ワークフロー](#-%E4%BD%BF%E7%94%A8%E3%83%AF%E3%83%BC%E3%82%AF%E3%83%95%E3%83%AD%E3%83%BC)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

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
