#!/bin/bash
set -euo pipefail

# llama-server 起動スクリプト
# 対象モデル: google/gemma-4-26B-A4B-it-qat-q4_0-gguf
# 検証環境: MacBook Pro M2 Pro (10 cores), 32GB Unified Memory
#
# 注意: 本スクリプトのパラメータは上記環境で検証した結果に基づく。
# 異なる環境では、参照先の SKILL.md / PROCEDURE.md に従って再チューニングすること。

PORT="${PORT:-8080}"
HOST="${HOST:-127.0.0.1}"
CONTEXT_SIZE="${CONTEXT_SIZE:-16384}"

echo "Starting llama-server for Gemma 4 26B..."
echo "Host: ${HOST}, Port: ${PORT}, Context: ${CONTEXT_SIZE}"

llama-server \
  -hf google/gemma-4-26B-A4B-it-qat-q4_0-gguf \
  -t 10 \
  -fa auto \
  -b 2048 -ub 2048 \
  -ngl -1 \
  -c "${CONTEXT_SIZE}" \
  -np 1 \
  --no-mmap \
  --port "${PORT}" \
  --host "${HOST}"
