# 5525 cloud migration history

The initial transfer snapshot below is historical. The old Web `prototype/` folder was later removed from the current tree; its code, images, QA evidence, vendored Three.js and MIT license remain at [the fixed removal baseline b723b4c](https://github.com/wildfire13/5525/tree/b723b4cdfb84f1b20fe895502d459092d412effb/prototype). The original snapshot text is also available at [that commit](https://github.com/wildfire13/5525/blob/b723b4cdfb84f1b20fe895502d459092d412effb/MIGRATION.md).

Current entrypoints are described in [README.md](README.md). `native/` remains the required Godot backend and asset source. Local regression checks use `python3 native/check.py`; historical source provenance and optional fixed-checkout comparison are documented in [native/source_tests/README.md](native/source_tests/README.md). Public repository visibility is the user's intentional choice for Actions costs and is unchanged. This cleanup does not operate on the user's PC.

## Initial transfer (2026-10-01)

Original: G:\Apps\CodexProjects\5525 (unchanged; not a Git repository).
Created 2026-10-01. Game: GoGo To Go; delivery RPG with non-attacking porters.
Historical planning and playtest reports were removed on 2026-10-20.
At the time of the transfer, prototype code, images, vendored runtime/license and QA evidence were retained.
Excluded: .serena (local tooling/cache), opencode.json (machine configuration), the reacquirable upstream Three.js development tree.
Historical runtime and rule checks: see the [fixed Web README](https://github.com/wildfire13/5525/blob/b723b4cdfb84f1b20fe895502d459092d412effb/prototype/README.md). That version used vendored Three.js 0.160.1 with its MIT license and required no package install or server.
Browser QA tools assume Windows Edge at a fixed path; cloud Linux requires later adaptation. No game code was changed.
Source hash/size/timestamp snapshots bracket copying and ZIP creation. Process command-line inspection was denied by Windows; stability observations do not prove Astra is idle.
Text files screened for common credential patterns; no matches. This is not an exhaustive security guarantee.
Only that initial transfer copy was initialized as Git, with a synthetic migration identity; the initial transfer itself had no remote, push or upload.
The initial snapshot proposed a private GitHub remote and later PC synchronization. Those notes are historical instructions, superseded by the user's current public-repository choice and the scope of each later task. Git history is preserved.
