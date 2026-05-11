#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deny_list="$root/scripts/lists/identifiers-denylist.txt"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required for identifier auditing."
  exit 2
fi

patterns="$(mktemp)"
matches="$(mktemp)"
trap 'rm -f "$patterns" "$matches"' EXIT

awk 'NF && $1 !~ /^#/ { print }' "$deny_list" > "$patterns"

if [[ ! -s "$patterns" ]]; then
  echo "Identifier deny-list is empty: $deny_list"
  exit 2
fi

targets=()
[[ -d "$root/GentleDay" ]] && targets+=("$root/GentleDay")
[[ -d "$root/GentleDayTests" ]] && targets+=("$root/GentleDayTests")
[[ -f "$root/GentleDay.xcodeproj/project.pbxproj" ]] && targets+=("$root/GentleDay.xcodeproj/project.pbxproj")

if [[ ${#targets[@]} -eq 0 ]]; then
  echo "No source targets found for identifier audit."
  exit 2
fi

touch "$matches"
rg --line-number --no-heading --ignore-case --pcre2 --file "$patterns" "${targets[@]}" > "$matches" || true

if [[ -s "$matches" ]]; then
  cat "$matches"
  echo "Identifier audit found deny-list matches."
  exit 1
fi

echo "Identifier audit passed."
