#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="${HOME}/.claude/plugins/data/green-code"
CONFIG_FILE="${DATA_DIR}/config.json"
USAGE_FILE="${DATA_DIR}/usage.json"
PROJECTS_DIR="${HOME}/.claude/projects"

# Idempotent: skip if usage.json already exists
[ -f "$USAGE_FILE" ] && exit 0

# Require config and jq
[ -f "$CONFIG_FILE" ] || { echo "ERROR: config.json not found. Run /green:config first." >&2; exit 1; }
command -v jq &>/dev/null || { echo "ERROR: jq is required." >&2; exit 1; }

# Read config
pue=$(jq '.pue // 1.15' "$CONFIG_FILE")
co2_g_per_kwh=$(jq '.co2_grams_per_kwh // 320' "$CONFIG_FILE")
threshold=$(jq '.threshold_co2_kg // 10' "$CONFIG_FILE")

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Historical usage is rebuilt from the session transcripts (the only durable
# token source: ~/.claude/stats-cache.json is no longer written by recent
# Claude Code versions). Each session gets a snapshot so the Stop hook never
# double-counts what was accounted here. Lines are deduplicated by message id.
transcripts=()
if [ -d "$PROJECTS_DIR" ]; then
  while IFS= read -r f; do transcripts+=("$f"); done \
    < <(find "$PROJECTS_DIR" -name '*.jsonl' -type f)
fi

since=$(date +%Y-%m-%d)
if [ "${#transcripts[@]}" -gt 0 ]; then
  oldest=$(find "$PROJECTS_DIR" -name '*.jsonl' -type f -printf '%TY-%Tm-%Td\n' | sort | head -1)
  since="${oldest:-$since}"
fi

scan=$(jq -nR \
  --arg ts "$NOW" \
  --argjson pue "$pue" \
  --argjson g "$co2_g_per_kwh" \
  '
  def sid_of(f): f | sub(".*/projects/[^/]+/"; "") | sub("/subagents/.*$"; "") | sub("\\.jsonl$"; "");
  def base_wh(name):
    if   name | test("opus")   then 0.002
    elif name | test("sonnet") then 0.0008
    elif name | test("haiku")  then 0.0003
    else                            0.001
    end;
  def tok: {
    inputTokens: ([.[].usage.input_tokens // 0] | add),
    outputTokens: ([.[].usage.output_tokens // 0] | add),
    cacheReadInputTokens: ([.[].usage.cache_read_input_tokens // 0] | add),
    cacheCreationInputTokens: ([.[].usage.cache_creation_input_tokens // 0] | add)
  };
  [ inputs
    | sid_of(input_filename) as $sid
    | fromjson? | .message?
    | select(. != null and .usage != null and .id != null and .model != null)
    | select(.model != "<synthetic>")
    | {sid: $sid, id, model, usage} ]
  | group_by(.id) | map(.[-1])
  | . as $entries
  | ($entries | group_by(.sid) | map({
      key: .[0].sid,
      value: {updatedAt: $ts, models: (group_by(.model) | map({key: .[0].model, value: tok}) | from_entries)}
    }) | from_entries) as $sessions
  | ($entries | group_by(.model) | map(
      base_wh(.[0].model) as $b | tok |
      (.outputTokens * $b + .inputTokens * $b * 0.20 + .cacheCreationInputTokens * $b * 0.25 + .cacheReadInputTokens * $b * 0.02)
    ) | add // 0 | . / 1000 * $pue) as $kwh
  | {
      sessions: $sessions,
      tokens: ([$entries[].usage | (.input_tokens // 0) + (.output_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)] | add // 0),
      kwh: $kwh,
      co2: ($kwh * $g / 1000)
    }
  ' "${transcripts[@]:-/dev/null}")

total_tokens=$(jq '.tokens' <<<"$scan")
total_kwh=$(jq '.kwh' <<<"$scan")
total_co2=$(jq '.co2' <<<"$scan")
trees_needed=$(jq --argjson t "$threshold" '.co2 / $t | floor' <<<"$scan")

mkdir -p "$DATA_DIR"
jq \
  --arg since "$since" \
  '
  {
    sessions: .sessions,
    accumulated: {kwh: .kwh, co2_kg: .co2, since: $since},
    history: [],
    trees: {total: 0, planted: []}
  }
  ' <<<"$scan" > "$USAGE_FILE"

# Summary output
echo ""
echo "=== green-code: initial analysis ==="
echo ""
echo "  Period:       since ${since}"
echo "  Tokens:       $(printf "%'d" "$total_tokens")"
echo "  Energy:       ${total_kwh} kWh (PUE ${pue})"
echo "  CO2:          ${total_co2} kg"
echo "  Trees needed: ${trees_needed} (at ${threshold} kg/tree)"
echo ""
echo "  Tracking is now active."
echo "  Use /green:status for details, /green:plant to offset."
echo ""
