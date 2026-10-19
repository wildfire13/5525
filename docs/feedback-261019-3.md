# 261019 UI feedback3

Base18194a89289fb6274a4ea40835b713ad8ebf3deb. Product main push is deferred until GUI acceptance and a separate instruction.

Source: private wildfire13/5525_temporary-storage commit59355b0610cacf0f9b9203153dfcb2e9c01158ab, root261019_5525_UI_feedback3.zip (2,409,662bytes). Inner workbook2,486,067bytes, SHA25661a674700e798336d8870dd7de4e591de839614d37a94ebd9766d1806ae64413. ZIP CRC and exact workbook hash verified. Sheets1–5 drawings, arrows, shape geometry and actual image1–5 pixels (1920×1032 each) reviewed; template excluded. The five source images are distinct; sheet4 repeats its source image with additional annotations.

## Five sheets

1. Weapon-shop filtering uses weapon type, derived from current products; armor/accessory stores retain equipment-slot filtering. Consumable shop filters by item. All stores have a dropdown product-list heading: 商品リスト（すべて） with no icon, then category icon and 商品リスト（…のみ）. Redundant 装備を購入 and separate 部位フィルター labels are removed. Facility returns use one green 広場に移動 at bottom right above portraits, including guild/inn/board/map/result.
2. Board title is 地名の掲示板. Party-count and cumulative-time clutter are removed from the top header. History and cumulative hours are available from the new action-log window. Native history, retention and export data are unchanged.
3. Completed delivery says 配達完了！; late delivery keeps its 遅配 qualifier. Result removes obsolete travel/items tabs, old history excerpt and shop shortcuts. The lower-right return calls the existing acknowledge operation. Arrival still reaches the hub without paying rewards; HubDeliverCargo remains the manual delivery action. Generic selection guidance is suppressed on noncombat pages while actual notices and combat guidance remain.
4. Status title is only in the window titlebar. The equipment tab's owner inventory has a single heading/filter row, ガロのインベントリ, aligned item-name columns, direct usable-item 使用 and shop 売却 controls. Both route into existing target/quote/confirmation transactions; old item-action controls remain. Existing narrow status windows are widened ONCE to at least1760px, capped to the current viewport; height is retained. Fresh default remains2080×780 screen-capped. The migration marker is local UI configuration; later manual resizing is respected. This intentionally supersedes the previous feedback2 behavior of keeping the old narrow width untouched. No campaign-save migration is introduced.
5. Menu begins セーブ/ロード/行動ログ; ログ保存 is inside the action-log window. Removed 画像 menu entry (status portrait editing remains), and 拠点・旅程へ (ordinary hub navigation duplicated facilities and was not a debug function). 新しい旅 is immediately before 閉じる. BGM/voice/SE start muted, with checkboxes reflecting that state; users can opt in.

## Junkie review

- R01: hovered unit's foot tile gets an outline; selected targets retain a fixed outline and 選択中. No hit-testing or camera behavior changed. Pointer hover and floor-click contract are checked without committing an action.
- R02: hover states the actual damage recipient and HP loss. Main prediction groups intended target, actual recipient and HP delta using existing damagePreview; no formula, MP or action-cost changes.
- R03: comparison anchors beside its candidate button, flips locally left if necessary and clamps inside the root viewport. It no longer jumps to x=8 when no outside strip exists. Old hover windows are hidden and retired before replacement to avoid duplicate names/lifetime collisions. Negative desktop coordinates were not established as a cause.
- R04: floating-panel background alpha is243/255 (about95.3%); front order and dragging are unchanged.
- R05: skill/item confirmation uses the action name plus を確定; no extra step.
- R06 held: no clear policy was found authorizing disclosure of enemy roles at route-choice time. No inferred healer hint or new hidden-information disclosure was added. I06 cargo wording and I13 no-shop guidance remain held.

## Verification

Godot16 invocations /526 passing checks, including76 new feedback3 checks,56 panel/camera input checks,32 skill checks and88 hover-lifetime checks. Existing native inn6 and preview7 Python tests pass;5 dual-skill groups pass; long-log regression runs1452actions/4014real lines and proves unchanged gameplay against an unbounded-log control. Full logs are in the transfer artifact. Run `python godot/tests/run_feedback_261019_3.py --evidence /path/outside/checkout` with Godot, Node and Python available.

Existing tests updated only where intentionally changed UI expectations required it: return text, filter labels/types, grid child count, recipient-caption text. frontend_smoke explicitly opts into sound for its sound-event assertions; playtest defaults remain muted. The hover-lifetime harness uses /proc on Linux to avoid Godot4.6 reporting errno10 when querying already-reaped child PIDs, retaining the owned-process-exit assertion.

An extra obsolete hover_regression still calls removed set_camera and stops identically on the pre-change battle_board implementation. It is not counted passed. The prior known followup_ui_regression/shop_quote_lifecycle failures remain outside this passing set; they were not claimed fixed by this task.

GUI acceptance remains pending: FHD and1364×1024 readability/spacing, long names, overlapping windows, fixed target outline visibility, equipment comparison placement near either edge and negative-coordinate desktop monitors. Headless tests do not establish visual acceptance. No native rules, accessories' behavior, CCT, saved camera settings or campaign-save format were changed.
