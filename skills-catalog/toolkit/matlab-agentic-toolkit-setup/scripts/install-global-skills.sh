#!/usr/bin/env bash
# Copyright 2026 The MathWorks, Inc.
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  printf 'Usage: install-global-skills.sh <toolkit-root>\n' >&2
  printf 'Example: bash install-global-skills.sh /path/to/matlab-agentic-toolkit\n' >&2
  exit 1
fi
toolkit_root="$1"

if [[ ! -d "${toolkit_root}/skills-catalog" ]]; then
  printf 'Error: %s/skills-catalog not found.\n' "${toolkit_root}" >&2
  printf 'Ensure <toolkit-root> is the matlab-agentic-toolkit repository root.\n' >&2
  exit 1
fi

# Determine skills directory: prefer ~/.agents/skills/, fall back to
# ~/.copilot/skills/ if the primary cannot be created (e.g., restricted
# home directory layouts on some corporate machines).
skills_root="${HOME}/.agents/skills"
if ! mkdir -p "${skills_root}" 2>/dev/null; then
  skills_root="${HOME}/.copilot/skills"
  mkdir -p "${skills_root}"
fi

link_skill() {
  local source_dir="$1"
  local link_name
  link_name="$(basename "${source_dir}")"
  ln -sfn "${source_dir}" "${skills_root}/${link_name}"
  printf 'Linked %s -> %s\n' "${skills_root}/${link_name}" "${source_dir}"
}

# Auto-discover all published skills (directories containing manifest.yaml).
while IFS= read -r manifest; do
  link_skill "$(dirname "${manifest}")"
done < <(find "${toolkit_root}/skills-catalog" -path '*/skills-catalog/*/*/manifest.yaml' | sort)

printf '\nSkills directory: %s\n' "${skills_root}"
