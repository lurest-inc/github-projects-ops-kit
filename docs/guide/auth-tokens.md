# 🔑 認証・トークンガイド

Workflow を実行するために必要な PAT（Personal Access Token）の権限設定について説明します。

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

<details><summary>（ここをクリック）目次</summary><ul>
<li><a href="#-q-pat-%E3%81%AB%E3%81%AF%E3%81%A9%E3%81%AE%E6%A8%A9%E9%99%90%E3%81%8C%E5%BF%85%E8%A6%81%E3%81%A7%E3%81%99%E3%81%8B">🔐 Q. PAT にはどの権限が必要ですか？</a></li>

<li><a href="#-q-fine-grained-token-%E3%81%A8-classic-token-%E3%81%AE%E3%81%A9%E3%81%A1%E3%82%89%E3%82%92%E4%BD%BF%E3%81%86%E3%81%B9%E3%81%8D%E3%81%A7%E3%81%99%E3%81%8B">🤔 Q. Fine-grained token と Classic token のどちらを使うべきですか？</a></li>

<li><a href="#-fine-grained-token-%E3%81%AE%E5%88%B6%E7%B4%84%E4%BA%8B%E9%A0%85">⚠️ Fine-grained token の制約事項</a></li>
</ul></details>

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

---

## 🔐 Q. PAT にはどの権限が必要ですか？

A. Workflow ごとに必要な権限が異なります。アカウントタイプとトークンタイプの組み合わせに応じて、以下の該当パターンを確認してください。

<details>
<summary>（ここをクリック）個人用アカウント × <code>Fine-grained token</code></summary>

<table>
<thead>
<tr><th>カテゴリ</th><th>権限</th><th>必要な Workflow</th></tr>
</thead>
<tbody>
<tr><td>Account permissions &gt; Projects</td><td>Read and write</td><td>①②⑤</td></tr>
<tr><td>Account permissions &gt; Projects</td><td>Read</td><td>⑥</td></tr>
<tr><td>Repository permissions &gt; Administration</td><td>Read and write</td><td>③</td></tr>
<tr><td>Repository permissions &gt; Contents</td><td>Read and write</td><td>release-please</td></tr>
<tr><td>Repository permissions &gt; Issues</td><td>Read and write</td><td>④</td></tr>
<tr><td>Repository permissions &gt; Issues</td><td>Read</td><td>⑤</td></tr>
<tr><td>Repository permissions &gt; Pull requests</td><td>Read and write</td><td>release-please</td></tr>
<tr><td>Repository permissions &gt; Pull requests</td><td>Read</td><td>⑤</td></tr>
</tbody>
</table>

<blockquote>
<strong>Note:</strong> Workflow ③（特殊 Repository 一括作成）では Repository の作成を行うため、 Administration の書き込み権限が必要です。
<br><br>
<strong>Note:</strong> Workflow ④（Label 一括追加）では Label の作成を行うため、 Issues の書き込み権限が必要です。
<br><br>
<strong>Note:</strong> Workflow ⑤（Issue/PR 一括紐付け）では対象 Repository の Issue/PR を読み取るため、 Repository の参照権限が追加で必要です。
<br><br>
<strong>Note:</strong> Workflow ⑥（統合プロジェクト分析）はプロジェクトデータの読み取りのみを行うため、 Projects は Read で十分です。
<br><br>
<strong>Note:</strong> release-please Workflow では CHANGELOG ・バージョンファイルの更新およびリリース PR の作成・更新を行うため、 Contents（Read and write）と Pull requests（Read and write）が必要です。
</blockquote>

</details>

<details>
<summary>（ここをクリック）個人用アカウント × Classic token</summary>

<table>
<thead>
<tr><th>Scope</th><th>必要な Workflow</th></tr>
</thead>
<tbody>
<tr><td><code>project</code></td><td>①②⑤⑥</td></tr>
<tr><td><code>read:org</code></td><td>①②⑤⑥</td></tr>
<tr><td><code>repo</code>（または <code>public_repo</code>）</td><td>③, ④, ⑤, release-please（対象 Repository が private の場合は <code>repo</code>）</td></tr>
</tbody>
</table>

<blockquote>
<strong>Note:</strong> Classic token では、個人用アカウント・ Organization を問わず <code>read:org</code> Scope が必要です。 Organization オーナーの場合、<code>read:org</code> が不足していると <code>gh project</code> サブコマンド実行時に <code>unknown owner type</code> エラーが発生します。
<br><br>
また、個人用アカウントオーナーの場合、<code>gh project field-create</code> が gh CLI v2.88.1 で <code>unknown owner type</code> エラーを起こす既知のバグがあります（<a href="https://github.com/mabubu0203/github-projects-starter-kit/issues/119">#119</a>、本 Repository では GraphQL API による回避策を適用済み）。
<br><br>
<strong>Note:</strong> release-please Workflow では GitHub Release の作成やタグの書き込みを行うため、<code>repo</code> Scope が必要です。<code>public_repo</code> では Contents や Pull requests の書き込み権限が含まれないため、 release-please は動作しません。
</blockquote>

</details>

<details>
<summary>（ここをクリック）Organization × <code>Fine-grained token</code></summary>

<table>
<thead>
<tr><th>カテゴリ</th><th>権限</th><th>必要な Workflow</th></tr>
</thead>
<tbody>
<tr><td>Organization permissions &gt; Projects</td><td>Read and write</td><td>①②⑤</td></tr>
<tr><td>Organization permissions &gt; Projects</td><td>Read</td><td>⑥</td></tr>
<tr><td>Repository permissions &gt; Administration</td><td>Read and write</td><td>③</td></tr>
<tr><td>Repository permissions &gt; Contents</td><td>Read and write</td><td>release-please</td></tr>
<tr><td>Repository permissions &gt; Issues</td><td>Read and write</td><td>④</td></tr>
<tr><td>Repository permissions &gt; Issues</td><td>Read</td><td>⑤</td></tr>
<tr><td>Repository permissions &gt; Pull requests</td><td>Read and write</td><td>release-please</td></tr>
<tr><td>Repository permissions &gt; Pull requests</td><td>Read</td><td>⑤</td></tr>
</tbody>
</table>

<blockquote>
<strong>Note:</strong> Workflow ③（特殊 Repository 一括作成）では Repository の作成を行うため、 Administration の書き込み権限が必要です。
<br><br>
<strong>Note:</strong> Workflow ④（Label 一括追加）では Label の作成を行うため、 Issues の書き込み権限が必要です。
<br><br>
<strong>Note:</strong> Workflow ⑤（Issue/PR 一括紐付け）では対象 Repository の Issue/PR を読み取るため、 Repository の参照権限が追加で必要です。
<br><br>
<strong>Note:</strong> Workflow ⑥（統合プロジェクト分析）はプロジェクトデータの読み取りのみを行うため、 Projects は Read で十分です。
<br><br>
<strong>Note:</strong> release-please Workflow では CHANGELOG ・バージョンファイルの更新およびリリース PR の作成・更新を行うため、 Contents（Read and write）と Pull requests（Read and write）が必要です。
</blockquote>

</details>

<details>
<summary>（ここをクリック）Organization × Classic token</summary>

<table>
<thead>
<tr><th>Scope</th><th>必要な Workflow</th></tr>
</thead>
<tbody>
<tr><td><code>project</code></td><td>①②⑤⑥</td></tr>
<tr><td><code>read:org</code></td><td>①②⑤⑥</td></tr>
<tr><td><code>repo</code>（または <code>public_repo</code>）</td><td>③, ④, ⑤, release-please（対象 Repository が private の場合は <code>repo</code>）</td></tr>
</tbody>
</table>

<blockquote>
<strong>Note:</strong> Classic token では、個人用アカウント・ Organization を問わず <code>read:org</code> Scope が必要です。 Organization オーナーの場合、<code>read:org</code> が不足していると <code>gh project</code> サブコマンド実行時に <code>unknown owner type</code> エラーが発生します。
<br><br>
<strong>Note:</strong> release-please Workflow では GitHub Release の作成やタグの書き込みを行うため、<code>repo</code> Scope が必要です。<code>public_repo</code> では Contents や Pull requests の書き込み権限が含まれないため、 release-please は動作しません。
</blockquote>

</details>

---

## 🤔 Q. Fine-grained token と Classic token のどちらを使うべきですか？

A. **`Fine-grained token` の使用を推奨します。** 理由は以下のとおりです。

- **最小権限の原則**: 必要な権限だけを細かく設定できるため、セキュリティリスクを最小限に抑えられる
- **Repository 単位のアクセス制御**: アクセスできる Repository を明示的に指定できるため、意図しない Repository への操作を防止できる
- **GitHub の推奨**: GitHub が今後推奨しているトークン形式であり、長期的なサポートが期待できる

> **参考:** `Fine-grained token` の制約事項については次のセクションを参照してください。

---

## ⚠️ Fine-grained token の制約事項

`Fine-grained token` には以下の制約があります。

- **Organization の複数指定不可**: `Fine-grained token` はリソースオーナーとして 1 つの Organization（または個人用アカウント）しか指定できない。複数 Organization の Repository を対象にする場合は、 Organization ごとに `PAT` を作成するか `Classic token` を使用する
- **個人用アカウントと Organization の横断不可**: 個人用アカウント所有 Repository と Organization 所有 Repository を 1 つの `Fine-grained token` で横断できない

> **注意:** 上記制約により、 Workflow ⑤ で異なる Organization の Repository を `target_repo` に指定する場合は、`Classic token` の使用を推奨します。
