# UIUX candidate for independent review

Base: bebf05770f58639ab8a4153e7cf7f72eb64d76de. Implements the three approved priorities from the formal UIUX v1.0 instructions: nearby fixed battle controls, simultaneous shop list/comparison, and a short current-party list with one selected detail. This branch is a candidate; it has not been pushed or applied to the ordinary installation.

Rules, prices, equipment eligibility, move-ending-hand behavior, fixed-cell enemy intents and save compatibility remain owned by the existing native engine. The UI tracks quote/preview generations and session-only scroll anchors; these UI values do not enter campaign saves.

## Reproduce

Run the existing python -X utf8 -B godot/check.py --full --godot <installed-console-exe> with isolated APPDATA, LOCALAPPDATA, TEMP and TMP. Additional tests use:

- tests/uiux_acceptance.gd: set UIUX_EVIDENCE to a writable directory containing reports/ and temp/, UIUX_BASELINE to a frozen checkout of the base, and NATIVE5525_NODE to Node. Run headless using the installed Godot console executable, --audio-driver Dummy --path godot --script res://tests/uiux_acceptance.gd.
- tests/uiux_visual.gd: same evidence environment with captures/; omit --headless for real rendered window captures. This uses callbacks, not OS mouse/keyboard automation.
- UIUX_TEST_PART can restrict the acceptance script to party, shop, battle or input; omit it for the full run.

## Evidence and limits

Implementation evidence: G:/Apps/Codex/2026-10-07/task/uiux-implementation-20261008/reports and captures. The additional acceptance script passed 161 assertions at 1280x800, 1440x900, 1024x720, 1920x1080 and 800x600. Visible-window captures cover 1280x800, 1024x720 and 800x600. Existing UI parity (60), display regression (662), and legacy presentation/overwrite (68) also passed during implementation. Final combined validation is recorded in the external handoff report.

Passing assertions are supporting evidence, not sign-off of all 65 acceptance cases. Independent UX/debug review, actual OS 150% scaling, and subjective audio listening remain pending. Battle branches, the east shop location and the 25-person display fixture are labeled synthetic.

AC-P04 assumes the final porter can be removed. The base engine already rejects that composition. This behavior is preserved and checked against the frozen base. Absence warning/disabled departure is covered using display-only data. Requiring actual removal would be a game-rule change outside this UI scope.
