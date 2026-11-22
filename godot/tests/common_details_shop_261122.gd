extends "res://tests/shop_drag_261119.gd"

func run():
	var qa=OS.get_environment("INVENTORY_QA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	root.size=Vector2i(1920,1080);root.gui_embed_subwindows=true
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();game.audio.fast_mode=true;game.checks_fast=true
	var seed=await saved();seed.state.location="west";seed.state.gold=1000
	await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();await tap("FacilityChoice_buy")
	await tap("RosterMember_"+GUARD);game.pages.shop_view.set_inventory_tab("equipment");await settle()
	var before=await saved()
	await tap("Product_armor-cloth")
	var detail=node("SkillDetailsWindow")
	check(detail!=null and detail.visible,"product click opens common read-only detail")
	if detail==null:quit(1);return
	check(detail.find_child("SkillDetailsBody",true,false).text.contains("DEF 物5"),"cloth detail uses native equipment values")
	check(detail.size.x==576,"common detail respects shared three-column width")
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(qa.path_join("common-detail.png"))
	detail.finish();await settle()
	check((await saved())==before,"closing product detail preserves money and equipment")
	check(game.get_viewport().gui_get_focus_owner()==node("Product_armor-cloth"),"close restores product focus")
	await pointer_drop(node("Product_cloth-head"),node("ShopEquipped_head"),product("cloth-head"))
	check(node("PurchaseAgree")!=null,"detail closure preserves product-to-slot drag")
	await tap("PurchaseDecline")
	check((await saved())==before,"drag cancellation remains pure")
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
	for i in range(8):await process_frame
	quit(0 if checks.all(func(row):return row.passed) else 1)
