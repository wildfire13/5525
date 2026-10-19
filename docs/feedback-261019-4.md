# 261019 UI feedback4

Base: ee81380056096b01c1070dc65dab3420a480725a. Working branch: ui/feedback-261019-4. No push before GUI review.

## Source verification

The direct Library attachment was resolved, but the official transfer helper returned `download failed`; Library pages returned no rendered images/readable content. Implementation did not start from that attempt. The parent then explicitly supplied the original through wildfire13/5525_temporary-storage commit d325a9f087c908df5fbe614a2ce8254a191831a3. Exact root file: 261019_5525_UI_feedback4(1).xlsx, 3,827,302 bytes; SHA256 c69a9d36e89b6e2d4e39ce568f5226e941d6a1008232cc2e831a0f59ccd2ab1d; Git blob cb7187274567d640885388086ffd5a4700cd7a6e. All three identifiers and ZIP integrity verified in this environment.

Sheets 1–5 reference six images, each 1920×1032; all six actual pixel images were viewed. DrawingML text, shape positions and connector endpoints were read and matched to the screenshot regions. Sheet 1 marks the square heading, sheet 2 swaps town/facility hierarchy, sheet 3 marks the four extra destination buttons and roster text, sheet 4 marks the log heading/time/divider, and sheet 5 marks duplicate accessory products and the filter in two screenshots. The workbook also contains template and two template images; template instructions are excluded.

## Changes

- Town name stays at the top of all town screens, including shops and guild. Below it, squares use 地名の広場; facilities use their facility names. Guild also retains the common upper-right gold display.
- Removed only the extra destination button row and roster sentence below the map. Map destination buttons, destination selection, green departure button and travel explanation remain.
- Action log uses ゲーム内経過時間:142時間, with a horizontal separator before the history. Its duplicate body heading is removed; the window title, full history and export remain.
- Accessory product definitions now share a slot-neutral display name and explicit canonical shopProductId. The Godot product list offers the canonical entry once; its dropdown retains only 商品リスト（すべて）. Weapon, armor and consumable filters are unchanged.

Legacy -1/-2 IDs remain separate physical inventories and equipped records. No ID rewrite, merge, deletion, price/stat/effect change, or campaign-save migration occurs. Legacy native shop APIs still resolve both IDs for compatibility; the current UI offers one canonical product. Both IDs already support both accessory slots through the existing allowed-slot rule. Moving equipped accessories uses the existing remove-to-inventory, then equip workflow. Existing duplicate-equipment restrictions and effect stacking rules are unchanged.

## Validation and remaining GUI review

Run `python godot/tests/run_feedback_261019_4.py --evidence /absolute/path/outside/checkout`; optional --only selects named checks. Fresh profiles isolate preferences and synthetic saves. Evidence accompanies the review artifact.

New native regression verifies all ten legacy IDs, 1→2→1 slot movement, counts, round trips, unchanged pricing/effects, quote cancellation and stale-token rejection. New Godot regression covers all five towns, every facility, map selection, canonical shop list, stale accessory filters, cancellation and log hierarchy at 1920×1080 and 1364×1024. Existing layout/camera/transaction regressions are included.

The extra native/test_character_inventory.cjs probe fails at line 32 because an old expected inventory omits quest-cargo:1. The same failure was reproduced against pristine ee81380 native sources. It is recorded separately, not counted as passing or silently fixed. Earlier known hover_regression/followup_ui_regression/shop_quote_lifecycle harness issues are outside this focused suite.

Actual desktop GUI acceptance remains pending. Review long names and narrow layouts, town/facility hierarchy, accessory purchases and movement, old saves with both IDs, and log separator/export. No CCT, battle camera implementation, or saved window geometry code changed. Synthetic town saves are supplied for review, not user progress.

Final targeted results: 27 passing invocations (19 Godot runs / 698 checks, 8 native runs including 378 new compatibility checks, equipment-slot 10 groups, migration 4 groups, shop transactions 9 groups, dual-skill 5 groups, preview 7 tests and inn 6 tests). frontend_smoke completes on current sources. Initial unknown board-icon errors were corrected by retaining the existing adopted place icon; affected tests were rerun. Existing guild/feedback3 assertions were updated for the explicitly changed heading/filter text and rerun. final-results.json points to the passing logs and retains the separate baseline failure; initial logs are retained for traceability.
