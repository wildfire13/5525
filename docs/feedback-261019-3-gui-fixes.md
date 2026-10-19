# GUI follow-up: status height and empty inventory

Base d5495a7f50a8b4c33bf12d0d3e4c1d92fad2405d. Product main push remains on hold pending GUI recheck.

## Height loss

A deterministic lifecycle reproduction on1364×1024 starts with saved800×600, migrates to1364×600, calls render(), and calls dialog.remember() before Container's deferred sorting. The newly built PartyFaceBar reports position(12,64) and size(0,0). The old keep_visible calculation used64−8 as the usable height and the window minimum forced the status to1364×300 at(0,36). remember persisted that transient geometry, so reopening retained300. This reproduces the reported outcome; the precise human click sequence/timing is not claimed reproduced.

The status boundary now uses viewport height, the base bottom margin, the visible footer's required height/separation, and the portrait row's required height. It never uses the row's provisional position or current0×0size. Status remains above portraits after layout and inside smaller viewports. Width migration, manual sizing and camera behavior are unchanged.

Already-saved300px height is not automatically replaced: it is indistinguishable from a deliberate minimum-height setting. Set it once to600/662 for GUI recheck. The regression explicitly verifies an intentional300px setting remains respected.

## Empty inventory

At1364×662, opening Garo then clicking Rino's bottom portrait reproduces the empty message wrapping one character per line. The message was the only child of a three-column item/action/sale GridContainer without a useful expanding column. It now sits outside the item grid, fills the owner-inventory column and retains normal wrapping. Filtered-empty text uses the same path. Nonempty rows still use the aligned grid; no inventory state changes.

## Verification

The new status_layout_lifecycle test passes40checks, including same-frame render/remember/close, all five town pages at1364/FHD, town→battle→panel movement→town load, saved camera/panel preservation, manual1100×662, intentional300, and real smaller-viewport clamping. status_empty_inventory passes10checks for the actual Garo→Rino path, filtered empty text, both desktop sizes and returning to nonempty owners. Existing owned_equipment_regression31, feedback_261019_378, feedback_261019_261 and feedback_261019_input56 pass. Total targeted follow-up:6Godot runs/276checks. All executed with isolated profiles; no actual desktop GUI acceptance claim.

Both reproduction failure logs are included with the passing logs. The first camera-preservation test initially compared absent preferences with the default camera that normal battle exit had saved; the finalized test seeds a real saved camera transform before loading battle and verifies it is preserved.

The focused feedback3 runner includes both new tests. Native rules, saved campaign data, audio defaults, ordering and CCT are unchanged.
