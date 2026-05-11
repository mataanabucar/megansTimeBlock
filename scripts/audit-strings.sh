#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deny_list="$root/scripts/lists/strings-denylist.txt"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required for string auditing."
  exit 2
fi

patterns="$(mktemp)"
matches="$(mktemp)"
trap 'rm -f "$patterns" "$matches"' EXIT

awk 'NF && $1 !~ /^#/ { print }' "$deny_list" > "$patterns"

if [[ ! -s "$patterns" ]]; then
  echo "String deny-list is empty: $deny_list"
  exit 2
fi

touch "$matches"

if [[ -d "$root/GentleDay" ]]; then
  rg --line-number --no-heading --only-matching \
    --glob '*.swift' \
    --glob '!**/Preview Content/**' \
    '"([^"\\]|\\.)*"' "$root/GentleDay" \
    | rg --ignore-case --pcre2 --file "$patterns" >> "$matches" || true

  rg --line-number --no-heading --ignore-case --pcre2 --file "$patterns" \
    --glob '*.strings' \
    --glob '*.stringsdict' \
    --glob '*.xcstrings' \
    --glob '*.json' \
    "$root/GentleDay" >> "$matches" || true
fi

if [[ -s "$matches" ]]; then
  cat "$matches"
  echo "User-visible string audit found deny-list matches."
  exit 1
fi

echo "User-visible string audit passed."
