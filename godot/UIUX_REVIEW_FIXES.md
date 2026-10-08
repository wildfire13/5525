# UI review fixes after fc75ff3

The independent UI review found that product-focus text could grow the footer to 105 px at 800x600, leaving a zero-height comparison pane while purchase remained available. The footer now occupies one line, with the complete text available in its tooltip and a scrollable popup opened by click or keyboard. Quote comparison has a 64 px minimum, long reasons are inside its scroll area, and purchase requires that the pane be visible within the client area. Cancel and trial-return preserve the operation position.

Camp rest previously shortened its button from the full recovery label to a short completed label, shifting the onward button. The rest slot now retains the full-label minimum width. Product summaries now take non-HP effects from the existing catalog description, so swift boots show movement +1 before and after selection, at the unchanged 70G price.

Presentation phases now use a dedicated HUD branch. It shows the action label from the current action_id and the current effect label, retaining the acting portrait and disabling action input. Held player skill/target/cost controls return only after the presentation completes. No combat, equipment, price, save, audio, or ACK protocol rules were changed.

## Regression

tests/uiux_review_fixes.gd is part of check.py. Its 35 checks use four labeled synthetic review fixtures: east shop, west shop, one-hit victory, and porter formation boost followed by an enemy-healer attack. The latter reproduces the original display conflict: enemy healer 3 attacks Nika for 9 damage while the held player command is skill.

The regression explicitly focuses product controls, verifies every comparison cell can be scrolled into view at 1280x800, 1024x720 and 800x600, opens a full 40-character name / 200-character explanation with Enter, cancels purchase, returns from trial, rejects purchase with a hidden comparison, checks camp geometry and catalog text, and records every presentation phase.

Optional environment: UIUX_REVIEW_EVIDENCE for the reports/captures directory and UIUX_REVIEW_TAG for result names. Without these, headless evidence goes to an isolated test subdirectory under the current Godot user directory. Use isolated APPDATA/LOCALAPPDATA/TEMP/TMP as with the other tests. Omitting --headless additionally captures rendered frames; Dummy audio does not establish subjective listening.

Independent re-acceptance is still required. This patch does not promote the previous 65-case acceptance totals, actual OS 150% scaling, real audio listening, or other untested procedures to passed.
