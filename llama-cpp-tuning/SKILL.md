---
name: llama-cpp-tuning
description: Tune llama.cpp inference parameters for a specific model and hardware. Use when the user wants to optimize llama.cpp performance, find good parameters for llama-bench or llama-server, or benchmark a GGUF model on Apple Silicon.
license: Proprietary
compatibility: Requires llama.cpp (llama-bench, llama-server) installed. Designed for Apple Silicon Macs with Unified Memory. Works with GGUF models from local files or Hugging Face.
metadata:
  author: kingu
  version: "1.0.0"
  focus: llama.cpp only
  tested-with: "llama.cpp build 9870 (ggml 0.15.3)"
  last-verified: "2026-07-05"
---

# llama.cpp パフォーマンスチューニング

## 目的

指定されたGGUFモデルに対して、llama.cpp（`llama-bench` / `llama-server`）の最適な推論パラメータを見つける。

## いつ使うか

- 新しいモデルを動かすとき
- `llama-bench` や `llama-server` のパラメータを最適化したいとき
- Apple Silicon Mac での推論速度を改善したいとき
- コーディングエージェントなど、特定の用途に最適な設定を探したいとき

## 前提条件

- `llama-bench` と `llama-server` が使用可能
- モデルは GGUF 形式、または Hugging Face 上の GGUF リポジトリ
- 十分なディスク容量とメモリ

## 基本方針

1. **ベースラインを測る**: デフォルトパラメータで `llama-bench` を実行
2. **パラメータをスイープ**: スレッド数、バッチサイズ、Flash Attention を試す
3. **実運用で検証**: `llama-server` を立ち上げ、API経由で実レイテンシを計測
4. **用途に合わせて選定**: プロンプト処理重視か生成重視かで最適値が変わる

## 推奨する初期値（出発点）

```bash
llama-server -hf <model-repo> \
  -t <physical-cores> \
  -fa auto \
  -b 2048 -ub 2048 \
  -ngl -1 \
  -c 16384 \
  -np 1 \
  --port 8080 --host 127.0.0.1
```

- `-t`: 物理コア数
- `-fa auto`: まず自動設定で試す
- `-b 2048 -ub 2048`: Apple Silicon では長文プロンプトで効きやすい
- `-ngl -1`: メモリに収まるなら全GPU載せ
- `-c 16384`: コーディング用途の現実的な初期値

## 詳細手順

詳細なステップバイステップ手順は [references/PROCEDURE.md](references/PROCEDURE.md) を参照。

## コマンド例

具体的なコマンドとテンプレートは [references/EXAMPLES.md](references/EXAMPLES.md) を参照。

## チェックリスト

実行時のチェックリストは [references/CHECKLIST.md](references/CHECKLIST.md) を参照。

## 重要な注意点

- **熱スロットリング**: 連続ベンチマークでは性能が低下する。各実行間に30〜60秒の冷却時間を設ける。
- **測定のばらつき**: 同じ設定でも ±10% 程度変動する。大きな差（>20%）が出た場合のみ判断材料とする。
- **llama-bench と llama-server の違い**: `llama-bench` は理想値、`llama-server` は実APIのオーバーヘッド込み。
- **モデル依存**: 得られた結果は他のモデルにそのまま当てはめない。アーキテクチャ、サイズ、量子化方式で最適値が変わる。
- **Flash Attention**: 常にONが最適とは限らない。`auto` から始めて、必要に応じて `on`/`off` を試す。

## バージョン追従

llama.cpp は頻繁に更新される。新しいバージョンを使う場合は、まずヘルプを確認する：

```bash
llama-bench --help
llama-server --help
```

新しいフラグが追加されている場合は、本SKILLの `references/PROCEDURE.md` に組み込むことを検討する。

### SKILLバージョンの管理方針

- SKILLの `version` は **Semantic Versioning** で管理する（例: `1.0.0` → `1.1.0`）
- `metadata.tested-with` に検証した llama.cpp のバージョンを記録する
- `metadata.last-verified` に最終検証日を記録する
- SKILLの内容がllama.cppの新機能で更新されたら、マイナーバージョンを上げる
- 手順の大幅な見直しがあれば、メジャーバージョンを上げる
