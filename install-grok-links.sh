#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
GROK_DIR="${HOME}/.grok"
SKILLS_SRC_DIR="${REPO_ROOT}/skills"
SKILLS_DST_DIR="${GROK_DIR}/skills"
SANDBOX_SRC="${REPO_ROOT}/grok/sandbox.toml"
LSP_SRC="${REPO_ROOT}/grok/lsp.json"
CONFIG_TOML="${GROK_DIR}/config.toml"
SANDBOX_PROFILE="workspace-safe"

if [[ ! -d "${GROK_DIR}" ]]; then
  echo "Error: ${GROK_DIR} does not exist" >&2
  exit 1
fi

# AGENTS.md (グローバル — 全プロジェクトに適用)
if [[ -f "${REPO_ROOT}/AGENTS.md" ]]; then
  ln -sfn "${REPO_ROOT}/AGENTS.md" "${GROK_DIR}/AGENTS.md"
  echo "Linked AGENTS.md -> ${GROK_DIR}/AGENTS.md"
fi

# sandbox.toml (グローバル — workspace + .env 拒否など)
if [[ -f "${SANDBOX_SRC}" ]]; then
  ln -sfn "${SANDBOX_SRC}" "${GROK_DIR}/sandbox.toml"
  echo "Linked grok/sandbox.toml -> ${GROK_DIR}/sandbox.toml"
fi

# lsp.json (グローバル — 全プロジェクトで language server を使う)
if [[ -f "${LSP_SRC}" ]]; then
  ln -sfn "${LSP_SRC}" "${GROK_DIR}/lsp.json"
  echo "Linked grok/lsp.json -> ${GROK_DIR}/lsp.json"
fi

# config.toml の [sandbox] profile を既定にする（なければ追記、あれば合わせる）
# マシン固有の他設定は触らない
ensure_sandbox_profile() {
  local profile="$1"
  if [[ ! -f "${CONFIG_TOML}" ]]; then
    printf '%s\n' '[sandbox]' "profile = \"${profile}\"" > "${CONFIG_TOML}"
    echo "Created ${CONFIG_TOML} with [sandbox] profile = \"${profile}\""
    return
  fi

  if grep -qE '^[[:space:]]*\[sandbox\]' "${CONFIG_TOML}"; then
    if grep -qE '^[[:space:]]*profile[[:space:]]*=' "${CONFIG_TOML}"; then
      # [sandbox] ブロック内の profile だけを対象にしたいが、簡易に最初の profile 行を置換する
      # （現状 config に他セクションの profile キーは想定しない）
      local tmp
      tmp="$(mktemp)"
      awk -v p="${profile}" '
        BEGIN { in_sandbox = 0; replaced = 0 }
        /^[[:space:]]*\[sandbox\]/ { in_sandbox = 1; print; next }
        /^[[:space:]]*\[/ {
          if (in_sandbox && !replaced) {
            print "profile = \"" p "\""
            replaced = 1
          }
          in_sandbox = 0
          print
          next
        }
        in_sandbox && /^[[:space:]]*profile[[:space:]]*=/ {
          print "profile = \"" p "\""
          replaced = 1
          next
        }
        { print }
        END {
          if (in_sandbox && !replaced) {
            print "profile = \"" p "\""
          }
        }
      ' "${CONFIG_TOML}" > "${tmp}"
      mv "${tmp}" "${CONFIG_TOML}"
      echo "Set [sandbox] profile = \"${profile}\" in ${CONFIG_TOML}"
    else
      # [sandbox] はあるが profile 行がない → セクション直後に挿入
      local tmp
      tmp="$(mktemp)"
      awk -v p="${profile}" '
        { print }
        /^[[:space:]]*\[sandbox\]/ { print "profile = \"" p "\"" }
      ' "${CONFIG_TOML}" > "${tmp}"
      mv "${tmp}" "${CONFIG_TOML}"
      echo "Inserted profile = \"${profile}\" under [sandbox] in ${CONFIG_TOML}"
    fi
  else
    printf '\n[sandbox]\nprofile = "%s"\n' "${profile}" >> "${CONFIG_TOML}"
    echo "Appended [sandbox] profile = \"${profile}\" to ${CONFIG_TOML}"
  fi
}

ensure_sandbox_profile "${SANDBOX_PROFILE}"

# skills (スキル単位 — ~/.grok/skills 内の既存スキルを潰さない)
if [[ -d "${SKILLS_SRC_DIR}" ]]; then
  mkdir -p "${SKILLS_DST_DIR}"
  for skill_dir in "${SKILLS_SRC_DIR}"/*/; do
    [[ -d "${skill_dir}" ]] || continue
    name="$(basename "${skill_dir}")"
    [[ -f "${skill_dir}/SKILL.md" ]] || continue
    ln -sfn "${skill_dir%/}" "${SKILLS_DST_DIR}/${name}"
    echo "Linked skills/${name} -> ${SKILLS_DST_DIR}/${name}"
  done
fi

echo "Done."
