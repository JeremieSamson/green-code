---
name: plant
description: Plant trees via Tree-Nation to offset your AI carbon footprint. Use when the user wants to compensate their CO2 emissions. Accepts optional tree count and message arguments.
---

# green-code: Plant Trees

Plant trees via Tree-Nation to compensate the user's AI carbon footprint.

## Steps

1. Read `~/.claude/plugins/data/green-code/config.json` to verify API key and forest_id are set. If not, tell the user to run `/green:config` first.

2. Read `~/.claude/plugins/data/green-code/usage.json` to get the current CO2 accumulation.

3. Determine how many trees to plant:
   - If the user provided a number (e.g., `/green:plant 3`), use that number.
   - If no number provided, calculate: `ceil(accumulated.co2_kg / threshold_co2_kg)`
   - If the calculated number is 0, tell the user their footprint is too small to warrant a tree yet, and show the current CO2 level.

4. Confirm with the user before planting:
   "You're about to plant {N} tree(s) via Tree-Nation to offset {co2} kg of CO2. Proceed?"

4b. Determine the dedication message (attached to each planting and shown on the public Tree-Nation certificate):
   - If the user provided a message (e.g., `/green:plant 3 "merci pour la forêt"`), use it verbatim.
   - If no message is provided, leave it empty: the script fills in a default
     (`Compensation {co2} kg CO2 - usage IA Claude Code - {date}` / `Offsetting {co2} kg CO2 - Claude Code AI usage - {date}`).

5. If confirmed, run the planting script (the message is optional; wrap it in quotes):
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/treenation.sh" plant {N} "{message}"
   ```

6. Parse the output:
   - If starts with `OK:` -- success. Show the number of trees planted and certificate URLs.
   - If starts with `ERROR:` -- show the error and suggest checking the API key.

7. After successful planting, update the accumulated CO2:
   - Subtract `N * threshold_co2_kg` from `accumulated.co2_kg` in usage.json
   - Use jq or direct JSON edit

8. Show a summary:
   ```
   {N} tree(s) planted via Tree-Nation!
   CO2 offset: {offset} kg
   Total trees planted: {trees.total}
   Certificate(s): {urls}
   ```

## Important

- Always confirm before planting (it costs real money via Tree-Nation credits)
- The script handles logging the planting in usage.json automatically (including the `message`)
- The message appears on the public certificate, so keep it clean; the default is safe when in doubt
- If the API call fails, do NOT modify usage.json
