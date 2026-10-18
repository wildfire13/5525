# 261019 feedback2: guild, character status, inn

Base: 8a8d55d21428834f95e9529f5aa10d26fae588dd. Product main push requires dot's GUI review and a separate start instruction.

Source: private wildfire13/5525_temporary-storage, commit fe28320dd851b798068721c1899bf43dc17a552d, root 261019_5525_feedback2.xlsx. 1,387,307 bytes; SHA-256 5e2839b0ede496f92548307b2377374caf9f3f11a423f75483062de138597746. ZIP readability and hash verified. Sheets 1–4 DrawingML text, rectangles, connectors/arrows and actual image1–5 pixels (1920×1032 each) reviewed. Template is excluded; its 内容確認 instruction is not implemented. The user explicitly retains 人物詳細.

- Clicking the selected guild member again opens the same existing detail window as 人物詳細. Active and reserve restrictions, selection/swap confirmation and busy guards remain.
- Title becomes キャラクターステータス. Existing status preference key and nonexclusive portrait-switch behavior remain.
- New unsaved default size is 2080×780 (old1040×780). Width is capped to the available screen, so FHD uses1920 and1364-wide uses1364. Existing saved rectangles are intentionally honored, not multiplied or discarded. A previously narrow saved window remains narrow until resized. Horizontal scrolling handles narrow saved layouts; existing bounds keep windows visible and above the party strip.
- A shared two-column grid aligns the right edge of スキル・効果 with the equipped column and the left edge of インベントリ with the owner-inventory column.
- Guild and inn use one green 広場へ移動 at the right edge immediately above the bottom party strip. The upper-right duplicates and the guild operation-row return are removed. 人物詳細 remains in the operations row. Pointer clicks on the moved return row do not clear/rebuild guild selection before the click reaches its button.
- Inn lists active party members as horizontal portrait/name/HP/MP cards, with no per-card inventory buttons. Card count follows ordered selected IDs. Horizontal scrolling handles more members/narrow screens. Long names wrap/truncate with tooltips. No journey/log UI is copied.
- Lodging confirmation is compact, centered, and green. The existing price, recovery, reserve exclusion, no-time-elapse, cancellation and once-only transaction remain.

No native rule/skill/equipment changes; no CCT or accessory changes. Existing saved camera and battle-panel keys are unchanged.

## Checks

Run `python godot/tests/run_feedback_261019_2.py --evidence <outside-checkout-directory>` with Node/Godot on PATH. It creates fresh profiles and reports script errors and timeouts as failures.

The new regression covers repeated selection and explicit-details equivalence, active/reserve state preservation, default width vs saved geometry, tab alignment at FHD and1364×1024, pointer-dispatched return clicks, inn cards/resources/long names/count, and lodging cancellation/double-confirmation/resource preservation. Related status/portrait, shop, inventory, frontend and restart checks are included. Native inn's six existing Python tests are also run.

The original guild_regression, guild_vacancy_regression and inventory_regression scripts were reproduced on both unchanged8a8d55d and candidate2af9df4. All three stopped at identical obsolete control references. Their tests now follow the current hub entry, direct counterpart selection, cargo-only confirmation, shared status owner heading and independent ConfirmationDialog. They retain cancellation, duplicate request, owner/resource preservation, stale confirmation and rejection coverage. The updated three suites pass on both the candidate and base production code (only the expected status title is changed to the old title for the baseline run).

Two additional broad suites remain outside the focused passing set: followup_ui_regression (old battle item/skill flows) and shop_quote_lifecycle (two quote-exit expectations). They failed identically on unchanged8a8d55d and2af9df4. Baseline and current logs are retained; these two are not counted as passed or fixed.

Focused evidence after test maintenance: 12 Godot runs /274 checks pass, plus6 native inn tests. The follow-up changes tests/documentation only; production code is identical to2af9df4. See feedback-261019-2-legacy-tests.md for the complete five-suite distinction.

## Dot GUI review

Apply the small overlay to the retained full-source8a8d55d copy with the game closed. Preserve user layout/camera preferences. All transfer files are text and below600KB.

1. At1364×1024 and FHD, open guild. First click selects; clicking the same active or reserve character again opens キャラクターステータス. Verify 人物詳細 still opens the same screen. Check ordinary selection of a different person still offers the existing swap/reorder confirmation.
2. In a profile without a saved status rectangle, verify the new doubled default width (screen-capped) and unchanged780-height default. In the existing profile, verify saved size is retained; resize manually if it was narrow. Restart and confirm persistence.
3. Check the two tab boundaries align with equipped and owned-inventory columns while resizing and with long names. Check inventory/gear confirmation cancellation, portrait switching and close behavior.
4. Verify one green 広場へ移動 on guild and inn, right aligned immediately above the party strip, and real pointer clicks return to the hub.
5. Load the supplied injured-inn QA save. Verify image/name/HP/MP cards without inventory buttons; compact green lodging control. Cancel once, then confirm once:30G is charged and active members recover, reserves/time stay unchanged. Full recovery disables further paid lodging.
6. Readability, chosen spacing and desktop pointer behavior remain human GUI acceptance items. Headless checks are not visual acceptance.
