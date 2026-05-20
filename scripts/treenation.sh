#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./i18n.sh
. "${SCRIPT_DIR}/i18n.sh"

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"
USAGE_FILE="${DATA_DIR}/usage.json"

[ -f "$CONFIG_FILE" ] || { echo "$T_TN_NOT_CONFIGURED"; exit 1; }
command -v jq &>/dev/null || { echo "$T_TN_JQ_REQUIRED"; exit 1; }

API_KEY=$(jq -r '.treenation_api_key // ""' "$CONFIG_FILE")
FOREST_ID=$(jq -r '.forest_id // ""' "$CONFIG_FILE")
BASE_URL="https://tree-nation.com/api"

[ -n "$API_KEY" ] || { echo "$T_TN_NO_API_KEY"; exit 1; }
[ -n "$FOREST_ID" ] || { echo "$T_TN_NO_FOREST"; exit 1; }

cmd_plant() {
  local count="${1:-1}"
  local threshold=$(jq '.threshold_co2_kg // 10' "$CONFIG_FILE")
  local co2_offset=$(echo "scale=2; $count * $threshold" | bc)

  response=$(curl -s -w "\n%{http_code}" \
    -X POST "${BASE_URL}/plant" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"forest_id\": ${FOREST_ID},
      \"quantity\": ${count}
    }")

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    # Extract certificate URLs
    cert_urls=$(echo "$body" | jq -r '.trees[]?.certificate_url // empty' 2>/dev/null)

    # Log to usage.json
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq \
      --argjson count "$count" \
      --arg date "$NOW" \
      --argjson offset "$co2_offset" \
      --arg certs "$cert_urls" \
      '
      .trees.total += $count |
      .trees.planted += [{
        "date": $date,
        "count": $count,
        "co2_offset_kg": $offset,
        "certificates": ($certs | split("\n") | map(select(. != "")))
      }]
      ' "$USAGE_FILE" > "${USAGE_FILE}.tmp" && mv "${USAGE_FILE}.tmp" "$USAGE_FILE"

    echo "OK:${count} ${T_TN_TREES_PLANTED} (${co2_offset} ${T_TN_OFFSET})"
    [ -n "$cert_urls" ] && echo "CERTS:${cert_urls}"
    return 0
  else
    echo "ERROR:HTTP ${http_code} - ${body}" >&2
    return 1
  fi
}

cmd_forest() {
  response=$(curl -s \
    -H "Authorization: Bearer ${API_KEY}" \
    "${BASE_URL}/forests/${FOREST_ID}")
  echo "$response" | jq .
}

cmd_species() {
  local project_id="${1:-}"
  if [ -z "$project_id" ]; then
    curl -s -H "Authorization: Bearer ${API_KEY}" \
      "${BASE_URL}/projects?status=active" | jq '.[] | {id, name, country}'
  else
    curl -s -H "Authorization: Bearer ${API_KEY}" \
      "${BASE_URL}/projects/${project_id}/species" | jq '.[] | {id, name, price, stock}'
  fi
}

case "${1:-help}" in
  plant)   cmd_plant "${2:-1}" ;;
  forest)  cmd_forest ;;
  species) cmd_species "${2:-}" ;;
  *)
    echo "$T_TN_USAGE"
    exit 1
    ;;
esac
