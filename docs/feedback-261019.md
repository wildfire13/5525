# 261019 UI / equipment feedback

Source: `261019_5525_feedback.xlsx` in `wildfire13/5525_temporary-storage`, commit `002affbafb4f09482d26ec6bf4c61c0b469ad051`.
Size: 3,626,220 bytes. SHA-256: `f32822a481e1c6e272ae65e3e2894dc63c86ee5e5a8367a90ed05c90e74a6f45`.

Sheets 1, 2, 3 and 装備実装 were reviewed, including DrawingML text/shape positions and the eight referenced PNG images. The template sheet is excluded. The incomplete trailing sentence on sheet 2 does not create an additional requirement.

## Behavior

- Battle details now retain formation occupancy/multipliers and the reasons behind enemy intentions. Turn order, history, stock and character stat duplicates are removed.
- Menu moves to the lower right. Normal campaign battle ESC opens retreat confirmation. Existing modal, reference, item/skill and target cancellation takes precedence; trial exit stays explicit.
- Floating battle/deployment panels reach the viewport top, stay within the viewport, and can overlap other controls. Dragging raises a panel. Existing geometry keys and camera preferences remain.
- Actor commands expand from behind the first order card. A skipped turn's card flies right, then the queue advances. Neither animation accepts the same action twice.
- The status equipment tab shows the owner's mixed inventory beside equipped slots. Its filter is at the top; selecting an equipped body part selects that filter. Item actions use existing inventory transactions and confirmations.
- Godot arrival transitions directly into the town hub, including loaded older arrival/travel-result snapshots. A five-second nonblocking notification uses the save-notice display. Quest cargo is not automatically delivered. Destination hubs place 荷物を届ける immediately beneath 地図・出発; the existing cargo/party/porter validation remains authoritative.

| Equipment | Effect | Skill |
|---|---|---|
| カンフーパンツ | HP +5 | 足払い Lv1: 50% |
| カンフーパンツ＋1 | HP +25 | 足払い Lv1: 50% |
| カンフーパンツ＋2 | HP +25 | 足払い Lv2: 75% |
| カンフーパンツ＋3 | HP +25 | 足払い Lv3: 100% |
| 拳 | No stat bonus | アイテム使用 Lv1: self |
| 拳＋1 | No stat bonus | アイテム使用 Lv2: self / orthogonally adjacent ally |
| 拳＋2 | No stat bonus, porter default | アイテム使用 Lv3: unlimited distance |
| 鉤縄 | No stat bonus | 引き寄せ: exactly two cells right, pull one cell toward user |
| 木製の両手槍 | Existing ATK34 and two-hand occupancy | ポールヴォールト: orthogonal two-cell jump |

足払い costs MP1, deals no damage, rolls independently for each living enemy in the surrounding eight cells, and sets one nonstacking pending skipped turn. Previews never roll. A skipped turn advances initiative without executing a command or spending the skipped unit's MP/items; turn-bound defensive effects expire normally. The pending boolean survives battle saves.

ポールヴォールト costs MP1. The intermediate cell may contain an ally, enemy, or nobody. Landing must be on the board, empty of living units, and satisfy the normal invasion restriction. No hole terrain is introduced.

引き寄せ costs MP1 and one action even when the intermediate landing cell is occupied; in that case there is no movement. Either side may be targeted. Item use costs MP0 and consumes one item from the actor's own inventory. Existing potion/ether effects and the porter-only ether restriction remain. Without アイテム使用 the battle item command cannot execute an item.

Empty hands expose virtual fists (porter: 拳＋2; others: 拳). They do not create sellable or transferable inventory copies. A two-handed weapon occupies both hands and suppresses the virtual offhand. 拳＋1 is a real purchasable test item. Highest level wins when more than one equipment source supplies a skill. Existing race/stat restrictions remain, including the wooden two-hand spear's STR14 requirement.

New test prices are provisional: pants 70/100/130/160G; 拳＋1 and 鉤縄 100G. The existing two-hand spear stays 140G. These prices were not specified in the source workbook.

Old saves are validated under their original skill metadata before migration. New `combatRevision: 1` character metadata adds default fist skills and the spear skill without changing inventory, money, HP/MP, growth, or rollback ownership. CCT and accessory equipment definitions are unchanged.

## Repeatable checks

With Node and Godot on PATH:

```text
python godot/tests/run_feedback_261019.py --evidence /workspace/5525-261019-qa/final-checks
```

Final focused result: 20 native suites and 11 Godot runs pass (303 GUI assertions, including 35 frontend smoke assertions). The two new Godot suites cover 25 UI checks and 32 skill checks. The new native suite covers 12 behavior groups. Many/long inventory names were checked with 36 synthetic view entries.

The runner uses fresh isolated Godot profiles and checks script errors, failures, and leaked objects as well as exit status. It includes both process-restart preference checks. `frontend_smoke.gd` uses the current APIs and is part of the run.

`godot/tests/feedback_261019_fixtures.cjs` produces controlled QA snapshots for GUI review. They are synthetic battle boundaries, not proof of a complete route playthrough. The ordinary six-battle cargo-return regression separately exercises real encounters and delivery.

Three broader native tests already fail at the unchanged base `61e2670`: `test_campaign_battle.cjs` expects the old absent DEF metadata, `test_character_inventory.cjs` expects no quest-cargo inventory entry, and `test_engine_regression.cjs` has a stale frozen journey hash. They are documented rather than altering unrelated rules to satisfy obsolete assertions. Artifact evidence includes baseline reproduction logs.

## GUI acceptance still required

Use the candidate's normal launcher on dot's cloud PC at 1920×1080. Keep real saves separate; load the provided QA snapshots and do not overwrite normal saves with test scenes.

1. `town.json`: open guard status; verify equipment beside inventory, top filter, part filtering, long labels/scrolling, equip/discard confirmation cancellation, and persisted size/position.
2. `sweep50.json` / `sweep100.json`: choose 足払い; verify three per-enemy probability previews, MP1, no direct damage, one skipped turn per success, no stacking, and each skipped card flying right. Cancel first, then execute once. Use the 100% case for deterministic animation acceptance.
3. `vault.json`: select ポールヴォールト; preview the empty cell two squares right across the adjacent ally, cancel, then execute. Check ghost and jump. Occupied landing, diagonal and enemy-side landing without invasion must not execute.
4. `grapple.json` / `grapple-blocked.json`: choose 引き寄せ and the enemy two cells right. Compare movement with the blocked case: both spend MP1/one action; only the open destination moves the target.
5. `item1.json` / `item2.json` / `item3.json`: use the skill to open items. Check self-only, adjacent ally and unlimited range respectively, actor-owned stock, cancellation, and single execution.
6. In battle, test command opening/closing at normal speed, move both panels to the screen top, overlap controls, switch the foreground panel, then restart to verify saved geometry and camera. Verify target ESC cancels before a later normal-state ESC offers retreat.
7. Complete a normal second encounter: return directly to town with an arrival notification. A destination quest remains pending until 荷物を届ける. Verify missing/reserve cargo disables delivery, and an already delivered quest cannot pay twice.
8. Confirm Windows launch and subjective visual timing/readability. Automated headless checks do not establish those results.

Do not push the product repository's main branch until dot's GUI review and separate push instruction.
