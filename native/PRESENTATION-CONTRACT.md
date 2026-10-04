# Sequential battle presentation integration contract

Worktree: `5525-presentation-work`, base `a51a773`, branch `battle-presentation`.
Uncommitted integration candidate; do not deploy independently.

The candidate now includes the portrait-images patch and real eight-clip SE package.
See SE.md for source hash, mapping, and integrated tests. Equipment-slot r3 changes are now included; see FINAL-INTEGRATION-QA.md. Use the combined delivery patch on a51a773; do not stack the original
image patch on top of it.

## Protocol

- Tk opts in with `presentation: true` on `act`, campaign/journey `begin`, and standalone `reset`.
- Response adds `presentation: {id, index, action_id, impact_group_id, phase, actor_id, unit_id, kind?, skill_id?, target?, from?, to?, label, voiceEvents}`.
- Phases: `action`, individual `move`, positive-damage `hurt`, positive-HP `heal`, `settled`.
- `state` in the response is the state of that phase, including intermediate HP/position/log/MP. It is also the state returned by `view`; future HP changes are not exposed as the current state.
- `presentation_next {id,index}` acknowledges exactly the visible phase. A repeated/stale token does not advance. The next enemy turn is executed only after the prior action's settled phase is acknowledged.
- Within one action, rules prepare an ordered sequence of snapshots. HP/position setters capture individual writes, including repeated hits, healing after damage, and the actual cover recipient. A single action's snapshots are replayed into the authoritative battle object; later enemy turns have not been executed yet.
- `presentation_finish {id}` settles the accepted batch once without replaying its sound. Window destruction calls this before releasing the bridge. A hard process exit loses only unsaved progress, as before.
- During presentation, bridge mutations, save/load, preview, reset, and export are rejected. `view`, presentation acknowledgements, and non-mutating audit `record` remain available. No presentation fields enter the save schema.

## Engine/equipment merge points

Keep `Presentation.mark(s,a,kind,target,{activeSkill,skillName})` at `apply` entry, and an equivalent marker at `enemyAction` entry (including misses). Nested apply of the same actor is deduplicated. Keep `Presentation.isStepping(s)` in `advance`, plus exported `stepEnemy(s)`.

The `skill_id` and voice cue must come from the actually selected skill. When integrating multiple active slots, forward that selection through the engine's existing `activeSkill` context; never infer a different skill from character job or replace unavailable voice clips. Passives do not produce active-skill speech.

Each `hurt` belongs to its own `actor_id` and `action_id`; never transfer damage from a later enemy action into an earlier ally action. No HP decrease means no hurt phase. Area recipients are separate phases. `impact_group_id=0` currently groups impacts within one action for optional SE deduplication; repeated actor actions have distinct action IDs.

## Portrait/HP merge points

`app.py` must keep canvas tags `portrait:<unit_id>` on whichever image/shape `resolve_portrait` draws. Animation moves only that tag, never another character or the HP text. A lethally hit portrait remains visible during its hurt phase, then disappears.

`battle_presentation.low_hp` uses `hp * 4 < max` (strict inequality). Board HP, the current actor HP label, and HP ranges in the status text use bold red below the threshold. At 25% and after healing to/above it they return to normal styling.

`CampaignBattleApp` must not re-enable retreat during a phase. Trial exit/window close may settle and leave safely. Preserve parent image/gear UI changes when merging `app.py`, `campaign_app.py`, and `journey_app.py`.

## Audio

One phase dispatches its exact character voice once; Tk waits for its nominal WAV duration plus a margin before acknowledging. Repeated identical character/cue within one action is deduplicated; every positive hit still has its own visual phase. No per-animation-tick playback. Voice mute skips only speech, not game phases. New SE must use its own audio handle, never winsound (which owns character speech).

`App`/`TrialBattleApp` accept an optional `sounds=` player. Campaign owns and shares it.
`SoundPlayer.phase` uses `action_id / phase / impact_group_id` and actual `skill_id`;
repeated draws do not dispatch sounds. Preserve this optional argument when merging
equipment UI. The frame waits for whichever is longer, its character voice, SE or
minimum visual duration. Preserve `resolve_portrait` and the `portrait:<unit_id>` tag
together; the phase timer restores offsets relative to the actual canvas coordinates
so redraw during a shake cannot accumulate drift.

BGM's default backend is now `wave_audio.WaveOutput`: one PCM buffer with Windows loop flags, one waveOutWrite, no Tk stop/restart at loop boundaries. Original six WAVs are unchanged. `WindowsMusic` in music.py remains the old MCI diagnostic backend only. No new dependencies.

## Verification commands

`python native/check.py`, `python native/qa_presentation_tk.py`, `python native/qa_wave_loop_tk.py`.
The last script verifies real Windows buffer continuity across the full battle track's 22.851-second boundary, independent voice/mute, and device cleanup; it does not claim human listening or loopback-recording proof.
