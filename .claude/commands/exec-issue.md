# 内容

`gh issue view $ARGUMENTS` でGitHubのIssueの内容を確認し、タスクの遂行を行なってください。
タスクは以下の手順で進めてください。コメントなどは全て日本語でお願いします。

## フェーズ1: Issue理解と校正

1. ClaudeCode: Issueに記載されている内容を理解する

## フェーズ2: ブランチ準備

2. ClaudeCode: `main` にチェックアウトし、pullを行い、最新のリモートの状態を取得する
3. ClaudeCode: `issues/#$ARGUMENTS` でブランチを作成、チェックアウトする

## フェーズ3: タスク計画

4. ClaudeCode: 実行計画を適宜Issueにコメントとして残す

## フェーズ4: 実装

5. ClaudeCode: 独立したサブタスクが2件以上あるかを確認する

## フェーズ5: コミット・プッシュ

6. ClaudeCode: Conventional Commits形式のコミットメッセージを作成し、適切な粒度でコミットを作成する

## フェーズ6: PRと課題作成

7. ClaudeCode: 課題を見つければ、別途Issueを起票する
8. ClaudeCode: PRを作成