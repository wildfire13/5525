# Redirected AppData save-path fix

When this PC exposes C:/Users/wildf/AppData/Roaming through a physical D: Codex cache directory, Windows rename/replace fails with WinError 17 even when the two logical paths have the same parent. The frozen bebf057 helper reproduces that failure on dedicated dummy data.

The candidate resolves the parent directory and pins the target returned by the read-only confirmation probe. Temporary creation and atomic publication use this same physical parent. A changed physical target rejects the confirmed write. Recovery carries the original pin across the helper process boundary; user-facing receipts retain the selected logical path. No drive/cache path is hard-coded and no copy-delete or direct overwrite fallback is introduced.

New-file creation stays exclusive. Confirmed replacement still verifies the existing SHA before atomic replacement; flush/fsync, operation-specific temp ownership and failure cleanup remain unchanged. The change does not alter save contents or the default logical save location.

Implementation verification: 17 adapter unit tests, and 30 real-path checks including the baseline failure, C logical / resolved D / G / Share new-save/readback/unconfirmed/stale-SHA/confirmed-replacement cases and four terminated-helper recovery cases on C. Dedicated generated dummy JSON only; Share verification is local and does not claim sync completion. Full combined regression and final preservation evidence are in the external handoff report.

Evidence: G:/Apps/Codex/2026-10-07/task/uiux-implementation-20261008/reports/save-real-paths.json
Reproducer: G:/Apps/Codex/2026-10-07/task/uiux-implementation-20261008/probe_save_fix.py
