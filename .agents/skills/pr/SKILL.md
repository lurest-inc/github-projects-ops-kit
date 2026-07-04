---
name: pr
description: コード変更をコミット・プッシュして PR を作成する。実装完了後に `/pr` で呼び出す。変更ファイルを論理グループに分けて Conventional Commits 形式でコミットし、PR を自動作成する。
allowed-tools: Bash, Read
---

# PR 作成スキル

実装完了後に変更をコミット・プッシュして PR を作成するスキルです。

## 実行手順

### 1. ブランチと変更確認

```bash
git status
git diff --stat
git branch --show-current
```

現在の作業ブランチを確認します。`main` などの共有ブランチ上では直接コミットせず、作業ブランチへ移動してから続行します。

変更ファイルを確認し、以下の観点で**論理的なグループ**に分類します：

- `feat:` 新機能の追加
- `fix:` バグ修正
- `refactor:` リファクタリング
- `docs:` ドキュメント更新
- `chore:` ビルド・ツール設定など
- `ci:` CI/CD 設定変更

### 2. コミット前チェック

機密情報が diff に含まれていないかを確認します（API キー・シークレット・個人情報）。
変更内容に応じた検証:
- Bash スクリプト: `shellcheck` が利用可能なら実行
- YAML: `yamllint` / `actionlint` が利用可能なら実行
- JSON 設定: `jq . <file>` で構文確認

### 3. コミット（最大3コミット）

```bash
# 論理グループごとにファイルをステージしてコミット
git add <対象ファイル>
git commit -m "feat: 機能説明 [#issue番号]"

# 例：複数グループがある場合
git add scripts/
git commit -m "feat: ラベル設定に priority カテゴリを追加 [#123]"

git add .github/workflows/
git commit -m "ci: ラベル設定ワークフローを更新 [#123]"
```

**コミットメッセージのルール:**
- 形式: `<type>[optional scope]: <description> [#issue-number]`
- 説明は日本語で記述
- Issue 番号は関連する場合に記載

### 4. プッシュ

```bash
git push origin HEAD
```

### 5. マージ先ブランチの決定

PR を作成する前に、現在の作業ブランチとマージ先ブランチの組み合わせを確認します。

1. ユーザーからマージ先ブランチの指定がある場合は、その指定を使用する
2. 指定がない場合は、リモートのデフォルトブランチと分岐元の候補を確認する
3. 作業ブランチのコミットがどのリモートブランチを起点にしているかを、merge-base と差分から判断する
4. マージ先を一意に判断できない場合は、推測で PR を作成せず、ユーザーに確認する

```bash
HEAD_BRANCH=$(git branch --show-current)
git fetch origin --prune
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)

git for-each-ref --format='%(refname:short)' refs/remotes/origin
git merge-base HEAD "origin/${DEFAULT_BRANCH}"
git log --oneline --decorate --graph --all -30
```

決定後、以下の変数を設定し、存在するリモートブランチであることを確認します。

```bash
BASE_BRANCH="main" # 実際に決定したブランチ名へ置き換える
git show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"
```

### 6. PR 差分の確認

コミット一覧、変更ファイル、概要は、決定したマージ先ブランチとの差分から取得します。

```bash
HEAD_BRANCH=$(git branch --show-current)
ISSUE_NUM=$(echo "$HEAD_BRANCH" | grep -o '[0-9]*$' || echo "")
COMMITS=$(git log "origin/${BASE_BRANCH}..HEAD" --pretty=format:"- %s")
CHANGED_FILES=$(git diff --name-only "origin/${BASE_BRANCH}...HEAD")

git log "origin/${BASE_BRANCH}..HEAD" --oneline
git diff --stat "origin/${BASE_BRANCH}...HEAD"
```

差分が意図した内容であることを確認してから PR 作成へ進みます。

### 7. PR 本文の作成

以下の構成で本文を作成します:

```bash
CLOSES_LINE=""
[ -n "$ISSUE_NUM" ] && CLOSES_LINE="Closes #${ISSUE_NUM}"

cat > /tmp/pr-body.md <<EOF
## 概要

<変更の目的と概要>

## 変更内容

${COMMITS}

## 動作確認

- [ ] Bash スクリプトの構文確認（shellcheck、または目視）
- [ ] YAML の構文確認（yamllint / actionlint、または目視）
- [ ] JSON 設定の構文確認（jq）

## 影響範囲

<影響するスクリプト、ワークフロー、設定>

## セルフレビュー

- [x] 変更差分をセルフレビューしました

## 補足

<スコープ外、破壊的変更、手動作業、移行手順、環境変数の変更、レビュー観点。なければ「なし」>

## 関連 Issue

${CLOSES_LINE}

## ブランチ

- 作業ブランチ: \`${HEAD_BRANCH}\`
- マージ先ブランチ: \`${BASE_BRANCH}\`
- [x] 作業ブランチとマージ先ブランチの組み合わせを確認しました
EOF
```

`<...>` のプレースホルダーを実際の内容に置き換え、実施した動作確認だけを `[x]` にします（該当しない項目は「該当なし」と明記）。

### 8. PR 作成

決定したマージ先を `--base` で必ず明示します。

```bash
gh pr create \
  --title "$(git log -1 --pretty=format:'%s')" \
  --body-file /tmp/pr-body.md \
  --base "$BASE_BRANCH" \
  --head "$HEAD_BRANCH"
```

### 9. PR 作成結果の検証

PR 作成後に、実際の作業ブランチとマージ先ブランチを取得し、意図した向きで作成されたことを確認します。

```bash
gh pr view --json url,baseRefName,headRefName
```

`baseRefName` が `$BASE_BRANCH`、`headRefName` が `$HEAD_BRANCH` と一致しない場合は、完了として報告せず PR の向きを修正します。

## 重要なルール

### セキュリティチェック（コミット前）

機密情報が diff に含まれていないか必ず確認：
- API キー・シークレット
- 個人情報・顧客データ

### PR ターゲットブランチ

- ユーザー指定がある場合は、そのブランチを優先する
- 指定がない場合は、リモートのデフォルトブランチと作業ブランチの分岐元を確認して決定する
- 一意に判断できない場合は、PR を作成する前にユーザーへ確認する
- 差分比較と `gh pr create --base` には、決定した同じマージ先ブランチを使用する

## 使用タイミング

このスキルは以下の場面で使用します：

1. 実装が完了したとき
2. ユーザーが `/pr` を実行したとき
3. 「PR を作成して」と指示されたとき

## 注意事項

- コミットは**最大3つまで**（論理的なグループ分けの範囲内）
- `git add -A` や `git add .` は**機密ファイルを誤って含めるリスク**があるため、ファイルを明示的に指定すること
- ブランチ名が `issues/#<番号>` 形式の場合、Issue 番号を自動検出してコミットメッセージと PR 本文に含める
