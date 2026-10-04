# Native integration validation — 2026-10-04

Runtime: 137 individual character WAV clips, six BGM WAV tracks, and eleven equipment effects. Launch with `Start-5525.cmd` from the repository root (Windows), or `python native/journey_app.py`. Requires Python with Tk and Node.js 22 or newer. Windows audio uses built-in winsound and MCI; no model weights or audio dependencies are required.

## Automated checks

Run `python native/check.py`: all eleven stages passed, including 113 Python tests and seventeen equipment test groups. Source parity and frozen baseline checks passed.

Additional Windows Tk checks (run from native):

- `python qa_audio_tk.py`: six tracks, natural battle loop, simultaneous voice/BGM, independent mute, scene changes, shutdown/device release, responsive Tk timer.
- `python qa_equipment_tk.py`: seven active equipment effects.
- `python qa_passive_trial_tk.py`: eight class/passive fixtures, including non-attacking porter.
- `python qa_battle_layout_tk.py`: nine screen/text-height combinations; return and confirm controls retain their required height, with working confirm/cancel callbacks.

## Independent manual GUI verification

Independent cloud Astra testing confirmed all eleven equipment effects through actual clicks; two normal battles (12 and 26 actions), delivery reward 117G, level 2, inn charge 30G, and the next request board; purchase and mid-deployment save/restart/load. It verified 137 voice clips, six BGM tracks, and correct mapping of eight new active skill cues. The final footer correction was checked against the exact app.py SHA-256 `a0d2efced88472bfd9f0cd11a56978a737dc3901130b58eaa849a07fa026a72e` (LF normalized). No remaining blocker was reported within this scope.

## Limits and asset provenance

Windows playback API and UI responsiveness were exercised; human voice quality and voice/BGM volume balance are not certified. Linux manual testing did not verify audible playback. Original audition approval applies only to the initial seventeen clips; later clips retain their manifest review status. Missing or invalid audio remains silent; no other character or skill is substituted. Passive effects do not emit active-skill voice cues.

See VOICE.md and MUSIC.md for playback behavior, provenance, and license references. Keep source archives outside the repository. Saves, caches, generated reports, credentials, preview mixes and model weights are excluded.
