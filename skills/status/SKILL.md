---
name: status
description: Display your AI carbon footprint - tokens consumed, energy estimated, CO2 emitted, and trees planted. Use when the user asks about their carbon impact or wants to see green-code stats.
---

# green-code: Carbon Footprint Status

Read the green-code tracking data and display a formatted summary to the user.

## Steps

1. Read `~/.claude/plugins/data/green-code/usage.json`
2. Read `~/.claude/plugins/data/green-code/config.json`
3. If either file is missing, tell the user to run `/green:config` to set up the plugin.

## Display Format

Present the data in this format (adapt numbers from the JSON):

    green-code -- Carbon Footprint

      Period:        Since {accumulated.since}
      Energy:        {accumulated.kwh} kWh (estimated)
      CO2 emitted:   {accumulated.co2_kg} kg (US mix, {config.co2_grams_per_kwh} g/kWh, PUE {config.pue})
      Trees needed:  {ceil(accumulated.co2_kg / config.threshold_co2_kg)} (at {config.threshold_co2_kg} kg CO2/tree)
      Trees planted: {trees.total}
      Balance:       {trees.total * config.threshold_co2_kg - accumulated.co2_kg} kg CO2

      Mode: {config.mode} | Threshold: {config.threshold_co2_kg} kg CO2/tree

      Sources: IEA 2024, Luccioni et al. 2024, de Vries 2023
      Note: Estimates based on US energy mix. Uncertainty ~x2.

If there are planted trees in `trees.planted`, show the last 5 entries:

    Recent plantings:
      {date} -- {count} tree(s), {co2_offset_kg} kg CO2 offset

## Important

- All numbers should be rounded to 2 decimal places for display
- If `accumulated.co2_kg` is 0 or very small, encourage the user: "Your footprint is minimal so far. Keep coding!"
- If balance is negative (more CO2 than trees planted), suggest: "Run /green:plant to compensate"
- If balance is positive or zero: "You're carbon-neutral! Keep it up."
