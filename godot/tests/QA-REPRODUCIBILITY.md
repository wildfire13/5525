# Windows QA from a clean checkout

Use the already installed Godot 4.6.x console executable, Node 22+, and Python 3.10+ with Pillow. No personal saves, portraits, prior QA output, or sibling demo directory is required. Keep the tracked native and godot directories together.

```powershell
python -X utf8 -B godot/check.py --full
```

The runner imports Godot resources before executing the suites. In the standard workspace the shared reports go to `QA/現行版用/results/<run>/evidence`. For a standalone checkout or CI, pass `--evidence` with a directory outside the game. Runtime details contain executable names and versions. The aggregate check uses a disposable profile. For standalone visual captures set `UIUX_REVIEW_EVIDENCE` to the external evidence directory. Use isolated APPDATA, LOCALAPPDATA, TEMP and TMP for QA. For a standalone display test, import resources first, then run `--headless --audio-driver Dummy --path godot --script res://tests/display_regression.gd`. The test creates its report directory and exits nonzero if output cannot be created, opened or written.

The launcher regression creates a disposable minimal project with the documented `runtime/godot` layout and copies the supplied existing console executable plus its adjacent GUI companion there. Node and Python are found through a temporary child-process PATH. This exercises automatic discovery without assuming a particular PC's sibling folders. Explicit-runtime validation and actual app start/stop still run against the checkout. No runtime is installed or downloaded.

Known P3: labels and HP can overlap in the low camera view. This QA follow-up does not change product code, visuals, prices or effects.
