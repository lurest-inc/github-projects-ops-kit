# ③ 🏷️ Issue ラベル一括追加

指定リポジトリに対して、設定ファイルで定義した Issue ラベルを一括作成します。
既存ラベルと同名のラベルが存在する場合はスキップします。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [✅ 前提](#-%E5%89%8D%E6%8F%90)
- [📖 使い方](#-%E4%BD%BF%E3%81%84%E6%96%B9)
- [⚙️ パラメータ](#-%E3%83%91%E3%83%A9%E3%83%A1%E3%83%BC%E3%82%BF)
- [📊 処理フロー](#-%E5%87%A6%E7%90%86%E3%83%95%E3%83%AD%E3%83%BC)
- [🔧 ワークフロー仕様](#-%E3%83%AF%E3%83%BC%E3%82%AF%E3%83%95%E3%83%AD%E3%83%BC%E4%BB%95%E6%A7%98)
  - [ファイル](#%E3%83%95%E3%82%A1%E3%82%A4%E3%83%AB)
  - [トリガー](#%E3%83%88%E3%83%AA%E3%82%AC%E3%83%BC)
  - [環境変数](#%E7%92%B0%E5%A2%83%E5%A4%89%E6%95%B0)
  - [ジョブ構成](#%E3%82%B8%E3%83%A7%E3%83%96%E6%A7%8B%E6%88%90)
- [📜 関連スクリプト](#-%E9%96%A2%E9%80%A3%E3%82%B9%E3%82%AF%E3%83%AA%E3%83%97%E3%83%88)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## ✅ 前提

このワークフローを実行する前に、クイックスタートを完了してください。

- [クイックスタート（GUI）](../quickstart-gui)
- [クイックスタート（CLI）](../quickstart-cli)

## 📖 使い方

1. `Actions` タブを開く
2. `③ Issue ラベル一括追加` を選択
3. `Run workflow` をクリック
4. パラメータを入力して実行

## ⚙️ パラメータ

| パラメータ | 説明 | 必須 | タイプ | 例 |
|------------|------|:----:|--------|-----|
| `target_repo` | 対象リポジトリ（owner/repo 形式） | ✅ | `string` | `myorg/myrepo` |

> **Note:** 既存ラベルと同名のラベルが存在する場合はスキップされます。定義ファイルに含まれない既存ラベルは削除されません。追加のみの安全設計です。

## 📊 処理フロー

```mermaid
flowchart TD
    A["workflow_dispatch\n（target_repo）"] --> B["setup-repository-labels ジョブ\nラベル定義ファイルを読み込み\n対象リポジトリにラベルを一括作成"]
    B --> C{"結果判定"}
    C -- "成功" --> D["workflow-summary-success ジョブ\n成功サマリーを出力"]
    C -- "失敗" --> E["workflow-summary-failure ジョブ\n失敗サマリーを出力"]
```

## 🔧 ワークフロー仕様

### ファイル

`.github/workflows/03-setup-repository-labels.yml`

### トリガー

`workflow_dispatch`（手動実行）

### 環境変数

| 環境変数 | ソース | 説明 |
|----------|--------|------|
| `GH_TOKEN` | `secrets.PROJECT_PAT` | GitHub PAT（`repo` または `public_repo` スコープ） |
| `TARGET_REPO` | `inputs.target_repo` | 対象リポジトリ |

### ジョブ構成

```
.github/workflows/03-setup-repository-labels.yml
  ├── setup-repository-labels ジョブ
  │   └── scripts/setup-repository-labels.sh    # ラベル一括作成
  ├── workflow-summary-failure ジョブ（失敗時）
  │   └── .github/actions/workflow-summary       # 失敗サマリー出力
  └── workflow-summary-success ジョブ（成功時）
      └── .github/actions/workflow-summary       # 成功サマリー出力
```

## 📜 関連スクリプト

- [setup-repository-labels.sh](../scripts/setup-repository-labels) — ラベル一括作成スクリプト
