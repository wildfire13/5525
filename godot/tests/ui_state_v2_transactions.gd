extends SceneTree
# Current inventory purchases, with real engine responses and test-only transport delays.
class PurchaseProbe extends "res://tests/v2_bridge_probe.gd":
	var lose_purchase=false
	func request(payload: Dictionary) -> Dictionary:
		var reply=await super.request(payload)
		if lose_purchase and payload.get("action")=="buyInventory":
			lose_purchase=false
			return _disconnect("injected_lost_inventory_purchase")
		return reply
const GUARD="recruit-guard-human-female"
var game
var probe
var checks=[]
var q=OS.get_environment("UIUX_REVIEW_EVIDENCE")
func _initialize():call_deferred("run")
func node(id):return game.find_child(id,true,false)
func check(id,ok,detail):
	checks.append({"id":id,"passed":bool(ok),"detail":detail})
	print(("PASS " if ok else "FAIL ")+id+" "+detail)
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker:await process_frame
func fixture(gold=313):
	var value=preload("res://tests/ui_current_fixture.gd").fixtures()["synthetic-east"]
	value.state.gold=gold
	await game.update({"op":"campaign_load","data":value})
	game.shop_uid=GUARD;game.shop_slot="rightHand";game.navigate("shop")
	game.pages.facility_entry.choose("buy");await settle()
func saved():return (await probe.request({"op":"campaign_save"})).data
func buy_count():return probe.calls.filter(func(call):return call.get("action")=="buyInventory").size()
func confirm():
	await game.pages.shop_view.confirm_purchase("spear-wood",GUARD);await settle()
	return node("PurchaseAgree")
func run():
	DirAccess.make_dir_recursive_absolute(q.path_join("reports"))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	game.engine.close_engine();game.engine.queue_free();probe=PurchaseProbe.new();game.add_child(probe);game.engine=probe;probe.start_engine()
	await game.new_game();await fixture();var original=await saved()
	var accept=await confirm();var quoted=game.pages.shop_view.consent.duplicate(true)
	check("V2-S06",quoted.gearId=="spear-wood" and quoted.cost==90 and quoted.afterGold==223,"purchase uses full current price, without automatic trade-in")
	node("PurchaseDecline").pressed.emit();await settle()
	check("V2-S07",await saved()==original,"decline preserves complete campaign")
	accept=await confirm();var calls=buy_count();probe.hold_action="buyInventory";accept.pressed.emit();accept.pressed.emit()
	while not probe.holding:await process_frame
	check("V2-S10",game.pages.shop_view.stage=="S5" and buy_count()==calls+1,"duplicate confirmation sends only one inventory purchase")
	game.pages.shop_view.select_member("recruit-scout-elf-male");game.pages.shop_view.escape()
	check("V2-S10",game.shop_uid==GUARD and game.pages.shop_view.stage=="S5","pending purchase keeps recipient and stage")
	probe.release=true;await settle();var purchased=await saved()
	check("V2-S08",purchased.state.gold==quoted.afterGold and purchased.state.characters[GUARD].inventory["spear-wood"]==1 and purchased.state.characters[GUARD].weapon==original.state.characters[GUARD].weapon,"purchase adds inventory once and never auto-equips")
	await fixture(0);calls=buy_count();await game.pages.shop_view.confirm_purchase("spear-wood",GUARD);await settle()
	check("V2-S12",buy_count()==calls and not is_instance_valid(game.dialog.window),"insufficient money prevents confirmation and submission")
	await fixture();accept=await confirm();calls=buy_count()
	var poor=await saved();poor.state.gold=0;await probe.request({"op":"campaign_load","data":poor})
	accept.pressed.emit();await settle()
	check("V2-S14",buy_count()==calls+1 and not game.pages.shop_view.unknown and game.campaign().characters[GUARD].weapon==original.state.characters[GUARD].weapon,"engine rejects a purchase whose funds changed after consent")
	await fixture();accept=await confirm();calls=buy_count();probe.lose_purchase=true;accept.pressed.emit();await settle()
	check("V2-S14",probe.disconnected and not game.notice.is_empty() and buy_count()==calls+1,"lost purchase reply disconnects with recovery notice and is not resent")
	await game.reconnect_engine();await settle();await fixture()
	var before=await saved()
	for product in game.pages.offered().slice(0,10):
		game.pages.shop_view.open_comparison(product.id);await settle()
	check("V2-S20",await saved()==before,"browsing live products changes no campaign resources")
	await game.act("trial",[GUARD,"spear-wood","rightHand"]);await settle()
	game.choose_command("attack");probe.hold_action="preview"
	var target=game.data.choices.attack[0]
	for unit in game.state().units:
		if unit.id==target:game.on_cell(int(unit.pos));break
	while not probe.holding:await process_frame
	game.cancel();probe.release=true;await settle()
	check("V2-B17",game.pending==null and game.preview.is_empty() and not game.can_commit(),"cancel discards delayed battle prediction")
	var file=FileAccess.open(q.path_join("reports/v2-transactions.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks},"  "));file.close()
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();probe.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
