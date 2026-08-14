---
name: migrate-agent-harness
description: >
  Copilot / Cursor / OKF / 無人 AI ボットがある既存リポジトリを、Grok 向け骨格へ移す。
  「Copilot から移行」「OKF を書き直して」「gh-aw を外して」で起動。
  新しいリポジトリの立ち上げは bootstrap-agent-harness。文面の書き方だけなら write-agent-knowledge。
---

# 既存リポジトリのエージェント面を移す

骨格の置き方・`check-work` 契約・docs の層・グローバル vs プロジェクト `AGENTS.md` の分担は `bootstrap-agent-harness` が正。本スキルは **掃除と変換の手順** だけ。

**OKF**: YAML frontmatter 付き・1 ファイル 1 概念の旧 docs 形式。

## 出力の契約

報告に「残す / 捨てる / 書き直す」表がある。**ベンダー面削除・OKF 全変換・無人ボット削除**が未合意なら表で止まり、ファイルは変えない。

合意後: `bootstrap-agent-harness` の成果物表を満たす。機械的 CI は残っている。製品コードは変えない。文脈なし検証の穴を埋めた。

## 手順

1. **棚卸し**: 常時指示（プロジェクト `AGENTS.md` / `.github/copilot-instructions.md` / `CLAUDE.md`）、スキル（`.github/skills` / `.agents/skills` / `.claude/skills`）、docs 形式、Actions を **機械的 CI** と **無人 AI ボット** に分ける。
2. **表を出す**。未合意なら止まる。
3. **docs を先に置く**（`bootstrap-agent-harness`）。旧パスを消すのは新正本のあと。既存の A 層の事実は落とさず、この移行と同じコミット列で書き切る。
4. **プロジェクト `AGENTS.md` と `.agents/skills/`**。ベンダー常時指示の **プロジェクト固有差分だけ** を移す。個人方針はグローバルに既にある前提で再掲しない。グローバル `AGENTS.md` はこのスキルでは編集しない。
5. **合意済みならベンダー面を消す**。スキルは `.agents/skills/` へ移してから `.github/skills` を消す。両方は残さない。
6. **参照漏れ** をリポジトリ全体で grep（旧 docs パス、`copilot-instructions`、`.github/skills`、消したボット名）。
7. **検証**: `write-agent-knowledge`。シナリオは今回触った変換から 2〜4。
8. 論理単位でコミット。push は明示があるまでしない。

## 判断基準

### 残す

- **機械的 CI**: unit / lint / build / rules **テスト**。消さない。元からないなら新設しない。
- **製品 rules 本体**（例: `firebase/firestore.rules`）: 移行では変えない。それを回す workflow は CI。

### 捨てる（合意後）

- **無人 AI ボット**: スケジュールや PR で別エージェントが勝手に動くもの（GitHub Agentic Workflows の `*.md` + `*.lock.yml`、日次 PM、自動簡略化）。Dependabot・CodeQL・人間が依頼する Copilot レビューはボットではない。検査観点が要るなら `check-work` に移してから消す。
- **ベンダー常時指示**: `.github/copilot-instructions.md`、重複する `CLAUDE.md`。固有差分はプロジェクト `AGENTS.md` へ。`.claude/skills` は `.agents/skills` へ寄せてから消す。
- **OKF を書き足す**: しない。既存は合意後に A/B へ書き切る。既存の C（画面文言・理想ツリー等）は消す。

### 他リポジトリの AGENTS.md をコピーしろと言われたとき

コピーしない。`bootstrap-agent-harness` どおり揃え先の固有差分だけ書く、と返して手順 1 からやる。

## 完了条件

- [ ] 表を出した。未合意なら止まった
- [ ] 合意後なら `bootstrap-agent-harness` の成果物表を満たした
- [ ] 機械的 CI を消していない
- [ ] グローバル方針をプロジェクトへ複製していない
- [ ] 文脈なし検証の穴を埋めた（ファイルを変えた場合）
