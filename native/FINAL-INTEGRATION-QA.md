# Integrated native candidate: a51a773 + presentation + images + SE + equipment r3

Base: `a51a7737b1c9f7e6310225c352692a735079a935`.
Worktree: `5525-presentation-work`, branch `battle-presentation`.
Release authorized after parent-reported independent GUI QA. Baseline before release:
the normal `5525-git` launcher checkout and remote main were clean at a51a773.
No personal save or portrait is part of this delivery.

User-approved balance update (2026-10-04): all four bows now require both hands,
including twin-bow. Greatsword ATK is 50 (was 38). All spear and hammer values and
the per-target sum/Snipe range-plus-one formulas are unchanged. Hammer comparison is complete: the parent accepted keeping one-hand occupancy and
ATK 29/39/29 (wood/iron/breaker), given Stamp plus offhand contributions and
knockback formation disruption. No hammer strengthening is included. This remains
approved for release after the independent GUI QA reported below.

## Included sources

- Portrait patch SHA-256 `ed7363bf92a988e1f52547a21e7a05a2ba43792d970590959d8bc0202b4f2f05`.
- Equipment **r3 only** SHA-256 `1c4ccd941dd4f6b173478359121e98a1bfedbacc50ca14c2847081405030fe7d`.
- SE runtime ZIP SHA-256 `4585e17e9e0753df039828d55729dc1b6001acb5a740cbdb675584f64f1245f3`.
- Sequential presentation, exact-character voice phase routing, strict HP warning,
  and Windows buffer-loop BGM backend described in PRESENTATION-CONTRACT.md and SE.md.

The full patch applies once to a51a773. It already contains the image and equipment
patches; do not stack those older individual deliveries on top. Existing 137 voice
clips and six BGM tracks are unchanged and omitted from the patch. They must already
be present in the a51a773 checkout. Eight new SE clips, their original manifest and
provenance/mapping text are included. `test_fixtures/campaign-a51a773-battle.json` is a
generated regression fixture, not a personal save.

## Merge decisions

- Engine keeps r3 target-by-target weapon contribution/preview rules, selected-skill
  lookup, and both presentation hooks and `stepEnemy`. Snapshot preparation does not
  dispatch audio during damage previews.
- Bridge keeps `select_skill`, skill source/range/damage preview fields, and the
  presentation lock/ACK protocol. Skill selection is rejected during presentation.
- App keeps the multiple-active selector, source/damage display, independent HP
  warning label, `resolve_portrait`, portrait canvas tags, and shared SE player.
- Skill selection buttons are disabled during presentation and stale callbacks are
  ignored. The actual selected skill ID routes voice and physical/cast SE.
- Shop keeps the selected member portrait above the selector and the new slot selector,
  eight-slot display, and slot-aware quote/purchase/trial callbacks.

## Verification on Windows

`python native/check.py`: **18 stages passed, 143 Python tests**. Includes all six r3
Node suites (slots, normal dual attacks, skill dual attacks, old-save migration,
two-handed occupancy, four weapon variants), existing rule/source parity, voice
routing, and sequential presentation. Supplementary presentation cases verify
target-filtered Snipe, splitShot and Stamp damage against previews, separate actual
HP phases, one MP/action consumption, exact skill voice keys and causal actor IDs.

`python native/qa_integrated_equipment_tk.py`: real Tk and Node, seven equipment cases:

- Sword + staff: distance 1 loses 40 HP with two contributions; distance 2 loses 14 HP
  with one contribution.
- Select the left-hand knockback skill through its real Tk button while trying a
  rest staff: 43 HP loss, correct `mage_skill_knockback_01.wav`, selected skill locked
  during its action, stale ACK rejected, and damage preview matches actual loss.
- Greatsword, one-hand spear, two-hand spear, and javelin: 50 / 23 / 34 / 21 HP loss,
  one contribution each, trial leaves campaign save unchanged, purchase/save/load pass.
- All eight slots and custom shop portrait coexist. The actual Python load path
  migrates an a51 legacy battle save plus an embedded custom portrait to revision 2;
  original file bytes stay unchanged and the migrated save round-trips.

Additional real Tk checks passed after merging r3:

- `qa_portraits_tk.py`: custom assignment/cancel/clear, shop/deployment/battle reuse,
  save and separate-process restart/load, old-save behavior.
- `qa_presentation_tk.py`: custom portrait during causal shakes, redraw stability,
  strict HP 25% boundary and healing recovery, lock/close behavior, one SE per area group.
- `qa_sound_phase_tk.py`: real action/impact/result SE, cancel without game mutation,
  no sound replay from redraw, end-of-window cleanup.
- `qa_battle_layout_tk.py`: all nine battle/campaign/trial footer layouts retain
  42px confirm and 28px return buttons.
- `qa_sound_effects_tk.py`: eight real clips, BGM/voice coexistence, separate mutes,
  four-gameplay-plus-one-UI SE bound and release.
- `qa_wave_loop_tk.py`: same Windows buffer/handle plays across the 22.851-second
  BGM loop boundary, no Tk restart, independent voice and cleanup.

All test files/saves/portraits were generated fixtures in temporary directories.
These checks do not substitute for the requested cloud manual GUI playtest or human
listening/volume-balance review. Linux can exercise UI/state tests but cannot verify
the Windows waveOut/winsound playback paths. Pillow is needed for custom images;
see requirements-portraits.txt. No new dependency was installed during integration.

## Approved bow / greatsword follow-up

- campaign.js: three Snipe bows have hands:2; equipment-skills.js: twin-bow has hands:2.
- Existing two-slot rules reject bow/offhand combinations and left-hand bow purchases,
  release the left slot on unequip/replacement, and count bow damage once.
- Old single-bow saves load without item/stat loss; current and rollback left-hand
  conflicts reject atomically with character/item and recovery instructions. Left-hand
  legacy bows are not silently moved or discarded. Source files remain unchanged.
- equipment-slots.js: greatsword-wood ATK 38 -> 50 only; STR14, reach1, price140 and
  hands2 unchanged. Shop/preview/trial/actual-damage tests use the same catalog value.
- Six two-handed test groups include every bow variant, atomic refusal, removal,
  replacement, original a51 battle fixture migration, rollback conflict and Snipe
  distance4 single contribution. Duplicate-skill source test now uses two staffs;
  synthetic engine tests still verify the general Snipe sum formula unchanged.

## Release verification (2026-10-04)

Parent reports fresh-a51 isolated patch verification and independent real GUI QA with
no blocking defect in the tested scope: causal actor/victim order, enemy sequencing,
HP threshold/recovery, equipment/bow occupancy, greatsword50, range sum/Snipe, custom
portraits, skill cancel/confirm, mid-window-close settlement, legacy migration and
new-process save restoration. This report supplements local tests; it is not a claim
that Windows sound was perceptually reviewed.

Final local aggregate: all 18 stages / 143 Python tests passed again. Manifest SHA256
checks passed for 137 voice WAVs, 6 BGM WAVs, and 8 SE WAVs. User-environment launcher
falls back from the nonworking py registration to Python313/python.exe; that Python
successfully initializes Tk and imports Pillow 12.3.0. No install was needed.

Remaining limits: Windows subjective listening/volume balance, exhaustive equipment
balance over long play, and repeated full delivery loops were not performed in this
final QA pass. Existing saves are never rewritten merely by updating the checkout.
