---
name: exec-issue
description: GitHub Issue の内容に従って実装からコミット・PR 作成までを実行する。`/exec-issue <issue番号>` で呼び出す。
allowed-tools: Bash, Read, Edit, Write
---

# exec-issue スキル

GitHub Issue の内容に従ってブランチ作成・実装・コミット・PR 作成を一括で行うスキルです。

## 呼び出し方

```
/exec-issue <issue番号>
```

例: `/exec-issue 123`

引数として渡された Issue 番号を `$ARGUMENTS` として参照します。

## 実行手順

### フェーズ1: Issue 理解

1. `gh issue view "$ARGUMENTS"` で Issue に記載されている内容・ラベル・背景を理解する
2. 完了条件・スコープを把握し、不明点があればユーザーに確認する

### フェーズ2: ブランチ準備

3. `main` にチェックアウトし、pull を行い、最新のリモートの状態を取得する
4. `issues/#$ARGUMENTS` でブランチを作成、チェックアウトする

### フェーズ3: 実行計画

5. Issue の内容から実行計画を作成する（3行以内で要約）
6. 実行計画を Issue にコメントとして残す

### フェーズ4: 実装

7. 実行計画に従い実装を進める
8. 実装完了後、変更内容に応じて以下を確認する:
   - **Bash スクリプトを変更した場合**: `shellcheck` が利用可能なら実行し、なければ構文を目視で確認する
   - **YAML を変更した場合**（`.github/workflows/` 等）: `yamllint` / `actionlint` が利用可能なら実行し、なければ構文を目視で確認する
   - **JSON 設定を変更した場合**（`scripts/config/`）: `jq . <file>` で構文の妥当性を確認する
   - **`scripts/lib/common.sh` を変更した場合**: 依存する他スクリプトへの影響を確認する

### フェーズ5: コミット・PR 作成

9. Conventional Commits 形式でコミットする（最大3コミット）
   - 形式: `<type>: <説明> [#$ARGUMENTS]`
   - 例: `feat: ラベル設定に priority カテゴリを追加 [#123]`
10. `git push origin HEAD` でプッシュする
11. `/pr` スキルを使用して PR を作成する

## 参照

- @.claude/skills/pr.md
