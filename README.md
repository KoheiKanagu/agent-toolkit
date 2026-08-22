# agent-toolkit

エージェントワークフローで再利用可能な共通スキル定義を集めたリポジトリ。

## 構成

```
AGENTS.md                    # 常時ロードされる共通ルール(毎ターン読まれるため厳選)
grok/
  sandbox.toml               # Grok グローバル sandbox profile（~/.grok/sandbox.toml へリンク）
  lsp/                       # Language Server 正本（dart.json / swift.json）
  copy-lsp.sh                # 正本を <repo>/.grok/lsp.json へコピーする
  permission.toml            # グローバル [permission] deny 正本（install で config.toml にマージ）
skills/
  git-workflow/SKILL.md          # コミット・push・PR 投稿・CI 監視の規約
  create-pr/SKILL.md             # PR 作成前チェックリストと body の書き方
  create-issue/SKILL.md          # issue 本文。受け入れ条件必須。プロジェクトのテンプレ優先
  review-pr/SKILL.md             # PR レビューの方法論・判断基準
  triage-issues/SKILL.md         # issue の実装可能性トリアージの判断基準
  promote-learnings/SKILL.md     # 個人のナレッジをチーム共有ナレッジへ昇格するループ
  write-agent-knowledge/SKILL.md # SKILL.md / AGENTS.md 自体の書き方(メタスキル)
  bootstrap-agent-harness/SKILL.md # 新しいリポジトリに骨格を置く（本線）
  migrate-agent-harness/SKILL.md   # Copilot / OKF / 無人ボットからの移行
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

### 一括 symlink (グローバル)

```bash
./install-copilot-links.sh   # ~/.copilot
./install-grok-links.sh      # ~/.grok
```

- **Copilot**: `AGENTS.md` → `~/.copilot/copilot-instructions.md`、`skills/` を `~/.copilot/skills` にディレクトリごとリンク
- **Grok**:
  - `AGENTS.md` → `~/.grok/AGENTS.md`
  - `grok/sandbox.toml` → `~/.grok/sandbox.toml`
  - 旧 `~/.grok/lsp.json` リンクがあれば外す（グローバル Language Server は置かない）
  - `grok/permission.toml` の `[permission]` を `~/.grok/config.toml` にマージ（他セクションは触らない）
  - `~/.grok/config.toml` に `[sandbox] profile = "workspace-safe"` を保証（他キーは触らない）
  - 各スキルを `~/.grok/skills/<name>` に個別リンク（既存の Grok 付属スキルを潰さない）

`workspace-safe` は `workspace` ベースで `**/.env` および一般的な `.env.*` 派生をカーネル deny する profile。一時的に外すときは `grok --sandbox off`。
### プロジェクト単位

グローバル `AGENTS.md`（このリポジトリ → `~/.grok/AGENTS.md`）は個人の開発方針の正本。プロジェクトへコピーしない。

1. プロジェクトの `AGENTS.md` には、そのリポジトリ固有の境界・正本・トリガーだけを書く（スキル `bootstrap-agent-harness`）
2. プロジェクト限定の手順スキルは `<repo>/.agents/skills/` に置く。toolkit のスキルはグローバルリンクで足りる
3. Language Server: `grok/copy-lsp.sh <repo> <lang> [lang ...]`（スキル `bootstrap-agent-harness`。言語は指定する。グローバルには置かない）

## 導入先の AGENTS.md で定義する値

toolkit の本文はプロジェクト依存の値をハードコードしていない。導入先の AGENTS.md に以下を定義する(未定義の項目は、エージェントが実行時にユーザーへ確認するフォールバックになる):

- デフォルトブランチ名(`main` 以外の場合の読み替え)
- 作業ブランチの命名規約
- メモリ(学習ループの記録場所)のパスと形式
- triage-issues の使用量取得手段(または件数上限)
- PR の ready 化をエージェントが行ってよいか(人間の役割か)
- Copilot レビュー完了をマージ前提にするか(未定義なら待たない。ユーザーが今回指示したときだけ待つ)
- GitHub コメントを許す owner(organization login。未定義なら認証アカウントの login のみ。確認しない)

## 注記

スキルによっては、そのドメイン固有のローカルな参考資料やヘルパースクリプトを含むことがある。
