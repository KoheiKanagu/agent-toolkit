# agent-toolkit

エージェントワークフローで再利用可能な共通スキル定義を集めたリポジトリ。

## 構成

```
AGENTS.md                    # 常時ロードされる共通ルール(毎ターン読まれるため厳選)
skills/
  create-pr/SKILL.md             # PR 作成前チェックリストと body の書き方
  review-pr/SKILL.md             # PR レビューの方法論・判断基準
  triage-issues/SKILL.md         # issue の実装可能性トリアージの判断基準
  promote-learnings/SKILL.md     # 個人のナレッジをチーム共有ナレッジへ昇格するループ
  write-agent-knowledge/SKILL.md # SKILL.md / AGENTS.md 自体の書き方(メタスキル)
  okf/                         # OKF skill package と参考資料
  llama-cpp-tuning/            # Apple Silicon 上での llama.cpp パフォーマンス調整
```

## 執筆原則

**何を書くか** — 「モデルのデフォルト動作からの差分」だけ:

- チームの決定(規約・役割分担) — モデルには導出不可能
- 判断基準・チェックリスト — 一貫性が要件になるもの
- gotcha(失敗の補正) — モデルの一般知識がデフォルトで間違えることの記録

一般的なツールの使い方や手順は書かない。モデルが既に知っており、コンテキストを消費し、陳腐化するだけのため。

**どう書くか** — 7原則(トリガー先頭、1項目1ルール、理由は1文、❌/✅ 実例、二値テスト、I/O 契約、完了条件の明示)と検証手順は `skills/write-agent-knowledge/SKILL.md` に定義されている。このリポジトリへの追記・レビューもそのスキルに従う。

## 導入方法

1. `AGENTS.md` の内容をプロジェクトの `AGENTS.md` に統合する(または全文コピーして冒頭にプロジェクト固有事項を追記)。Claude Code 用には `CLAUDE.md → AGENTS.md` の symlink を張る
2. `skills/` を各エージェントのスキルディレクトリへ symlink する:
   - Claude Code: `.claude/skills/<name> → <toolkit>/skills/<name>`
   - Codex CLI: `.codex/skills/<name>/SKILL.md → <toolkit>/skills/<name>/SKILL.md`

## 導入先の AGENTS.md で定義する値

toolkit の本文はプロジェクト依存の値をハードコードしていない。導入先の AGENTS.md に以下を定義する(未定義の項目は、エージェントが実行時にユーザーへ確認するフォールバックになる):

- デフォルトブランチ名(`main` 以外の場合の読み替え)
- 作業ブランチの命名規約
- メモリ(学習ループの記録場所)のパスと形式
- triage-issues の使用量取得手段(または件数上限)
- PR の ready 化をエージェントが行ってよいか(人間の役割か)

## 注記

スキルによっては、そのドメイン固有のローカルな参考資料やヘルパースクリプトを含むことがある。
