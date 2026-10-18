# 261019 GUI follow-up: floating panel input

Base: e3a9457f2b4efd5084f502f67f47470dc428069f. Product main push remains on hold.

## Reproduced bugs

The reported town → battle reload problem reproduces through `load_game` and viewport-dispatched mouse events at 1364×1024. On the base candidate, the first drag works, but after saving near the top and reloading, `gui_get_hovered_control()` reports `BattleTools` over the visually foreground panel header. The panel never receives its press and `dragging` stays false. The initial 20-check reproduction has 13 failures.

`z_index` sets drawing order, while Control picking follows sibling order. Mount placed tools after the panels. Clicking a panel used to bring it to the end, explaining why dragging could work initially and stop after remount.

Saved negative parent-local coordinates were also clamped against the parent before viewport bounds were enabled. After correcting that, container layout still moved the parent by 12px after the first restoration. Both caused a top-edge position to move on reload.

## Fix

- Mount floating panels after tools/order controls so input order matches their foreground drawing. Clicking either exposed header still raises that panel over the other.
- Enable viewport bounds before configuration, preserve the existing preference keys and saved coordinate format, and reapply the saved rectangle once container layout has settled. Opening waits for that restoration. A user press cancels pending restoration.
- Opening/closing/skip animation copies recursively ignore input, including internal scrollbars, and disable copied scripts. Their explicit tweens continue to run. The opening still starts behind the current first action card and finishes at the restored command window.

No native rules, inventory definitions, accessories, CCT, or camera behavior were changed.

## Rule recheck

`native/test_feedback_261019_input.cjs` checks all four non-porters: Lv3 fists fail eligibility with the porter-only reason, both hand equip quotes fail without state mutation, and an equipped Lv3 save is rejected. Porter default fists expose Lv3 without creating inventory stock or allowing attacks. Lv1/self, Lv2/orthogonal adjacency, and Lv3/unlimited targets were checked across all 50 cells, including enemy rejection. Forged Lv3 skill-source metadata on a non-porter save is rejected.

Lv3 fists are the porter's virtual empty-hand default; they are not a transferable physical item. These rechecks required no native behavior change.

## Verification and limits

`godot/tests/feedback_261019_input.gd` injects mouse motion/press/release through the viewport, not by directly calling drag handlers. It covers 1364×1024 and 1920×1080, town/battle file reloads, both headers at the top edge, foreground input after overlapping panels, toolbar overlap, opening origin and motion at normal speed, and unchanged campaign/camera state. It also checks that all animation-copy descendants ignore input.

Final focused run: 3 native suites (24 behavior groups) and 9 Godot runs (234 checks) pass. This includes the 56 new input checks, the 32 new-skill checks, action order, equipment/UI flow, deployment geometry, restart persistence, frontend smoke, and existing viewport mouse/camera checks.

These are headless Linux/Godot 4.6.3 checks. They do not establish human drag feel or Debian desktop-specific pointer behavior. Dot should retest the same visible scenario on the existing cloud PC before accepting the candidate.

## Dot GUI retest

1. Close the game and apply the reviewed overlay to the extracted e3a9457 source copy. Keep the existing user preferences; clearing them would hide the reported transition.
2. At 1364×1024, load town.json then sweep100.json. Drag both headers to y=0. Load town.json and sweep100.json again; verify the positions remain at the top and both headers still drag. Repeat twice.
3. Overlap the panels. Click each exposed header, checking that the same window becomes both visibly foremost and draggable. Move a header over the battle-details toolbar and repeat.
4. Confirm opening starts behind the currently first action card, ends at the saved position, and leaves the real command window interactive. Execute 足払い once to recheck the skip-card flight and queue progression.
5. Recheck camera operations on empty board space and ensure dragging/resizing either panel does not pan, rotate, or zoom the camera. Restart and check geometry/camera persistence.
6. Lv1 item target: self only. Lv2: self or orthogonally adjacent ally. Porter Lv3: distant ally allowed; no attacks. Non-porter Lv3 equipment/save injection remains invalid at the engine boundary.
