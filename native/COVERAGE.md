# Native acceptance matrix — Official gameplay prototype

Date: 2026-10-02. Scope: currently implemented functionality in `5525/prototype/index.html` and `battle.html` at source commit `0b77f6bc3f18d02359f7376a0936ad5a8a67a173`. Independent gameplay-testability review passed; designated the official gameplay prototype on 2026-10-02.

## Evidence categories

- **Rules**: byte-identical `battle.js`, `journey.js`, `play-log.js`; seven original assertion-preserving rule suites and source hashes
- **Adapter**: separate actual Node process, Python tests; full state parity after every action for five journeys/ten battles/285 allied actions, plus standalone30 actions
- **Native GUI**: supported native CUA input, observed real Tk screenshots. No browser/DOM simulation is counted here
- **Boundary GUI**: labeled fixture; does not count as a complete ordinary GUI playthrough. Journey boundary fixtures are generated only via public game operations and real combat, never HP/phase/reward injection
- **Declared difference**: implementation/presentation deviation kept explicit; not silently treated as parity

## Current feature matrix

| Existing feature and source anchor | Native implementation | Automated evidence | Actual native GUI evidence | Limits/differences |
|---|---|---|---|---|
| Two entry points (`index.html`, `battle.html`; `Battle.create`, `Journey.create`) | Journey shell and independent standalone window; journey toolbar entry | Mode/run/reset tests; standalone parity | Both launch; toolbar opens fresh4v4 while active journey remains unchanged | Separate native windows |
| Two jobs, cargo/capacity/deadline/reward (`Journey.jobs/accept`; `cycleRender`) | Both jobs and preparation display | Both jobs/one acceptance gates | Medicine accepted in full run; parts accepted normally and displayed in boundary completion | Capacity remains informational as source |
| Eleven candidates, max5, mandatory porter (`Battle.roster`, `Journey.select/depart`) | Full picker, count, disabled excess choices, porter warning | Invalid/duplicate/max tests;126 combat teams and336 porter teams | Remove porter disables departure; replace guard with warrior; select both Towa/Haru; distinct HP/MP | Every composition not GUI-played |
| Both kits and convoy/flank (`Journey.depart`, `Battle.create`) | Native radio controls; identical battle creation options | Both kits/placements; maxMp carryover tests | Ether/flank in full run, medicine/convoy with two porters; MP bonus and inventories observed | Pre-battle party text mirrors source base-stat display |
| Two road choices/two legs (`Journey.travel/forecast`) | Route buttons, opponent counts, elapsed/deadline display | Short/safe, exact deadline,5 full deliveries | Both safe legs in ordinary full run; short normal first leg; time/enemy count shown | All route combinations not GUI-played |
| Deadline confirmation/back/Escape/continue (`cycle.js:confirmDeadline`) | Modal native dialog, no mutation before Continue | Forecast read-only/strict lateness tests | Safe-route warning, Escape no time change, reopen+Continue; rest warning+Continue | Final wording corrected to “出発から”; no new forecast formula |
| Deployment/drag/swap/reset/start (`Battle.deploy/begin`, `renderDeployment`) | Native board, roster, click/drag, own-side restriction, initial reset | Source deployment suite and adapter phase/overlap/resource tests | Click swap; drag relocation; enemy-side drag rejection; repeated reset preserves enemies/time/HP/MP; begin | Dead-unit and every edge guard primarily rules-tested |
| Deployment feedback (`renderDeployment`) | Formation slots/status, selected attack reach, legal scout ambush markers, enemy HP/MP, portrait affiliation | Engine-derived metadata; source hash parity | Candidate03 green ambush target, blue range, enemyMP, corrected visible rejection footer | 2D continuous board |
| AGI turns/movement/attack (`Battle.paths/act/advance/queue`) | Full rules,10-entry queue, current reach/HP/MP, cancel/confirm | Full state parity; original battle suite | Ordinary two battles10+21 actions; moves, attack, enemy phases, invalid click, repeated Confirm/reset, affiliation during invasion | Native adds Confirm to attacks/items/guard |
| Guard/heal/Cover/potion (`Battle.apply/receive`, `legalFor`) | All native command/target flows with precise hints and no-target reason | Original support/potion/cover/expiry assertions | Guard halves hits; heal restores cappedHP and spendsMP; potion inventory1→0; labeled Cover keeps RinoHP30 while Garo180→155/MP6→5; covered ally displayed | All support range/expiry permutations primarily rules-tested |
| Scout ambush (`Battle.ambush`; source `app.js` preview) | Forward-only journey / two-way standalone; landing ghost and range/risk preview | Source path/direction assertions; read-only preview landing/range tests | Ordinary journey ambush crossed boundary+attacked; Candidate03 forward-only/no-target hint; standalone landing+danger preview | Full route overlay replaced by landing/ghost/range text; rule path unchanged |
| Snipe/Stamp (`activeSkill`, `attackReach`, `stampCells`) | Both skills; enemy-only3-cell preview; target/empty-center handling | Original four-direction/edge/MP0/empty/friendly-center assertions; preview regressions | SnipeMP4→3; Stamp empty center enemy100→74, ally105/outside enemy180 unchanged; cancel/reset; ordinary journey Stamp | All directional/edge fixtures not individually GUI-clicked |
| Formation/porter swap/boost/failure (`formation/boosted/swapTarget/check`) | Occupancy rules, boost status, no-attack porter, swapping and failure | Source nonstacking/expiry/break/reform/either-porter tests | Ordinary porter boost+swap; Candidate03 two independent porters eachMP6→5; swap ghost/formation/overlapping danger+cancel; porter failure while allies survive | Exact nonstacking damage primarily rules-tested |
| Enemy AI/fixed forecasts (`plan/enemyAction`) | Unchanged AI; target names/reasons/cells; danger/overlap/destination overlays | Original fixed-cell/path/empty-cell cases | Vacated-cell Snipe misses; attacks/movement/support intents; double warning!2 and two resolved hits | Immediate log/state updates instead of particles |
| Move/skill preview (`source app.js render/preview controls`) | Ghost future positions, swap partner, attack/skill inspection, formation transition, legal target names, destination threats, locking competing commands |7 preview tests: no mutation, Stamp names, scout normal landing range, porter path, invalid/deploy/terminal gates | Attack→skill inspection after hypothetical move; formation break; landing danger; porter swap ghost+cancel; Stamp3-cell border | Extra Confirm remains explicit; no action consumed before confirm |
| Battle return/camp/carryover (`Journey.finishBattle/rest/onward`) | Return button, once-only advancement, rest/onward, second deployment | Five real-process journeys, rest/no-rest, maxHp/maxMp/potions, duplicate gates | Full first return+1h, MP/potions retained, rest+2h/caps/disabled repeat, second deployment and battle | Full GUI run used rest; no-rest verified by reachable fixtures+adapter |
| Delivery/completion/rewards/failure/retry (`Journey.deliver`, `cycleRender/restartJourney`) | Explicit delivery, job-specific story/party art, reward view, failure reason, clean retry | Both jobs/rest combinations; exact deadline; fixture reachability tests | Full ordinary medicine12h late117G/XP60/Lv1; labeled parts6h150G/XP100/Lv2; labeled actual-combat porter failure0G/XP0; retry from both terminal branches | One ordinary full GUI delivery; other terminal branches explicitly fixture-backed |
| Diagnostic log/export (`PlayLog`, `exportPlayLog`) | Original bounded schema, local explicit native Save dialog, restart runs, independent mode | Original retention/immutability tests; adapter run/mode/reject tests | Real journey JSON837619bytes/105events; real standalone JSON/battle-mode parsed; export Cancel keeps gameplay; save success visible | Save-error recovery branch exists but no destructive/permission-error GUI test; no progress-save/replay |
| Current presentation (`world.js`, CSS, app/cycle markup) | Original character image copies, names/HP/MP/AGI, affiliation, cover/boost, hints, readable logs/story/results | Copied-rule hashes; asset copies | Portraits, range/forecast colors, story/party completion and current state observed | **Not visual parity:** Three.js3D road/cart, particles and entrance animations not reproduced; text/2D equivalents expose gameplay outcomes |

## Actual GUI runs and saved artifacts

1. Tiny native experiment: select/move/HP6→3→0/death/invalid/reset. Preserved as `tiny_poc.py`.
2. Initial expanded battle: standard movement/cancel/commit, fixed-cell miss, attack/Snipe, terminal victory/defeat/porter boundaries, reset.
3. Full ordinary native journey: medicine; archer/mage/scout/porter/warrior; ether/flank; safe+safe; rest; battles10+21; late12h117G/XP60/Lv1; completion/rewards/retry. Native saved file `5525-native-journey-20261002-182032.json`, parsed105events and0dropped.
4. Candidate03 feedback: continuous ranges, full queue, recipients, no-target/skill hints, ghosts and preview switches, Cover interception; saved `5525-native-battle-20261002-183348.json` parses battle-mode/null journey. Save cancellation leaves state intact.
5. Candidate03 boundary screens: on-time parts fixture from public engine battles31+25 actions; actual clicks Delivery→Completion→Rewards150G/XP100/Lv2→Retry. Failure fixture from actual one-porter combat11actions; failure reason/0rewards→Retry. Both screens retain permanent QA labels until retry.
6. Candidate03 normal two-porter parts setup: medicine kit/convoy/short; deployment green ambush marker, enemyMP, rejected drag with visible notice, repeated reset, live overlapping forecasts, stage1 hint, both porter boosts, swapped future positions and cancellation.

Screenshots were observations of actual native windows, not synthesized. No exported screenshot files are included. Candidate03 in the evidence history denotes the tested build promoted to this official prototype.

## Automated checks

Run `python check.py` for the final aggregate report in `qa-check-report.json`.

-30 Python tests: 23 tiny model/bridge/journey/preview tests plus 7 mocked Windows-bootstrap safety tests
-Standalone30-action exact state parity
-Five adapter journeys/ten battles/285 allied actions; only source cycle's journey victory wording adapted
-Seven source suites with unchanged assertions (require paths only), frozen module hashes, optional live original-source/assertion identity (CRLF normalized to LF only for the original checkout; frozen native hashes remain byte-exact);20checks with source checkout
-Public-operation reachable boundary fixtures: on-time31+25 actions; failure11 actions; deterministic independent generation and unchanged global RNG

No DOM simulation is counted as native GUI evidence. Original Web source contents remain unmodified. The original Web files remain unchanged. No installed dependencies or network runtime were introduced. Windows validation is tracked separately from the cloud evidence below. QA exports remain in the original verification workspace and are excluded from version control.

## Gate interpretation and remaining disclosures

The existing gameplay rules and user-facing test controls are reachable in the native prototype. Representative native inputs and exact rule/adapter tests cover their outcomes. This does not assert every possible balance combination was played visually or that the native renderer reproduces all web visuals.

Meaningful differences requiring acceptance awareness: native2D instead of3D decorative world/effects, separate battle windows, additional confirmation on some commands, generic X11 accessibility rather than rich control labels, and no Windows packaging. These are kept explicit for the final review; **independent review passed and official gameplay prototype designation is recorded**.

Source has no independent encounter-event system, sound, equipment-change UI, progress save/load, replay, continuous campaign or post-result leveled-up new trip. No such feature is silently invented or counted as migrated.


## Windows startup correction (2026-10-02)

The Windows executor reported Python3.12.14 x64 with matching Tcl/Tk8.6.12 files, but ordinary Tk creation failed to find a usable init.tcl. A same-process `Tcl_FindExecutable` / temporary interpreter / `pwd` / interpreter deletion before Tk creation was observed to create the actual journey app (mapped1180×850,2 job choices,10 loaded images,Node alive). This was a runtime/window-object observation, not screenshot evidence. The shared bootstrap is gated to that exact existing runtime layout and versions. It respects differing explicit Tcl/Tk paths, restores process environment after initialization failure, and never edits installed resources or persistent settings. Seven mocked tests cover success/idempotence, ordinary platform/version no-op, explicit-path preservation, DLL mismatch, evaluation failure cleanup and null interpreter cleanup. Future runtime versions may require fresh diagnosis.
