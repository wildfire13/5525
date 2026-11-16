extends SceneTree
var game
var checks=[]
var q=OS.get_environment("UIUX_REVIEW_EVIDENCE")
const GUARD="recruit-guard-human-female"
func _initialize():call_deferred("run")
func node(id):return game.find_child(id,true,false)
func check(id,ok,detail):
	checks.append({"id":id,"passed":bool(ok),"detail":detail})
	print(("PASS " if ok else "FAIL ")+id+" "+detail)
func settle():
	for i in range(8):await process_frame
	while game.locked or game.engine.busy or game.presenting or game.pages.shop_view.quote_worker:await process_frame
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func fixture():
	await game.update({"op":"campaign_load","data":preload("res://tests/ui_current_fixture.gd").fixtures()["synthetic-east"]})
	game.shop_uid=GUARD;game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
func run():
	DirAccess.make_dir_recursive_absolute(q.path_join("reports"))
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.audio.fast_mode=true;game.checks_fast=true
	for dims in [Vector2i(1920,1080)]:
		root.size=dims;await fixture();var before=await saved()
		for product in ["spear-wood","javelin-wood"]:
			game.pages.shop_view.open_comparison(product);await settle()
			var comparison=node("ShopComparisonStats").text
			for cycle in range(3):
				await game.pages.shop_view.confirm_purchase(product,GUARD);await settle()
				check("N01",is_instance_valid(game.dialog.window),"current inventory purchase opens consent")
				node("PurchaseDecline").pressed.emit();await settle()
				var cancelled=await saved()
				check("N01",node("ShopComparisonProduct")!=null and node("ShopComparisonStats").text==comparison and game.shop_uid==GUARD and cancelled==before,"cancel preserves owner, comparison and exact campaign")
				var message="操作説明 "+"長い文を繰り返して全文の保持を確認します。".repeat(20)
				game.notice=message;game.render();await settle();game.show_status_details();await settle()
				var popup=game.dialog.window
				check("N02",popup!=null and popup.find_children("*","Label",true,false).any(func(label):return label.text.contains(message)),"full explanation retains exact source")
				game.dialog.close();await settle()
				game.render();await settle()
				var rebuilt=await saved()
				check("C01",str(game.footer.get_meta("full_message",""))==message and rebuilt==before,"closing explanation and rebuilding preserve status and campaign")
			await game.act("trial",[GUARD,product,"rightHand"]);await settle()
			game.choose_command("guard");await game.commit();await settle();await game.act("endTrial",[]);await settle()
			var restored=await saved()
			check("TRANSITION",game.page=="shop" and restored==before,"trial returns to shop with exact original resources")
	var file=FileAccess.open(q.path_join("reports/repeated-state-v2.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks},"  "));file.close()
	game.closing=true;game.dialog.close(false);await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(6):await process_frame
	quit(0 if checks.all(func(c):return c.passed) else 1)
