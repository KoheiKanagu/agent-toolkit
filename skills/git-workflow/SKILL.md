---
name: git-workflow
description: コミット、作業ブランチ、worktree、push、rebase、stacked PR、PR body 更新、GitHub への投稿、CI / デプロイ監視のときの git / GitHub 規約。「コミットして」「push して」「ブランチ切って」「CI 見て」「PR 本文を直して」で起動。PR の新規作成そのものは create-pr。差分のレビューは review-pr。コードを書くだけの作業では使わない。
---

# git / GitHub / CI

## 出力の契約

該当する判断基準を、その作業に入る前に適用する。ルールに完了条件がある項目は、それを満たして完了とする。PR の新規作成はこのファイルだけでは完了にせず、`skills/create-pr` に渡す。

## 判断基準

`origin/main` はリモートのデフォルトブランチ。導入先の AGENTS.md で別名が定義されていればそちら。未定義なら `origin/main`。

### コミットと push

- 1変更 = 1論理コミット。
- **worktree・作業ブランチを作るとき**: 起点は必ず `origin/main`(リモート ref)。ローカルの `main` は未 push コミットを含むことがあり、PR の diff に混入する。
- **デフォルトブランチ上で既に変更・コミットしてしまったとき**: 現 HEAD から作業ブランチを切って退避し、ローカルのデフォルトブランチを origin に揃え直す。
- **worktree を作るとき**: 配置先は `../worktrees/<リポジトリ名>/<issue番号 or ブランチ名>` にする。リポジトリ外に置くことで、誤って本体の worktree や gitignore に混入するのを防ぐ。
- **push する前**(履歴書き換え(amend・rebase)をしたら、次の push の前に再確認): ベース汚染を確認する。`git fetch origin <base>` してから、次の両方を満たして完了とする — (1) `git diff --name-only origin/<base>...HEAD` にこの PR が触るはずのないパスがない、(2) `git cherry origin/<base> HEAD` に `-` で始まる行がない(ベースと patch 等価な重複コミット — 誤った rebase/reset がマージ済みの作業を再導入した印)。どちらかに該当したら rebase で取り除いてから push する。
- **stacked PR を rebase するとき**: 依存 PR がマージされたら、`git rebase --onto` の前に必ず `git fetch origin <base>`。古い base への rebase は依存のマージ済み変更を無言で落とす(rebase は自分の diff しか replay しない)。rebase 後、依存のシンボルが HEAD に残っていることを grep で確認して完了とする。
- **stacked PR の下層ブランチに修正を入れたあと、上層を載せ直すとき**: 上層を毎回フル cascade rebase しない。各上層はその層の独自コミットだけ `git rebase --onto <修正後の下層 tip> <修正前の下層 tip>`(または同等)で載せ、下から順に行う。全体 cascade はコンフリクト連鎖などで必要になったときだけ。理由: 下層の小さな修正で全 PR の CI を焼き直すのを防ぐ。
- **push するとき**: コミットを溜めて1回で push する。push ごとに CI とレビューが走るため。

### 長時間ジョブの監視

- **デプロイ・CI・データ移行などを起動したとき**: 終端状態(成功/失敗/タイムアウト)まで監視し、結果とエラー内容を報告して完了とする。「トリガーした」という報告で作業を終えない。
- **監視対象を選ぶとき**: 実際のジョブ機構(workflow run、パイプライン実行)を特定してその状態を見る。推測した下流の効果(デプロイ後のリソース状態など)を代わりに見ない — 別の原因でも変化し、誤判定する。
- **ポーリングループを書くとき**: break 条件に「終端状態」か「回数上限」を必ず含める。「特定の名前のチェックが現れたら」のような、永遠に満たされない可能性のある条件だけで待たない。
- **PR の CI 完了を待つとき**: その PR で実際に登録された必須チェックだけを待つ。docs のみ等で analyze/test が走らないときは「走らない＝失敗」とみなさない。完了判定は最新の required check 群だけで行い、古い fail run を最新成功と取り違えない。理由: path フィルタやスキップで永遠に pending/fail 判定になり得る。
- **CI に赤いチェックを見つけたとき**: conclusion を確認してから対処する。`cancelled` は失敗ではない(連続イベントで concurrency group が古い run を止めた痕跡)。最新の run が成功していれば対処不要。

### GitHub 操作

- **PR body を更新するとき**: 最新の body を取得し、必要なセクションだけを差分編集する。他者・bot の編集や、人間が添付した画像・動画を上書きで消さない。
- **`#` + 数字を含むテキストを投稿するとき**: 裸の `#6` はその番号の PR/issue へ自動リンクされる。順序数は出力言語の序数表現(「6番」/ "No. 6")かインラインコード(`` `#6` ``)で書き、投稿前に裸の `#<数字>` の紛れ込みを確認する。
- **レビューの承認状況を判断するとき**: review の state(`APPROVED` / `CHANGES_REQUESTED` / `COMMENTED`)だけを根拠にする。本文の文言は根拠にしない(「approve 済み」と書かれた `COMMENTED` レビューが実在する)。レビュアーごとに最新の state が有効で、新しいコミットが push されたら古い `APPROVED` は stale。
- **PR に Copilot コードレビューを依頼するとき**: REST `requested_reviewers` で依頼が乗らない／空のときは GraphQL `requestReviews` の `botIds` を使う。`@copilot` の Issue コメントは使わない。詳細コマンドは導入先の skill / agent-memory を正本とする。理由: REST は成功レスポンスに見えても依頼が乗らないことがある。
- **Copilot レビューの通過・完了を判断するとき、または Copilot 待ちのあとマージするとき**: 対象 PR に対して `skills/git-workflow/scripts/wait-copilot-review.sh`(導入後は `~/.grok/skills/git-workflow/scripts/wait-copilot-review.sh`)を実行し、その終了コードだけで判定して完了とする。導入先の AGENTS.md が Copilot 待ちをマージ前提にしておらず、ユーザーも今回それを指示していないなら、このルールは適用しない。理由: `reviewDecision` や未到着の行コメント 0 件を通ったと読む事故が実在する。
  - ❌ `reviewDecision`・`mergeable`・レビュー配列の目視・セルフレビューを通った根拠にする
  - ✅ 対象 PR へのスクリプト終了コード 0 だけを通ったとする
- **待ちスクリプトの終了コードが 1 のとき**: 指摘を直して CI を通してから再依頼する。終了コード 0 になるまでマージしない。
- **待ちスクリプトの終了コードが 2 のとき**: マージしない。標準出力の `FAIL_NOT_REQUESTED` なら GraphQL `botIds` で取り直し、`FAIL_TIMEOUT` / `FAIL_PENDING` なら報告する。
- **「Copilot を最大 N 回」など回数上限付きでレビューを回すとき**: (1) line comment が 0 なら再依頼せず打ち切る (2) 指摘があれば直して CI を通してから次の依頼。理由: 指摘ゼロの再依頼は overview だけになりやすく、直す前の再依頼は同じ指摘の繰り返しになる。
- **マージ済みかを判断するとき**: fetch 済みの `origin/main`(`git grep <symbol> origin/main` 等)と issue tracker / PR の state を根拠にする。ドキュメント内の status 表記とローカルの main checkout は stale になり得るので根拠にしない。
