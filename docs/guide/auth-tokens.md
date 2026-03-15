# 認証・トークンガイド

ワークフローを実行するために必要な PAT（Personal Access Token）の権限設定について説明します。

---

## PAT にはどの権限が必要ですか？

ワークフローごとに必要な権限が異なります。アカウントタイプとトークンタイプの組み合わせに応じて、以下の該当パターンを確認してください。

<details>
<summary>（ここをクリック）個人用アカウント × Fine-grained token</summary>

<table>
<thead>
<tr><th>カテゴリ</th><th>権限</th><th>必要なワークフロー</th></tr>
</thead>
<tbody>
<tr><td>Account permissions &gt; Projects</td><td>Read and write</td><td>①②③④</td></tr>
<tr><td>Repository permissions &gt; Issues</td><td>Read</td><td>③</td></tr>
<tr><td>Repository permissions &gt; Pull requests</td><td>Read</td><td>③</td></tr>
</tbody>
</table>

<blockquote>
<strong>Note:</strong> ワークフロー ③（Issue/PR 一括紐付け）では対象リポジトリの Issue/PR を読み取るため、リポジトリの参照権限が追加で必要です。
</blockquote>

</details>

<details>
<summary>（ここをクリック）個人用アカウント × Classic token</summary>

<table>
<thead>
<tr><th>スコープ</th><th>必要なワークフロー</th></tr>
</thead>
<tbody>
<tr><td><code>project</code></td><td>①②③④</td></tr>
<tr><td><code>read:org</code></td><td>①②③④</td></tr>
<tr><td><code>repo</code>（または <code>public_repo</code>）</td><td>③（対象リポジトリが private の場合は <code>repo</code>）</td></tr>
</tbody>
</table>

<blockquote>
<strong>Note:</strong> Classic token では、個人用アカウント・Organization を問わず <code>read:org</code> スコープが必要です。Organization オーナーの場合、<code>read:org</code> が不足していると <code>gh project</code> サブコマンド実行時に <code>unknown owner type</code> エラーが発生します。
<br><br>
また、個人用アカウントオーナーの場合、<code>gh project field-create</code> が gh CLI v2.88.1 で <code>unknown owner type</code> エラーを起こす既知のバグがあります（<a href="https://github.com/mabubu0203/github-projects-starter-kit/issues/119">#119</a>、本リポジトリでは GraphQL API による回避策を適用済み）。
</blockquote>

</details>

<details>
<summary>（ここをクリック）Organization × Fine-grained token</summary>

<table>
<thead>
<tr><th>カテゴリ</th><th>権限</th><th>必要なワークフロー</th></tr>
</thead>
<tbody>
<tr><td>Organization permissions &gt; Projects</td><td>Read and write</td><td>①②③④</td></tr>
<tr><td>Repository permissions &gt; Issues</td><td>Read</td><td>③</td></tr>
<tr><td>Repository permissions &gt; Pull requests</td><td>Read</td><td>③</td></tr>
</tbody>
</table>

<blockquote>
<strong>Note:</strong> ワークフロー ③（Issue/PR 一括紐付け）では対象リポジトリの Issue/PR を読み取るため、リポジトリの参照権限が追加で必要です。
</blockquote>

</details>

<details>
<summary>（ここをクリック）Organization × Classic token</summary>

<table>
<thead>
<tr><th>スコープ</th><th>必要なワークフロー</th></tr>
</thead>
<tbody>
<tr><td><code>project</code></td><td>①②③④</td></tr>
<tr><td><code>read:org</code></td><td>①②③④</td></tr>
<tr><td><code>repo</code>（または <code>public_repo</code>）</td><td>③（対象リポジトリが private の場合は <code>repo</code>）</td></tr>
</tbody>
</table>

<blockquote>
<strong>Note:</strong> Classic token では、個人用アカウント・Organization を問わず <code>read:org</code> スコープが必要です。Organization オーナーの場合、<code>read:org</code> が不足していると <code>gh project</code> サブコマンド実行時に <code>unknown owner type</code> エラーが発生します。
</blockquote>

</details>

---

## Fine-grained token と Classic token のどちらを使うべきですか？

**`Fine-grained token` の使用を推奨します。** 理由は以下のとおりです。

- **最小権限の原則**: 必要な権限だけを細かく設定できるため、セキュリティリスクを最小限に抑えられる
- **リポジトリ単位のアクセス制御**: アクセスできるリポジトリを明示的に指定できるため、意図しないリポジトリへの操作を防止できる
- **GitHub の推奨**: GitHub が今後推奨しているトークン形式であり、長期的なサポートが期待できる

> **参考:** `Fine-grained token` の制約事項については次のセクションを参照してください。

---

## Fine-grained token の制約事項

`Fine-grained token` には以下の制約があります。

- **Organization の複数指定不可**: `Fine-grained token` はリソースオーナーとして 1 つの Organization（または個人用アカウント）しか指定できない。複数 Organization のリポジトリを対象にする場合は、Organization ごとに `PAT` を作成するか `Classic token` を使用する
- **個人用アカウントと Organization の横断不可**: 個人用アカウント所有リポジトリと Organization 所有リポジトリを 1 つの `Fine-grained token` で横断できない

> **注意:** 上記制約により、ワークフロー ③ で異なる Organization のリポジトリを `target_repo` に指定する場合は、`Classic token` の使用を推奨します。
