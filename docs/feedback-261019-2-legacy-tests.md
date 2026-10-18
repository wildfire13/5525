# Legacy test investigation after candidate2af9df4

Base production: 8a8d55d21428834f95e9529f5aa10d26fae588dd. Initial candidate: 2af9df46dd5aa7a23700d0053f39d1c4625f1a44. Product main remains unpushed pending GUI review.

| Suite | Original failure | Baseline comparison | Follow-up |
| --- | --- | --- | --- |
| guild_regression | nav_party lookup from the board yields an empty array, then null.text at line63 | Identical script errors on base and candidate | Use HubFacility_guild from hub; replace GuildSwap/pick workflow with counterpart selection; retain cargo confirmation and cancellation, stale/duplicate/rejected requests and state invariants.33 checks pass. |
| guild_vacancy_regression | null.disabled for removed GuildSwap at line20; later begin_swap also obsolete | Identical script error on base and candidate | Test real one-member swap and addition, plus disabled final-member removal.5 checks pass. |
| inventory_regression | null.text for removed InventoryOwner at line35 | Identical script error on base and candidate | Verify common status owner heading and IDs; use independent ConfirmationDialog signals; verify selection persists without resurrecting invalidated shop preview.13 checks pass. |
| followup_ui_regression | 45 FAIL lines around old battle item/skill controls, followed by missing boost dictionary key (46 error lines total) | Same complete error list on base and candidate | Unchanged in this follow-up; not passed. |
| shop_quote_lifecycle | purchaseQuote and previewGear exit cancellation expectations (2 FAIL lines) | Same complete error list on base and candidate | Unchanged in this follow-up; not passed. |

Historical evidence: aef272e removed GuildSwap/begin_swap and InventoryOwner; e5280cf introduced HubFacility_* and the town hub; aef272e changed normal formation operations to direct commit, while cargo owner removal keeps confirmation. 885a953 introduced independent inventory confirmation before8a8d55d. select_product clears the old gear-preview quote in the baseline shop implementation, so INV-UI-07 must preserve selection without requiring the old quote to survive.

The first three original suites were run with fresh isolated profiles on a detached8a8d55d worktree and2af9df4. Each was terminated only after the script error was recorded because SceneTree scripts otherwise remain running. Exit-15 is recorded as terminated, never passed. All original logs are preserved.

Updated tests were additionally run against the base production implementation with only their expected title changed from キャラクターステータス to ステータス. All51 checks pass there and on the candidate. This distinguishes old test expectations from a feedback2 production regression. The full focused runner now includes the three repaired suites:12 Godot invocations,274 checks,plus6 native inn tests. No production files were changed by this follow-up.
