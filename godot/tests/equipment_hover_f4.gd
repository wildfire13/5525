extends "res://tests/inventory_header_261020.gd"
const Grid=preload("res://screen_grid.gd")
var measurements={}

func move_pointer(at: Vector2):
	var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
	if DisplayServer.get_name()!="headless":Input.warp_mouse(at)
	root.push_input(motion)

func observe(source: Button,label: String,leave:=true):
	check(source!=null,"hover source exists: "+label)
	if source==null:return {}
	var anchor=source.get_global_rect()
	if source.get_window()!=root:anchor.position+=Vector2(source.get_window().position)
	move_pointer(anchor.get_center())
	await create_timer(.65).timeout
	var popup=source.hover_window
	check(is_instance_valid(popup) and popup.visible,"pointer opens shared hover: "+label)
	if not is_instance_valid(popup) or not popup.visible:return {}
	var rect=popup.get_global_rect()
	var area=root.get_visible_rect()
	var xs=[];var ys=[]
	for i in range(11):
		var point=Grid.cell_rect(area.size,i,i,0,0).position
		xs.append(point.x);ys.append(point.y)
	check(area.encloses(rect) and xs.has(rect.position.x) and xs.has(rect.end.x) and ys.has(rect.position.y) and ys.has(rect.end.y) and rect.size.x in [576.0,768.0],"FHD grid rectangle: "+label)
	check(popup.content.get_global_rect().end.y<=rect.end.y and not rect.intersects(anchor),"hover fits and leaves its source uncovered: %s %s > %s" % [label,anchor,popup.content.get_global_rect()])
	check(popup.mouse_filter==Control.MOUSE_FILTER_IGNORE and popup.find_children("*","Control",true,false).all(func(c):return c.mouse_filter==Control.MOUSE_FILTER_IGNORE),"overlay and every child ignore pointer input: "+label)
	var sample={"title":popup.title.text,"body":popup.body.text,"size":str(rect.size),"surface":popup.panel.get_theme_stylebox("panel").bg_color.to_html(),"ink":popup.body.get_theme_color("font_color").to_html()}
	measurements[label]={"rect":str(rect),"sample":sample}
	if leave and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"screenshot saved: "+label)
	if leave:
		move_pointer(Vector2(1917,5));await frames()
		check(not popup.visible,"pointer leave hides overlay: "+label)
	return sample

func run():
	create_timer(90).timeout.connect(func():print("FAIL compact hover watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(evidence.replace("\\","/").to_lower()+"/"):push_error("Isolated hover profile required");quit(2);return
	root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(1920,1080);root.gui_embed_subwindows=true
	game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	await game.new_game();game.checks_fast=true;game.audio.fast_mode=true;await settle()
	check(root.get_visible_rect().size==Vector2(1920,1080),"FHD root viewport")
	var seed=await saved();seed.state.location="west"
	check((await game.update({"op":"campaign_load","data":seed})).get("ok",false),"fresh west shop fixture")
	game.navigate("shop");await settle();await click("FacilityChoice_buy")
	var before=await saved()
	var cloth=await observe(node("Product_armor-cloth"),"shop-cloth")
	check(cloth.get("title")=="布製の旅装" and cloth.get("body","").contains("装備の基礎能力") and cloth.get("body","").contains("DEF 物5 / 火1") and cloth.get("body","").contains("属性相性"),"cloth hover shows full equipment details")
	var product=node("Product_armor-cloth")
	await observe(product,"shop-cloth-before-click",false)
	await pointer_click(product)
	var detail=node("SkillDetailsWindow")
	check(detail==null,"click on a hovered shop product selects inline without modal popup")
	if detail!=null:detail.finish();await settle()
	game.pages.shop_view.set_inventory_tab("equipment");await settle()
	product=node("Product_cloth-head")
	await observe(product,"shop-hat-before-drag",false)
	var popup=product.hover_window
	product.force_drag({"kind":"shop_product","item":"cloth-head","connection":game.engine.connection_generation,"epoch":game.pages.epoch,"token":game.campaign().inventoryToken},null)
	await frames()
	check(root.gui_is_dragging() and not popup.visible,"product drag starts and dismisses the shared overlay")
	var target: Button=node("ShopEquipped_head")
	var motion=InputEventMouseMotion.new();motion.position=target.get_global_rect().get_center();root.push_input(motion);await process_frame
	var release=InputEventMouseButton.new();release.position=motion.position;release.button_index=MOUSE_BUTTON_LEFT
	root.push_input(release);await settle()
	check(node("PurchaseDecline")!=null,"drop from hovered product reaches purchase consent")
	if node("PurchaseDecline")!=null:await click("PurchaseDecline")
	check((await saved())==before,"shop cloth hover preserves the campaign")
	await load_at(seed,"east");await enter_facility("shop")
	before=await saved()
	game.pages.shop_view.open_comparison("undertow-sword");await settle()
	var skill=await observe(node("ComparisonSkill_追加_skill_retreat_slash_*"),"shop-retreat")
	check(skill.get("body","").contains("70%攻撃") and skill.get("body","").contains("消費MP 1"),"retreat shows actual attack and cost")
	check((await saved())==before,"shop comparison hover preserves the campaign")
	await click("ProductTrial_undertow-sword");await click("TrialRecipient_character_mirei")
	check(game.data.get("trial")!=null,"shop starts the real trial battle with the same skill")
	var trial_button=node("EndTrial").get_global_rect()
	var grid=preload("res://screen_grid.gd")
	check(grid.cell_rect(game.size,0,1,10,8).encloses(trial_button) and not game.battle_header.get_global_rect().intersects(trial_button),"trial exit stays clear of common header, footer and turn order")
	var trial_state=game.state().duplicate(true)
	await game.hud.open_equipment_sheet("character_mirei");await settle()
	var equipped=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="equipment_upperBody")
	var battle_cloth=await observe(equipped[0] if not equipped.is_empty() else null,"battle-cloth")
	check(not cloth.is_empty() and battle_cloth==cloth,"shop and battle cloth share text, size and colors")
	if not equipped.is_empty():
		check(equipped[0].plain_details.any(func(line):return line.contains("属性相性")) and equipped[0].brief().contains("属性相性"),"full detail text appears in hover body")
	game.dialog.close();await settle()
	game.hud.open_skills();await settle()
	var battle_skill=await observe(node("BattleSkillDetails_skill_retreat_slash"),"battle-retreat")
	check(not skill.is_empty() and battle_skill==skill,"shop and battle skill share text, size and colors")
	var info=node("BattleSkillDetails_skill_retreat_slash")
	await observe(info,"battle-retreat-before-click",false)
	await pointer_click(info)
	detail=node("SkillDetailsWindow")
	check(detail!=null and detail.visible,"click on hovered battle skill icon still opens full details")
	if detail!=null:detail.finish();await settle()
	check(game.state()==trial_state,"battle hovers preserve the trial state")
	await click("EndTrial")
	check((await saved())==before,"ending trial after battle hovers restores the exact prior campaign")
	var f=FileAccess.open(evidence.path_join("hover-checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"measurements":measurements},"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
