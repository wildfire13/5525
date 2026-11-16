extends "res://tests/ui_feedback_20261016.gd"
func price_fits(product: Button) -> bool:
	var labels=product.find_children("*","Label",true,false)
	var prices=labels.filter(func(label):return label.text.ends_with("G"))
	var titles=labels.filter(func(label):return label.text==product.tooltip_text)
	return prices.size()==1 and titles.size()==1 and titles[0].clip_text and titles[0].get_global_rect().end.x<=prices[0].global_position.x and product.get_global_rect().encloses(prices[0].get_global_rect())
func run():
	create_timer(50).timeout.connect(func():print("FAIL compact review watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true
	var seed=await saved();seed.state.location="west"
	await game.update({"op":"campaign_load","data":seed});await enter_facility("shop")
	var before=await saved();var shop=game.pages.shop_view
	var rows=node("ShopProductsScroll").find_children("Product_*","Button",true,false)
	check(rows.size()==shop.offered().size() and rows.size()>=8 and rows.all(func(row):return row.size.y==68),"standard catalog products use compact 68px rows")
	var viewport=node("ShopProductsScroll").get_global_rect()
	check(rows.filter(func(row):return viewport.encloses(row.get_global_rect())).size()>=8,"at least eight standard products fully visible at FHD")
	shop.select_slot("feet");await settle()
	rows=node("ShopProductsScroll").find_children("Product_*","Button",true,false).filter(func(row):return row.is_visible_in_tree())
	check(rows.size()==shop.offered().size() and not rows.is_empty() and rows.all(func(row):return row.size.y==68),"feet filter retains compact rows for every current product")
	var item=shop.offered().filter(func(g):return g.id=="swift-boots")[0]
	var original=item.name
	item.name="長い商品名の表示確認".repeat(20)
	for dims in [Vector2i(1920,1080)]:
		root.size=dims;game.render();await settle()
		var product=node("Product_swift-boots")
		check(product.size.y==68 and product.tooltip_text==item.name and price_fits(product),"long title retains its tooltip, row height and visible price "+str(dims))
	item.name=original;game.render();await settle()
	check(price_fits(node("Product_swift-boots")) and node("Product_swift-boots").size.y==68,"short title restores compact product presentation")
	check((await saved())==before,"catalog presentation changes leave campaign untouched")
	var f=FileAccess.open(evidence.path_join("compact-review.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"standard_shop_row_px":68},"\t"));f.close()
	game.closing=true;game.invalidate_preview();await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
