# Sound effects and presentation integration

This uncommitted candidate integrates the image patch, sequential battle presentation,
strict below-25% HP warnings, buffer-loop BGM playback, and eight real sound effects.
Equipment-slot r3 changes are now included; see FINAL-INTEGRATION-QA.md.

## Runtime source

Input: `5525-se-runtime-v1.zip`, 252,526 bytes,
SHA-256 `4585e17e9e0753df039828d55729dc1b6001acb5a740cbdb675584f64f1245f3`.
All eleven ZIP entries passed CRC, duplicate/path/symlink checks. The eight WAVs matched
the unchanged schema-2 manifest's SHA-256, size, frame count, 48 kHz mono PCM16 format,
and zero endpoints. Original ZIP and existing 137 voice / six BGM WAVs were not modified.

Runtime root: `assets/se/`. The original `manifest.json`, `README_JA.txt`, and
`EVENT_MAPPING.txt` are retained. The manifest identifies these as original procedural
synthesis with no third-party samples, models, or paid services. Its original subjective
review flags are preserved; consumer playback verification is reported below.

## Mapping and lifecycle

| Event | SE |
|---|---|
| Physical attack or physical skill begins | attack |
| Nonphysical skill / return cast begins | skill (no simultaneous attack) |
| Actual positive HP loss | hit |
| Actual positive HP recovery | heal (no hit) |
| Accepted noncombat command / completed save | confirm |
| Cancel, back, invalid target/menu | cancel |
| Entry into victory result | victory |
| Entry into defeat / porter failure result | failure |

One sound per `(cue, action_id, phase, impact_group_id)`, never per animation tick.
Area hits share one impact group. A later enemy action has a different action ID.
No confirm sound is added to battle action confirmation, battle begin, trial entry/exit,
or battle-result transition. View/preview and redraw do not dispatch sounds.

`SoundPlayer` owns up to four gameplay SE handles and one UI SE handle. These are SE
channels, not character voices. Finished handles are released, and oldest SE of the same
channel category is replaced when full. No backlog is queued. The independent SE mute
stops only SE; BGM and character voice retain their own controls and playback handles.
The campaign shares its SE player with battle/trial children. Leaving battle stops SE;
destroying the owner cancels its timer and releases all its handles. Missing/corrupt
assets or unavailable audio devices do not advance or block gameplay.

The original PCM samples and prepared levels are used without normalization or trimming.
`wave_audio.WaveOutput(loop=False)` handles SE, while BGM uses the same device API with
buffer loop flags. `winsound` remains exclusive to character voices.

## Validation

- `python native/check.py`: all eighteen stages passed, including 143 Python tests.
- `python native/qa_portraits_tk.py`: real Tk/Node assignment, cancel, clear, shop,
  deployment/battle image reuse, old saves, embedded image save and separate-process
  restart/load passed. Generated temporary fixtures only.
- `python native/qa_presentation_tk.py`: custom image remains attached to the correct
  character during action/hurt phases, redraw causes no offset drift, two area recipients
  produce one actual hit SE, HP boundaries and close/duplicate-input behavior passed.
- `python native/qa_sound_phase_tk.py`: real confirmation controls and engine phases
  dispatched skill/heal, attack/hit/victory, and attack/hit/failure exactly as above;
  cancel left the state unchanged, redraw did not replay sounds, close released SE.
- `python native/qa_sound_effects_tk.py`: all eight original WAVs played through Windows
  waveOut, alongside BGM and character voice; pool limits, independent mutes, Tk timer
  responsiveness, and cleanup passed.
- `python native/qa_wave_loop_tk.py`: unchanged BGM buffer remains submitted across its
  full 22.851-second loop boundary; no Tk stop/restart, voice coexistence, and release pass.

These are automated real-widget/API checks. Human visual review, listening quality and
final cross-bus volume balance remain for parent integration QA. No commit, push, or
normal-launch checkout update is authorized at this stage.
