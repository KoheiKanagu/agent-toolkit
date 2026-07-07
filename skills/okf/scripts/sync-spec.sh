#!/usr/bin/env bash
set -euo pipefail

MODE="update"
if [[ "${1:-}" == "--check" ]]; then
  MODE="check"
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--check]" >&2
  exit 2
fi

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SPEC_PATH="$REPO_ROOT/skills/okf/references/SPEC.md"
UPSTREAM_URL="https://raw.githubusercontent.com/GoogleCloudPlatform/knowledge-catalog/main/okf/SPEC.md"
TMP_FILE="$(mktemp)"

trap 'rm -f "$TMP_FILE"' EXIT

curl -fsSL "$UPSTREAM_URL" -o "$TMP_FILE"

if cmp -s "$TMP_FILE" "$SPEC_PATH"; then
  echo "skills/okf/references/SPEC.md is already up to date."
  exit 0
fi

if [[ "$MODE" == "check" ]]; then
  echo "The vendored OKF spec is out of date."
  echo "Please update skills/okf/references/SPEC.md to match the upstream spec."
  exit 1
fi

cp "$TMP_FILE" "$SPEC_PATH"
echo "Updated skills/okf/references/SPEC.md from upstream."
