# Current combat acceptance

## Rules

- All units may cross the center line during combat.
- The enemy chooses and executes each action from the current board state. Battle saves contain no enemy intent or reserved target cells.
- Formation conditions use three guardian cells relative to the Porter position. The Porter is not itself counted as a guardian.
- A living Porter reaching the enemy's far edge wins immediately. Porter defeat takes precedence if both terminal conditions could occur together.
- The `invasion` passive grants enemy-side initial deployment. It does not grant a special combat movement right.
- Victory rewards are settled for annihilation and breakthrough. Older in-battle saves return to Astaris during load.

## Verification

Run `python3 check.py` for the native suite. `test_campaign_rule_migration.cjs` covers synthetic Porter-relative movement/deployment and checked-in old-save migration; it never reads or writes a player save. `test_godot_rules.cjs` covers immediate enemy choices, crossing into enemy territory, invasion deployment, and breakthrough. `test_campaign_battle.cjs` and `test_equipment_ambush_def.cjs` cover skill and damage behavior.

The Godot UI suite and Windows executable are separate checks. A headless rule pass does not claim Windows GUI verification.
