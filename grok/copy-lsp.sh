#!/usr/bin/env bash
set -euo pipefail

# Copy grok/lsp/<lang>.json into <dest>/.grok/lsp.json.
# Usage: grok/copy-lsp.sh <dest-repo> <lang> [lang ...]
# Existing keys not in the chosen langs are kept.

TOOLKIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LSP_DIR="${TOOLKIT_ROOT}/grok/lsp"

available_langs() {
  local f
  shopt -s nullglob
  for f in "${LSP_DIR}"/*.json; do
    basename "${f}" .json
  done
  shopt -u nullglob
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 2 ]]; then
  echo "Usage: grok/copy-lsp.sh <dest-repo> <lang> [lang ...]" >&2
  echo "Languages: $(available_langs | tr '\n' ' ')" >&2
  exit 2
fi

if ! command -v jq >/dev/null; then
  echo "jq is required" >&2
  exit 1
fi

DEST="$(cd "$1" && pwd)"
shift
HOME_GROK="$(cd "${HOME}/.grok" 2>/dev/null && pwd || true)"

if [[ -n "${HOME_GROK}" && "${DEST}" == "${HOME_GROK}" ]]; then
  echo "refusing to write ~/.grok/lsp.json" >&2
  exit 1
fi
if [[ "${DEST}" == "${TOOLKIT_ROOT}" ]]; then
  echo "refusing to copy onto agent-toolkit" >&2
  exit 1
fi

incoming='{}'
for lang in "$@"; do
  src="${LSP_DIR}/${lang}.json"
  if [[ ! -f "${src}" ]]; then
    echo "no canonical file for: ${lang}" >&2
    exit 1
  fi
  incoming="$(
    jq -e -n --argjson a "${incoming}" --slurpfile p "${src}" '
      $p[0] as $patch
      | if ($patch | type) != "object" then error("not an object: \($patch)") else . end
      | reduce ($patch | keys[]) as $k ($a;
          if has($k) and .[$k] != $patch[$k] then
            error("server key collision: \($k)")
          else
            .[$k] = $patch[$k]
          end
        )
    '
  )"
done

dest_file="${DEST}/.grok/lsp.json"
existing='{}'
if [[ -f "${dest_file}" ]]; then
  existing="$(jq -e 'if type == "object" then . else error("not an object") end' "${dest_file}")"
fi

mkdir -p "${DEST}/.grok"
jq -n --argjson a "${existing}" --argjson b "${incoming}" '$a * $b' >"${dest_file}.tmp"
mv "${dest_file}.tmp" "${dest_file}"
echo "copied $* -> ${dest_file}"
