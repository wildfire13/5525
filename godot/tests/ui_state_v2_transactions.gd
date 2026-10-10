extends SceneTree
var game
var probe
var checks=[]
var failures=[]
var q=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func check(id: String,ok: bool,detail: String):
	checks.append({"id":id,"passed":ok,"detail":detail});print(("PASS " if ok else "FAIL ")+id+" "+detail)
	if not ok:failures.append(id+" "+detail)
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker:await process_frame
func fixture(weapon: String="sword-wood",gold: int=313):
	var value=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uiux-review/synthetic-east.json"));value.state.characters.guard.weapon=weapon;value.state.gold=gold
	await game.update({"op":"campaign_load","data":value});game.shop_uid="guard";game.shop_slot="rightHand";game.navigate("shop");await settle()
func snapshot():
	await settle();return (await probe.request({"op":"campaign_save"})).data
func buy_count()->int:return probe.calls.filter(func(call):return call.get("action")=="buyGear").size()
func confirm():
	await settle()
	game.pages.shop_view.confirm_purchase();await settle()
	return game.dialog.actions.get_child(1) if is_instance_valid(game.dialog.window) else null
func run():
	if q.is_empty():q="user://v2-transactions"
	DirAccess.make_dir_recursive_absolute(q.path_join("reports"))
	root.size=Vector2i(800,600);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	game.engine.close_engine();game.engine.queue_free();probe=load("res://tests/v2_bridge_probe.gd").new();game.add_child(probe);game.engine=probe;probe.start_engine();await game.new_game()
	await fixture();var original=await snapshot()
	await game.preview_gear("sword-wood");check("V2-S11",game.gear_preview.same and not game.pages.shop_view.reason(game.gear_preview).is_empty(),"same item is disabled independently of zero cost")
	await game.preview_gear("staff-wood");check("V2-S11",game.gear_preview.cost==0 and not game.gear_preview.same and game.pages.shop_view.reason(game.gear_preview).is_empty(),"different zero-cost item is valid")
	var button=await confirm();button.pressed.emit();await settle()
	check("V2-S11",game.pages.shop_view.stage=="S6" and game.campaign().gold==313 and game.campaign().characters.guard.weapon=="staff-wood","zero-cost transaction equips once and returns receipt")
	await fixture("sword-iron-1");await game.preview_gear("sword-wood");check("V2-S11",game.gear_preview.cost==-65 and game.gear_preview.afterGold==378,"negative quote is not rounded or rejected")
	button=await confirm();button.pressed.emit();await settle();check("V2-S11",game.pages.shop_view.stage=="S6" and game.campaign().gold==378,"negative transaction returns 65G with canonical receipt")
	await fixture();await game.preview_gear("greatsword-wood");check("V2-S12",not game.gear_preview.eligible and game.gear_preview.reason.contains("左手"),"two-hand condition comes from engine without auto-unequipping")
	await game.preview_gear("porter-kit");check("V2-S12",not game.gear_preview.available and game.pages.shop_view.reason(game.gear_preview).contains("この店"),"unavailable means shop does not offer the item")
	await fixture("sword-wood",0);await game.preview_gear("spear-wood");check("V2-S12",not game.gear_preview.affordable,"insufficient gold remains rejected")
	await fixture();await game.preview_gear("spear-wood");button=await confirm();var calls=buy_count();probe.hold_action="buyGear";button.pressed.emit();button.pressed.emit()
	for i in range(4):await process_frame
	check("V2-S10",game.pages.shop_view.stage=="S5" and probe.holding and buy_count()==calls+1,"submission locks before await; duplicate pressed sends one buy")
	game.pages.shop_view.select_member("archer");game.pages.shop_view.select_slot("leftHand");game.pages.shop_view.escape()
	check("V2-S10",game.pages.shop_view.stage=="S5" and game.shop_uid=="guard" and game.shop_slot=="rightHand","S5 ignores member/slot/Esc mutation")
	probe.release=true;await settle();check("V2-S08",game.pages.shop_view.stage=="S6" and game.campaign().gold==293,"receipt waits for completed canonical response")
	await fixture();await game.preview_gear("spear-wood");button=await confirm();calls=buy_count();game.campaign().gold+=1;button.pressed.emit();await settle()
	check("V2-S13",buy_count()==calls and game.pages.shop_view.stage=="S7","stale confirmation never submits old quote")
	await game.pages.shop_view.recover_quote();await settle();check("V2-S13",game.campaign().gold==313 and game.gear_preview.afterGold==293,"retry refreshes canonical state then quote")
	await fixture();await game.preview_gear("spear-wood");button=await confirm();calls=buy_count()
	# A different client removes the money after the quote. The real engine refuses.
	var poor=(await snapshot()).duplicate(true);poor.state.gold=0;await probe.request({"op":"campaign_load","data":poor})
	button.pressed.emit();await settle()
	check("V2-S14",game.pages.shop_view.stage=="S7" and not game.pages.shop_view.unknown and buy_count()==calls+1 and game.campaign().characters.guard.weapon=="sword-wood","canonical purchase refusal is a known failure, not receipt or unknown")
	await fixture();await game.preview_gear("spear-wood");calls=buy_count();probe.drop_buy_reply=true;button=await confirm();button.pressed.emit();await settle()
	check("V2-S14",game.pages.shop_view.stage=="S7" and game.pages.shop_view.unknown and probe.disconnected and buy_count()==calls+1,"lost purchase response is unknown with no automatic resend")
	game.pages.shop_view.back_list();game.pages.shop_view.select_member("archer");game.pages.shop_view.select_slot("leftHand");game.pages.shop_view.select_product("staff-wood")
	check("V2-S14",game.pages.shop_view.stage=="S7" and game.shop_uid=="guard" and game.shop_slot=="rightHand","unknown outcome blocks context changes and further shop transactions")
	var old_epoch=game.pages.epoch;await game.reconnect_engine();await settle()
	check("V2-S14",game.pages.epoch>old_epoch and game.pages.shop_view.stage=="S0" and game.pages.shop_view.receipt.is_empty() and buy_count()==calls+1,"new Node epoch never proves old purchase succeeded")
	await fixture();probe.calls.clear();game.pages.cached_quotes.clear();probe.hold_action="previewGear"
	game.pages.shop_view.select_product("spear-wood")
	while not probe.holding:await process_frame
	game.pages.shop_view.select_member("archer");game.pages.shop_view.select_member("guard");probe.release=true;await settle()
	check("V2-S02",game.shop_uid=="guard" and game.gear_preview.characterId=="guard" and game.pages.quote_valid(),"A→B→A discards stale quote and applies current generation")
	check("V2-S20",await snapshot()==original,"all staged browsing and quote requests leave canonical resources unchanged")
	var before=await snapshot();var items=game.pages.offered()
	for i in range(mini(10,items.size())):await game.preview_gear(str(items[i].id));await settle()
	check("V2-S20",await snapshot()==before,"browsing ten products never changes money/equipment/HP/MP/items/EXP/quest")
	await game.act("trial",["guard","spear-wood","rightHand"]);await settle();game.choose_command("attack");probe.hold_action="preview"
	game.on_cell(25)
	while not probe.holding:await process_frame
	game.cancel();probe.release=true;await settle()
	check("V2-B17",game.pending==null and game.preview.is_empty() and not game.can_commit(),"cancel during delayed prediction discards old success")
	game.choose_command("move");await game.on_cell(23);await settle();game.hud.open_range_reference();await settle();old_epoch=game.pages.epoch
	await game.new_game();await settle();check("V2-G08",game.pages.epoch>old_epoch and not game.hud.range_reference and game.pending==null and not is_instance_valid(game.dialog.window),"new campaign invalidates open movement-reference state")
	var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"calls":probe.calls,"method":"headless real Node engine with test-only transport delay/drop subclass","os_input":false}
	var f=FileAccess.open(q.path_join("reports/v2-transactions.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  ",true,true));f.close();print("V2 TRANSACTIONS ",checks.size()," FAILURES ",failures.size())
	await settle();game.closing=true;game.dialog.close(false);await game.audio.finish_audio();probe.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if failures.is_empty() else 1)
