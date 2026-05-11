#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if rg -n 'logEvent|track\(|recordEvent|Analytics\.|Amplitude\.|Mixpanel\.|firebase\.|Segment\.|Crashlytics|Sentry' "$root/GentleDay" >/tmp/gentle-day-analytics-audit.txt; then
  cat /tmp/gentle-day-analytics-audit.txt
  echo "Analytics or telemetry API reference found in GentleDay."
  exit 1
fi

if rg -n 'rawTextPreview|raw response body|console\.log\(\`\[AI_PROXY_DEBUG\].*(raw|body|text)' "$root/server/index.js" "$root/GentleDay" >/tmp/gentle-day-log-audit.txt; then
  cat /tmp/gentle-day-log-audit.txt
  echo "Potential user-content logging found."
  exit 1
fi

if rg -n '"category"\s*:' "$root/server/index.js" >/tmp/gentle-day-proxy-schema-audit.txt; then
  cat /tmp/gentle-day-proxy-schema-audit.txt
  echo "Proxy schema must not request category."
  exit 1
fi

echo "Recovery-sensitive privacy audit passed."
