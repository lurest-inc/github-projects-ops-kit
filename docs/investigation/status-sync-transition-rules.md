# 🔄 ステータス自動同期 — 遷移ルール定義書

<!-- START doctoc -->
<!-- END doctoc -->

本ドキュメントは、Issue/PR のライフサイクルイベントに連動して GitHub Project のステータスを自動更新するための遷移ルールを定義する。

関連 Issue: [#187](https://github.com/mabubu0203/github-projects-starter-kit/issues/187)

---

## 前提

### 対象ステータス

[`project-status-options.json`](../../scripts/config/project-status-options.json) で定義された 5 ステータスを使用する。

| ステータス | 色 | 説明 |
|-----------|-----|------|
| **Backlog** | GRAY | バックログ |
| **Todo** | BLUE | 着手予定 |
| **In Progress** | YELLOW | 作業中 |
| **In Review** | ORANGE | レビュー中 |
| **Done** | GREEN | 完了 |

### 設計方針

- **2 層アーキテクチャ**: 本リポジトリのセットアップワークフロー（⑥）が対象リポジトリにイベント駆動ワークフローを PR として配置する。詳細は[ワークフロー入出力仕様書](status-sync-workflow-spec.md)を参照
- **イベント駆動**（対象リポジトリ側）: `on: issues` / `on: pull_request` / `on: pull_request_review` をトリガーとする
- **前方遷移のみ**: ステータスの逆方向遷移（例: Done → In Progress）は原則行わない。以下の 2 ケースのみ例外として許可する
  - `In Review → In Progress`: レビューでの差し戻し（`changes_requested`）
  - `Done → Todo`: Issue の再オープン（`reopened`）
- **既存運用との整合**: [運用ルール](../guide/kanban-rules.md) に定義されたカンバンフローに準拠する

---

## 遷移ルール

### Issue イベント (`on: issues`)

| イベント | activity type | 遷移先 | 条件 | 備考 |
|---------|--------------|--------|------|------|
| Issue オープン | `opened` | Backlog | — | 新規 Issue の初期ステータス |
| Issue クローズ | `closed` | Done | — | `state_reason` に関わらず Done（`completed` / `not_planned` / `null` いずれも同一扱い） |
| Issue 再オープン | `reopened` | Todo | — | 再対応が必要になったため Todo に戻す |

### Pull Request イベント (`on: pull_request`)

| イベント | activity type | 遷移先 | 条件 | 備考 |
|---------|--------------|--------|------|------|
| PR オープン | `opened` | In Progress | — | PR 作成 = 作業開始と見なす |
| PR レビューリクエスト | `review_requested` | In Review | — | レビュー依頼 = レビュー中 |
| PR ドラフト化 | `converted_to_draft` | In Progress | — | ドラフトに戻した = 作業中 |
| PR Ready for Review | `ready_for_review` | In Review | — | ドラフト解除 = レビュー待ち |
| PR マージ | `closed` | Done | `merged == true` | マージによるクローズ |
| PR クローズ（マージなし） | `closed` | Done | `merged == false` | 破棄された PR も Done 扱い |

### Pull Request レビューイベント (`on: pull_request_review`)

| イベント | review state | 遷移先 | 条件 | 備考 |
|---------|-------------|--------|------|------|
| レビュー承認 | `approved` | — | — | ステータス変更なし（マージを待つ） |
| 変更リクエスト | `changes_requested` | In Progress | — | 差し戻し = 修正作業が必要 |

### 紐付け Issue の連動遷移

PR イベントおよび PR レビューイベント発生時、紐付けられた Issue のステータスも連動して更新する。

| PR イベント | 紐付け Issue の遷移先 | 備考 |
|------------|---------------------|------|
| PR オープン | In Progress | 作業着手 |
| PR マージ | Done | タスク完了 |
| 変更リクエスト | In Progress | 差し戻し |

> **注意**: 紐付け Issue の検出には、PR の `closing references`（`Closes #123` 等）を使用する。
> GitHub GraphQL API の `closingIssuesReferences` フィールドで取得可能。

---

## 遷移の優先順位

同一アイテムに対して複数のイベントが短時間で発生した場合、以下の優先順位に従う。

1. **Done** — 最優先（クローズ・マージは確定的な終了操作）
2. **In Review** — レビュー中は作業中より優先
3. **In Progress** — 作業中
4. **Todo** — 再オープン時のみ
5. **Backlog** — 新規作成時のみ

---

## 前方遷移ガード

ステータスの後退を防ぐため、以下のガードルールを設ける。

| 現在のステータス | 許可する遷移先 |
|----------------|--------------|
| Backlog | Todo, In Progress, In Review, Done |
| Todo | In Progress, In Review, Done |
| In Progress | In Review, Done |
| In Review | In Progress（差し戻し時のみ）, Done |
| Done | Todo（再オープン時のみ） |

> **例外**: `changes_requested` による `In Review → In Progress` は明示的な差し戻しであるため許可する。

---

## 複数プロジェクトへの帰属

同一 Issue/PR が複数の Project に属する場合：

- **全プロジェクトに対して遷移ルールを適用する**
- GraphQL API の `projectItems` フィールドでアイテムが属する全プロジェクトの Item ID を取得できる
- 各プロジェクトの Status フィールド ID・Option ID は異なるため、プロジェクトごとに解決が必要

```graphql
query($nodeId: ID!) {
  node(id: $nodeId) {
    ... on Issue {
      projectItems(first: 100) {
        nodes {
          id
          project { id number title }
          fieldValueByName(name: "Status") {
            ... on ProjectV2ItemFieldSingleSelectValue {
              name
              optionId
            }
          }
        }
      }
    }
  }
}
```
