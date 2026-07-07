#!/usr/bin/env bash
set -euo pipefail

# GitHub issue に triage-issues スキルで使うラベルを作成する。
# 既存のラベルは上書きしない。
# 実行前に gh コマンドで認証済みであることを確認する。

labels=(
  "in-triage:#FEF2C0:claim マーカー。エージェントがトリアージ処理中であることを示す"
  "ready:#0E8A16:エージェントが人手を介さず実装着手可能"
  "needs-triage:#D93F0B:追加情報または人の判断が必要。要件が揃えば ready に昇格しうる"
  "stale:#CCCCCC:解決済み・obsolete・重複など、クローズ候補"
  "complexity:low:#C2E0C6:機械的・局所的な修正"
  "complexity:medium:#FEF2C0:数ファイルに触れる標準的な機能・バグ"
  "complexity:high:#F9D0C4:横断的または設計判断を含む"
  "complexity:very-high:#F4A6A6:アーキテクチャレベルまたは高リスク"
)

for entry in "${labels[@]}"; do
  IFS=':' read -r name color description <<< "$entry"

  if gh label list --search "$name" --json name --jq ".[] | select(.name == \"$name\")" | grep -q .; then
    echo "Label already exists: $name"
  else
    echo "Creating label: $name"
    gh label create "$name" --color "$color" --description "$description"
  fi
done
