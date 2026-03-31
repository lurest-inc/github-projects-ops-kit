# 🏢 Organization 管理者・PM・EM のための GitHub Projects 活用ガイド

**レポート自動生成。外部ツール不要でコスト削減。立ち上げ 10 分。**

GitHub Projects を導入してみたものの、継続的な運用が定着しない...。レポート作成が手作業で回らない...。チーム横断の状況把握がしづらい...。
**GitHub Projects Ops Kit** なら、標準化された運用基盤の構築から、分析・レポートの自動生成まで、マネジメントに必要な仕組みを GitHub だけで実現できます。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-github-projects-%E3%81%8C-organization-%E3%81%AB%E5%90%91%E3%81%84%E3%81%A6%E3%81%84%E3%82%8B%E7%90%86%E7%94%B1">🏗️ GitHub Projects が Organization に向いている理由</a></li>

<li><a href="#-beforeafter--%E6%89%8B%E4%BD%9C%E6%A5%AD-vs-ops-kit">⚡ Before/After — 手作業 vs Ops Kit</a></li>

<li><a href="#-%E3%81%93%E3%81%AE%E3%83%AA%E3%83%9D%E3%82%B8%E3%83%88%E3%83%AA%E3%81%8C%E8%A7%A3%E6%B1%BA%E3%81%99%E3%82%8B%E8%AA%B2%E9%A1%8C">🛠️ このリポジトリが解決する課題</a></li>

<li><a href="#-%E5%85%B7%E4%BD%93%E7%9A%84%E3%81%AA%E3%83%A6%E3%83%BC%E3%82%B9%E3%82%B1%E3%83%BC%E3%82%B9%E3%82%B7%E3%83%8A%E3%83%AA%E3%82%AA">📖 具体的なユースケースシナリオ</a></li>

<li><a href="#-workflow-%E5%AE%9F%E8%A1%8C%E3%82%A4%E3%83%A1%E3%83%BC%E3%82%B8">🖥️ Workflow 実行イメージ</a></li>

<li><a href="#-%E3%81%93%E3%82%93%E3%81%AA%E6%96%B9%E3%83%BB%E3%83%81%E3%83%BC%E3%83%A0%E3%81%AB%E3%81%8A%E3%81%99%E3%81%99%E3%82%81">🎯 こんな方・チームにおすすめ</a></li>

<li><a href="#-%E3%81%AF%E3%81%98%E3%82%81%E6%96%B9">🚀 はじめ方</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 🏗️ GitHub Projects が Organization に向いている理由

### 🔗 GitHub 上で開発とプロジェクト管理を一元化できる

コードレビュー・Issue 管理・プロジェクト進捗の把握がすべて GitHub 上で完結します。開発チームが普段使っている環境にプロジェクト管理を統合できるため、Workflow の切り替えコストがなくなります。

### 💰 外部ツール不要でコスト削減・学習コスト低減

外部のプロジェクト管理ツールを契約する必要がありません。GitHub を使い慣れたメンバーであれば追加の学習コストも最小限です。

### 🔀 複数 Repository を横断した管理が可能

Organization 配下の複数 Repository にまたがる Issue や PR を、1 つの Project ボードで横断的に管理できます。チーム全体の進捗を俯瞰するのに最適です。

---

![チーム・組織のプロジェクト運営の導入前後イメージ](../assets/images/use-case-organization.png)

## ⚡ Before/After — 手作業 vs Ops Kit

| 作業内容 | 手作業の場合 | Ops Kit の場合 |
|---|---|---|
| Project 新規作成 + Field / Status / View 設定 | 約 30〜60 分（GUI で 1 つずつ設定） | **約 1 分**（Workflow ① を実行するだけ） |
| 2 つ目以降の Project 構築 | 毎回同じ手順を繰り返し | **同じ Workflow を再実行するだけ** |
| Label の統一設定（複数 Repository） | Repository ごとに手動追加（10 分 × n 個） | **約 1 分**（Workflow ④ で一括適用） |
| 滞留タスクの検知 | 目視で Board を確認、見落としリスクあり | **自動検出 + レポート出力** |
| ベロシティ・工数レポート作成 | スプレッドシートで手動集計 | **Workflow ⑥ で自動生成** |

> 💡 **手作業では「Project 1 つ作るのに 30 分以上」かかっていた作業が、Ops Kit なら Workflow 実行の約 1 分で完了します。**

---

## 🛠️ このリポジトリが解決する課題

### 📋 GitHub Projects を導入しても継続運用が定着しない

ツールを導入しても、構成がチームごとにバラバラだと運用ルールが曖昧になり、次第に使われなくなります。

**GitHub Projects Ops Kit なら:** JSON 定義ファイルで Field・Status・View を標準化できます。Organization 全体で統一された運用基盤をコードとして管理し、誰が Project を作っても同じ構成が再現されます。運用の属人化を防ぎ、定着を促進します。

→ [Workflow ① GitHub Project 新規作成](../workflows/01-create-project.md)

### 📊 レポート作成が手作業で、定例報告に時間がかかる

スプレッドシートに手動でデータを転記し、集計する作業は時間がかかり、ミスも発生しやすくなります。週次・月次の定例報告のたびにこの作業が繰り返されます。

**GitHub Projects Ops Kit なら:** 分析 Workflow を実行するだけで、サマリーレポート・工数レポート・ベロシティレポートを自動生成できます。Artifact としてダウンロードでき、定例報告にそのまま活用できます。

→ [Workflow ⑥ 統合 Project 分析](../workflows/06-analyze-project.md)

### 🔀 チーム横断の状況把握がしづらい

複数チーム・複数 Repository が並行稼働していると、全体の進捗を俯瞰するのが困難です。滞留しているタスクの見落としリスクも高まります。

**GitHub Projects Ops Kit なら:** 複数リポジトリの Issue/PR を 1 つの Project に一括紐付けし、横断的に管理できます。滞留タスクの自動検知で、対応漏れを未然に防止できます。

→ [Workflow ⑤ Issue/PR 一括紐付け](../workflows/05-add-items-to-project.md)

### 📦 新チーム・新プロジェクトの立ち上げに工数がかかる

新チーム結成のたびに、Project の作成・Field 定義・View 設定・Label 追加・特殊リポジトリの作成を手作業で行うのは非効率です。

**GitHub Projects Ops Kit なら:** Workflow を実行するだけで、約 10 分で Project 環境が整います。特殊 Repository（`.github`・GitHub Pages 等）の一括作成にも対応しています。

→ [Workflow ② GitHub Project 拡張](../workflows/02-extend-project.md)
→ [Workflow ③ 特殊 Repository 一括作成](../workflows/03-create-special-repos.md)

---

## 📖 具体的なユースケースシナリオ

### シナリオ 1: 新チームの立ち上げ

> **状況:** 新規プロダクトの開発チーム（5 名）が結成された。Backend・Frontend・Infrastructure の 3 Repositories で開発を進める予定。プロジェクト管理はまだ決まっていない。

**Ops Kit を使った立ち上げ手順:**

1. Fork した Repository で **Workflow ①** を実行 → Project が自動作成され、Field・Status・View が即座に構成される
2. **Workflow ④** で 3 Repositories に共通の Label を一括設定
3. **Workflow ⑤** で既存の Issue/PR を Project に一括紐付け
4. チームメンバーは初日から統一された Project ボードで作業開始

**結果:** チーム立ち上げから Project 運用開始まで **約 10 分**で完了。手作業なら半日かかる構築作業が不要に。

### シナリオ 2: 複数プロジェクトの横断管理

> **状況:** Organization 内で 3 つの開発プロジェクトが並行稼働している。マネージャーとして全体の進捗を把握し、定例ミーティングで報告する必要がある。

**Ops Kit を活用した運用:**

1. 各プロジェクトを同じ Field・Status 構成で作成（Workflow ①/② で統一）
2. 週次で **Workflow ⑥** を実行し、サマリーレポート・ベロシティレポートを自動生成
3. 滞留タスクが自動検知され、対応漏れを防止

**結果:** 手動でのデータ集計が不要になり、定例報告の準備時間を大幅に削減。

---

## 🖥️ Workflow 実行イメージ

Workflow は GitHub の `Actions` タブから「Run workflow」ボタンで実行します。以下は Workflow ① 実行時のログ出力イメージです。

```
📋 Creating GitHub Project...
✅ Project "Sprint Board" created successfully (ID: PVT_xxx)

📋 Setting up project fields...
✅ Field "Priority" (SingleSelect) created
✅ Field "Estimate" (Number) created
✅ Field "Sprint" (Iteration) created

📋 Setting up project status...
✅ Status options configured: Backlog / Ready / In Progress / In Review / Done

📋 Setting up project views...
✅ View "Sprint Board" (Board) created
✅ View "Backlog" (Table) created

🎉 Project setup completed!
```

> 上記はログの概要イメージです。実際の出力は Workflow 実行時の `Actions` タブで確認できます。

---

## 🎯 こんな方・チームにおすすめ

- 外部のプロジェクト管理ツールのコストを削減し、GitHub に集約したい方
- 定例報告のレポート作成を自動化し、準備時間を短縮したいマネージャー
- 複数チーム・複数 Repository の進捗を横断的に把握したい PM / EM
- 新チーム立ち上げのたびに発生するセットアップ工数を削減したい方
- GitHub Projects の運用を標準化し、組織全体で定着させたい方

---

## 🚀 はじめ方

> **所要時間:** 約 10 分 | **前提条件:** GitHub アカウント、`GitHub Personal Access Token`（PAT）

### Step 1: Repository を Fork する

[この Repository を Fork](https://github.com/lurest-inc/github-projects-ops-kit/fork) して、自分の Organization または個人アカウントにコピーします。

### Step 2: PAT を設定する

Fork した Repository の `Settings` > `Secrets and variables` > `Actions` で `PROJECT_PAT` シークレットを登録します。

→ PAT に必要な権限の詳細は [認証・トークンガイド](../guide/auth-tokens.md) を参照

### Step 3: Workflow を実行する

`Actions` タブから Workflow ①「GitHub Project 新規作成」を選択し、「Run workflow」を実行します。

→ 入力パラメータの詳細は [クイックスタート（GUI）](../getting-started/quickstart-gui.md) または [クイックスタート（CLI）](../getting-started/quickstart-cli.md) を参照

### Step 4: 必要に応じて拡張する

Project の構築後、用途に応じて追加の Workflow を実行できます。

| やりたいこと | 実行する Workflow |
|---|---|
| Field・Status・View を追加 | [Workflow ② GitHub Project 拡張](../workflows/02-extend-project.md) |
| 特殊リポジトリを作成 | [Workflow ③ 特殊 Repository 一括作成](../workflows/03-create-special-repos.md) |
| Label を統一設定 | [Workflow ④ Label 一括設定](../workflows/04-setup-repository-labels.md) |
| Issue/PR を Project に紐付け | [Workflow ⑤ Issue/PR 一括紐付け](../workflows/05-add-items-to-project.md) |
| 進捗分析・レポート生成 | [Workflow ⑥ 統合 Project 分析](../workflows/06-analyze-project.md) |

> ❓ 困ったときは [よくある質問（FAQ）](../support/faq.md) や [トラブルシューティング](../support/troubleshooting.md) を参照してください。
