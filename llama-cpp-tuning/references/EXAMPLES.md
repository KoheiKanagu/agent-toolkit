# コマンド例集

## 環境確認

```bash
# ハードウェア情報
uname -a
sysctl -n hw.ncpu hw.physicalcpu hw.memsize
system_profiler SPDisplaysDataType SPHardwareDataType | head -40

# ツールバージョン
llama-bench --help | head -5
llama-server --help | head -5
```

## ベースライン

```bash
# Hugging Faceから
llama-bench -hf google/gemma-4-26B-A4B-it-qat-q4_0-gguf -o md

# ローカルファイル
llama-bench -m /path/to/model.gguf -o md
```

## パラメータスイープ

### スレッド数

```bash
llama-bench -hf google/gemma-4-26B-A4B-it-qat-q4_0-gguf -t 4,6,8,10 -o md
```

### バッチサイズ

```bash
llama-bench -hf google/gemma-4-26B-A4B-it-qat-q4_0-gguf \
  -t 10 -b 512,1024,2048,4096 -ub 128,256,512,1024,2048 -o md
```

### Flash Attention

```bash
llama-bench -hf google/gemma-4-26B-A4B-it-qat-q4_0-gguf \
  -t 10 -b 2048 -ub 2048 -fa auto,on,off -o md
```

### 長文プロンプト

```bash
llama-bench -hf google/gemma-4-26B-A4B-it-qat-q4_0-gguf \
  -t 10 -b 2048 -ub 2048 -fa auto -p 2048,4096,8192 -n 128 -r 3 -o md
```

## llama-server 起動例

### コーディングエージェント基本設定

```bash
llama-server -hf google/gemma-4-26B-A4B-it-qat-q4_0-gguf \
  -t 10 \
  -fa auto \
  -b 2048 -ub 2048 \
  -ngl -1 \
  -c 16384 \
  -np 1 \
  --port 8080 \
  --host 127.0.0.1
```

### 長いコンテキストが必要な場合

```bash
llama-server -hf google/gemma-4-26B-A4B-it-qat-q4_0-gguf \
  -t 10 -fa auto -b 2048 -ub 2048 -ngl -1 \
  -c 32768 -np 1 \
  --port 8080 --host 127.0.0.1
```

### メモリを固定したい場合

```bash
llama-server -hf google/gemma-4-26B-A4B-it-qat-q4_0-gguf \
  -t 10 -fa auto -b 2048 -ub 2048 -ngl -1 -c 16384 -np 1 \
  --mlock \
  --port 8080 --host 127.0.0.1
```

## APIリクエスト例

### プロンプトキャッシュなし

```bash
curl http://127.0.0.1:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4",
    "prompt": "長いプロンプト",
    "max_tokens": 512,
    "temperature": 0.8
  }'
```

### プロンプトキャッシュあり

```bash
curl http://127.0.0.1:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4",
    "prompt": "長いプロンプト",
    "max_tokens": 512,
    "temperature": 0.8,
    "cache_prompt": true
  }'
```

### チャット補完

```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma4",
    "messages": [
      {"role": "system", "content": "あなたはコーディングアシスタントです"},
      {"role": "user", "content": "以下のコードをレビューしてください\n```python\n...\n```"}
    ],
    "max_tokens": 512,
    "temperature": 0.8,
    "cache_prompt": true
  }'
```

## 結果記録用テンプレート

```markdown
## モデル: 
## ハードウェア: 

### llama-bench
| 設定 | pp512 | tg128 |
|------|-------|-------|
| ベースライン | | |
| 最適化 | | |

### llama-server
| 長文プロンプト | キャッシュ後生成 | 短い生成 |
|--------------|----------------|---------|
| | | |

### 推奨コマンド
```bash
llama-server ...
```
```
