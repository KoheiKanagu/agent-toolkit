# llama.cpp パフォーマンスチューニング手順

## 目的

指定されたモデルに対して、llama.cpp（llama-bench / llama-server）での最適な推論パラメータを見つける。

## 前提条件

- llama.cpp がインストールされている（`llama-bench`, `llama-server`, `llama-cli` が使用可能）
- モデルは GGUF 形式、または Hugging Face 上の GGUF リポジトリ
- 十分なディスク容量とメモリ

## フェーズ1: 環境確認

### 1.1 ハードウェア情報の取得

```bash
# CPU情報
uname -a
sysctl -n hw.ncpu hw.physicalcpu hw.memsize

# GPU情報（Apple Silicon）
system_profiler SPDisplaysDataType SPHardwareDataType
```

### 1.2 ツールバージョンの確認

```bash
llama-bench --help | head -40
llama-server --help | head -40
```

### 1.3 確認項目

- [ ] 物理コア数を記録
- [ ] メモリ総量を記録
- [ ] GPU名とUnified Memoryか確認
- [ ] llama.cppのビルド情報を記録
- [ ] 新しいバージョンで追加されたフラグがないか確認（`--help` の差分を確認）

## フェーズ2: ベースラインベンチマーク

### 2.1 llama-bench でのベースライン

```bash
llama-bench -hf <model-repo> -o md
```

またはローカルファイルの場合：

```bash
llama-bench -m /path/to/model.gguf -o md
```

### 2.2 記録項目

- `pp512`（プロンプト処理速度）
- `tg128`（トークン生成速度）

## フェーズ3: パラメータスイープ

### 3.1 スレッド数の最適化

```bash
llama-bench -hf <model-repo> -t 4,6,8,10 -o md
```

**原則**: Apple Silicon では物理コア数を基本とする。ただしGPU主体の場合、差は小さい。

### 3.2 バッチサイズの最適化

```bash
llama-bench -hf <model-repo> -t <best_threads> -b 512,1024,2048,4096 -ub 128,256,512,1024,2048 -o md
```

**原則**:
- 短いプロンプト（<1K）: 512〜1024
- 中程度のプロンプト（1K〜8K）: 1024〜2048
- 長いプロンプト（>8K）: 2048
- Apple Silicon では `-b 2048 -ub 2048` がコミュニティで推奨されることが多い

### 3.3 Flash Attention の確認

```bash
llama-bench -hf <model-repo> -t <best_threads> -b <best_batch> -ub <best_ubatch> -fa auto,on,off -o md
```

**原則**:
- まず `-fa auto`（デフォルト）を試す
- 長いコンテキストでは `-fa on` が有利なことが多い
- 短いコンテキストや特定モデルでは `-fa off` の方が速いこともある
- **実際のサーバー運用では `-fa auto` が無難**

### 3.4 GPUレイヤー確認

```bash
llama-bench -hf <model-repo> -t <best_threads> -ngl -1,0 -o md
```

**原則**:
- メモリに収まるなら `-ngl -1`（全GPU載せ）
- `-ngl 0`（CPUのみ）は比較用。通常は圧倒的に遅い

### 3.5 スプリットモード確認（マルチGPU時）

```bash
llama-bench -hf <model-repo> -t <best_threads> -sm layer,row -o md
```

**原則**:
- シングルGPUでは差が小さい
- マルチGPUでは `layer` が基本

### 3.6 キャッシュタイプ確認

```bash
llama-bench -hf <model-repo> -t <best_threads> -b <best_batch> -ctk f16,q8_0 -ctv f16,q8_0 -o md
```

**原則**:
- デフォルト `f16` が最も安定
- `q8_0` はメモリ節約になるが、モデルによっては失敗する（Gemma4 26Bでは未対応）
- Flash Attention ON が前提のことが多い

## フェーズ4: コーディングエージェント用途の最適化

### 4.1 長文プロンプトの計測

```bash
llama-bench -hf <model-repo> -t <best_threads> -b <best_batch> -ub <best_ubatch> -fa <best_fa> -p 2048,4096,8192 -n 128 -o md
```

### 4.2 llama-server での実API計測

```bash
llama-server -hf <model-repo> \
  -t <best_threads> \
  -fa <best_fa> \
  -b <best_batch> -ub <best_ubatch> \
  -ngl -1 \
  -c 16384 \
  -np 1 \
  --port 8080 --host 127.0.0.1
```

APIクライアントまたは curl で計測：

```bash
curl http://127.0.0.1:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "model",
    "prompt": "長いプロンプト",
    "max_tokens": 128,
    "temperature": 0.8,
    "cache_prompt": true
  }'
```

### 4.3 プロンプトキャッシュの効果測定

1回目: `cache_prompt: false`
2回目: `cache_prompt: true`

時間差を記録。

## フェーズ5: 結果の記録と推奨設定の導出

### 5.1 記録テンプレート

```markdown
## モデル: <model-name>
## ハードウェア: <Mac model>

### llama-bench 結果
| 設定 | pp512 | tg128 | pp8192 | tg128-after-8192 |
|------|-------|-------|--------|------------------|
| ベースライン | | | - | - |
| 最適化 | | | | |

### llama-server 結果
| 設定 | 長文プロンプト | キャッシュ後生成 | 短い生成 |
|------|--------------|----------------|---------|
| 最適 | | | |

### 推奨コマンド
```bash
llama-server -hf <model-repo> -t <threads> -fa <fa> -b <batch> -ub <ubatch> -ngl -1 -c <ctx> -np 1 --port 8080
```
```

### 5.2 推奨設定の選定基準

1. **速度**: 最も重要な指標を選ぶ（プロンプト処理か生成か）
2. **安定性**: エラーやクラッシュが少ない設定
3. **メモリ**: システムに余裕を残す
4. **用途**: チャット、RAG、バッチ処理など

## 注意事項

### 熱スロットリング

- 連続ベンチマークでは熱スロットリングで結果が低下する
- 各ベンチマーク間に30〜60秒の冷却時間を設ける
- 複数回計測して平均を取る

### 測定のばらつき

- 同じ設定でも ±10% 程度変動するのは普通
- 大きな差（>20%）が出た場合のみ判断材料とする

### モデル依存性

- 得られた結果は他のモデルにそのまま当てはめない
- アーキテクチャ（Dense/MoE）、サイズ、量子化方式で最適値が変わる

## よくある落とし穴

1. **Flash Attention を盲目的にONにしない**
   - モデルとコンテキスト長によっては OFF/auto の方が速い

2. **バッチサイズを無闇に大きくしない**
   - 2048を超えると逆に遅くなることがある
   - メモリ不足で失敗することも

3. **llama-bench と llama-server の結果を混同しない**
   - llama-bench は理想値
   - llama-server は実APIのオーバーヘッド込み

## 関連ファイル

- `checklist.md` - 実行時チェックリスト
- `examples.md` - 具体的なコマンド例
