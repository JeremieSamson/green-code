---
name: plant
description: Plant trees via Tree-Nation to offset your AI carbon footprint. Use when the user wants to compensate their CO2 emissions. Accepts optional tree count and message arguments.
---

# green-code: Plant Trees

Plant trees via Tree-Nation to compensate the user's AI carbon footprint.

## Steps

1. Read `~/.claude/plugins/data/green-code/config.json` to verify API key and forest_id are set. If not, tell the user to run `/green:config` first.

2. Read `~/.claude/plugins/data/green-code/usage.json`. `accumulated.co2_kg` is a
   lifetime total of emissions that is never decremented, and `trees.total` counts
   every tree planted so far, so the outstanding debt is
   `accumulated.co2_kg - (trees.total * threshold_co2_kg)`.

3. Determine how many trees to plant:
   - If the user provided a number (e.g., `/green:plant 3`), use that number.
   - If no number provided, calculate `floor(debt / threshold_co2_kg)` using the debt
     from step 2. Never divide `accumulated.co2_kg` by the threshold directly: that
     ignores the trees already planted and offsets the same emissions twice.
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

7. Do NOT edit `accumulated.co2_kg`. The script already increments `trees.total`,
   which lowers the debt computed in step 2; subtracting the offset as well would
   count the planting twice.

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
- `accumulated.co2_kg` is a lifetime total: only the tracker hook ever writes to it
- The message appears on the public certificate, so keep it clean; the default is safe when in doubt
- If the API call fails, do NOT modify usage.json
