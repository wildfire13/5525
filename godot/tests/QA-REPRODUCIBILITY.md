# Windows QA from a clean checkout

Use the already installed Godot 4.6.x console executable, Node 22+, and Python 3.10+ with Pillow. No personal saves, portraits, prior QA output, or sibling demo directory is required. Keep the tracked native and godot directories together.

```powershell
$env:NATIVE5525_NODE = '<full path to node.exe>'
python -X utf8 -B godot/check.py --godot '<full path to the Godot console executable>' --full
```

The runner imports Godot resources before executing the suites. Outputs go to ignored `godot/qa` and `native/qa-check-report.json`. Use isolated APPDATA, LOCALAPPDATA, TEMP and TMP for QA. For a standalone display test, import resources first, then run `--headless --audio-driver Dummy --path godot --script res://tests/display_regression.gd`. The test creates its report directory and exits nonzero if output cannot be created, opened or written.

The launcher regression creates a disposable minimal project with the documented `runtime/godot` layout and copies the supplied existing console executable plus its adjacent GUI companion there. Node and Python are found through a temporary child-process PATH. This exercises automatic discovery without assuming a particular PC's sibling folders. Explicit-runtime validation and actual app start/stop still run against the checkout. No runtime is installed or downloaded.

`fixtures/python-launcher-baseline.json` contains the SHA256 of the original Git blob `fc36fdf7b5cbb6eeaff0a45b18f4e872f713bbe3:Start-5525.cmd`. Only CRLF is normalized to LF for Git checkout portability. The expected content comes from that historical source, never from the candidate under test. Personal hashes, absolute user paths and historical machine QA files are unnecessary.

Known P3: labels and HP can overlap in the low camera view. This QA follow-up does not change product code, visuals, prices or effects.
