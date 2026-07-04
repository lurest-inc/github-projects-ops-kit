---
name: fix-pr
description: GitHub Pull Request のレビュー指摘事項を確認し、修正・コミット・返信までを実行する。`/fix-pr <PR番号>` で呼び出す。
allowed-tools: Bash, Read, Edit, Write
---

# fix-pr スキル

GitHub Pull Request の未解決レビューコメントを修正し、コミット・プッシュ・返信までを行うスキルです。

## 呼び出し方

```
/fix-pr <PR番号>
```

例: `/fix-pr 45`

引数として渡された PR 番号を `$ARGUMENTS` として参照します。

## 実行手順

### フェーズ1: PR 理解とレビューコメント確認

1. PR に記載されている内容と、Resolve していないレビューコメントを理解する
   - `gh pr view "$ARGUMENTS" --comments` で PR とコメントを確認
   - 以下の GraphQL API で Resolve していないレビューコメントを取得:

   ```bash
   OWNER_REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
   OWNER=$(echo $OWNER_REPO | cut -d'/' -f1)
   REPO=$(echo $OWNER_REPO | cut -d'/' -f2)
   PR_NUMBER=$ARGUMENTS

   gh api graphql -f query="
   query {
     repository(owner: \"${OWNER}\", name: \"${REPO}\") {
       pullRequest(number: ${PR_NUMBER}) {
         reviewThreads(last: 20) {
           edges {
             node {
               isResolved
               path
               line
               comments(last: 20) {
                 nodes {
                   author { login }
                   body
                   url
                 }
               }
             }
           }
         }
       }
     }
   }" --jq '.data.repository.pullRequest.reviewThreads.edges[] | select(.node.isResolved == false)'
   ```

### フェーズ2: ブランチ準備

2. PR のブランチをチェックアウトする
   - `gh pr checkout "$ARGUMENTS"` でブランチに切り替え
   - `git pull` でリモートの最新状態を取得

### フェーズ3: 修正実装

3. レビュー指摘事項を修正する（最小限の変更で対応）
4. 修正完了後、変更内容に応じて確認する:
   - Bash スクリプトを変更した場合は `shellcheck` が利用可能なら実行する
   - YAML を変更した場合は `yamllint` / `actionlint` が利用可能なら実行する
   - JSON 設定を変更した場合は `jq . <file>` で構文を確認する

### フェーズ4: コミット・プッシュ

5. Conventional Commits 形式でコミットする
   - 例: `fix: レビュー指摘事項を修正`
6. リモートにプッシュする
   - 通常: `git push`
   - リベース/スカッシュした場合: `git push --force-with-lease`

### フェーズ5: レビューコメントへの返信

7. 各レビューコメントに修正完了の旨を返信する
8. 必要に応じて PR description を更新する
9. 新たな課題を見つければ、別途 Issue を起票する
