extends "res://tests/inventory_header_261020.gd"
## First-pass popup measurement; actual OS hover is verified separately.
var measurements=[]
func equipped(slot: String):
	var controls=game.find_children("*","Button",true,false).filter(func(button):return button.get_meta("ui_key","")=="equipment_"+slot)
	check(controls.size()==1,"F4 equipped source uniquely identified "+slot)
	return controls[0]
func popup_for(source):
	source.show_hover()
	# Headless has no OS pointer: keep this geometry fixture visible while its
	# ScrollContainer sorts. Real mouse enter/leave/scroll is tested in X11 QA.
	source.hover_window.idle=-1000
	await settle()
	var popup=source.hover_window;var box=popup.content
	check(source._make_custom_tooltip("")==null,"native empty-tooltip callback cannot create a second popup")
	check(game.modal_open(),"existing status modal remains active while game-root hover is open")
	return {"popup":popup,"box":box,"first_height":box.get_combined_minimum_size().y}
func geometry(result,label: String):
	var popup=result.popup;var box=result.box;var body=box.find_child("EquipmentTooltipDetails",true,false);var scroll=box.find_child("EquipmentTooltipScroll",true,false)
	check(popup.visible,"F4 geometry is measured on a visible popup "+label)
	check(popup.get_parent() is CanvasLayer and popup.get_parent().get_parent()==root and popup.get_parent().layer==1025,"hover draws above embedded status in game coordinates "+label)
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(popup.position),Vector2(popup.size))),"F4 popup fits game viewport "+label)
	check(absf(box.size.y-box.get_combined_minimum_size().y)<=4,"F4 background follows visible full/scrollable content "+label)
	check(not body.get_meta("excerpt",true),"F4 no excerpt or cut text "+label)
	check(body.get_content_height()<=body.size.y+2,"F4 rich body retains its whole natural height "+label)
	var title=box.find_child("EquipmentTooltipName",true,false)
	check(popup.mouse_filter==Control.MOUSE_FILTER_IGNORE and body.mouse_filter==Control.MOUSE_FILTER_IGNORE,"F4 full hover never steals character clicks or drag sources "+label)
	check(popup.input_guard.visible==(popup.source.get_window()!=root),"F4 root input guard follows character/window ownership "+label)
	if not box.get_meta("scrollable",false):
		check(absf(scroll.size.y-(title.size.y+body.get_content_height()+8))<=4,"F4 ordinary popup has no stale first-width blank tail "+label)
	measurements.append({"case":label,"root":str(root.size),"popup":str(Rect2(Vector2(popup.position),Vector2(popup.size))),"box":str(box.size),"body_height":body.size.y,"content_height":body.get_content_height(),"scroll_height":scroll.size.y,"scrollable":box.get_meta("scrollable",false)})
func close_popup(result):
	result.popup.hide();await frames()
func run():
	create_timer(180).timeout.connect(func():print("FAIL F4 equipment hover watchdog");quit(2))
	if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):push_error("Isolated F4 profile required");quit(2);return
	root.size=Vector2i(1280,800);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var seed=await saved();seed.state.location="east"
	var hero=seed.state.characters.guard;hero.level=29;hero.xp=2800;hero.allocations.str=2;hero.allocations.agi=1;hero.statPoints=53;hero.skillPoints=28;hero.leftHand="empty-leftHand"
	for dims in [Vector2i(1280,800),Vector2i(1180,812),Vector2i(1920,1080)]:
		root.size=dims;await settle()
		for gear in ["hammer-iron-1","partner-dagger","longspear-wood","grappling-rope"]:
			hero.weapon=gear
			check((await game.update({"op":"campaign_load","data":seed})).get("ok",false),"F4 canonical equipped level29 fixture "+gear)
			await enter_facility("shop");game.pages.party_view.open_detail("guard");await settle()
			if dims.x==1920:game.dialog.window.size=Vector2i(1280,640);await settle()
			var before=await saved()
			for slot in (["upperBody","rightHand"] if gear=="hammer-iron-1" else ["rightHand"]):
				var source=equipped(slot);var full=source.tooltip_text
				var original_lines=source.plain_details.duplicate();var original_rich=source.details.duplicate()
				for cycle in range(2):
					var result=await popup_for(source);var label=gear+" "+slot+" "+str(dims.x)+" reopen"+str(cycle)
					geometry(result,label)
					var body=result.box.find_child("EquipmentTooltipDetails",true,false)
					check(not body.get_meta("excerpt",true) and body.get_parsed_text()=="\n".join(original_lines),"F4 ordinary equipment reaches its full original end "+label)
					check(body.text=="\n".join(original_rich) and (not source.plain_details.any(func(line):return line.contains("付与スキル")) or body.text.contains("[color=")),"F4 text and colour spans are preserved "+label)
					check(source.tooltip_text==full and source.plain_details==original_lines and source.details==original_rich,"F4 popup never rewrites stored descriptions "+label)
					await close_popup(result)
			check((await saved())==before,"F4 resize reopen and equipped hover preserve exact save "+gear+str(dims.x))
			game.dialog.close();await settle()
	# Oversize original material remains complete in this same hover. Its own
	# scroll reaches the end; no second window is needed to recover omitted text.
	root.size=Vector2i(1180,812);await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");game.pages.party_view.open_detail("guard");await settle()
	game.dialog.window.size=Vector2i(1180,420);await settle()
	var before=await saved();var source=equipped("rightHand");var definition=game.roster().filter(func(u):return u.id=="guard")[0].equipmentDetails.rightHand.duplicate(true)
	var note="長い原文 [角括弧] の完全保持。".repeat(220)+"原文の最後まで保持"
	definition.note=note;source.configure(definition.name,definition,{"names":game.campaign().skillNames,"definitions":game.campaign().skillDefinitions,"title_size":20,"detail_size":16})
	var full=source.tooltip_text;var result=await popup_for(source);geometry(result,"oversize original note")
	var body=result.box.find_child("EquipmentTooltipDetails",true,false);var hint=result.box.find_child("EquipmentTooltipHint",true,false);var scroll=result.box.find_child("EquipmentTooltipScroll",true,false)
	check(body.get_parsed_text()=="\n".join(source.plain_details) and body.get_parsed_text().ends_with(note),"F4 oversize hover preserves all verbatim blocks without excerpt")
	check(hint.visible and hint.text.contains("スクロール") and not hint.text.contains("抜粋"),"F4 long hover has local scroll instruction")
	check(result.popup.position.y+result.popup.size.y>game.dialog.window.position.y+game.dialog.window.size.y and result.popup.position.y+result.popup.size.y>=root.size.y-20,"F4 full hover uses game height beyond short character window")
	scroll.scroll_vertical=100000;await settle()
	print("SCROLL_END visible=",result.popup.visible," offset=",scroll.scroll_vertical," max ",scroll.get_v_scroll_bar().max_value," page ",scroll.get_v_scroll_bar().page," body ",body.get_global_rect()," scroll ",scroll.get_global_rect())
	check(scroll.scroll_vertical>0 and body.get_global_rect().end.y<=scroll.get_global_rect().end.y+4,"F4 same hover reaches complete original final line")
	check(source.tooltip_text==full and source.tooltip_text.ends_with(note),"F4 popup does not rewrite original note")
	# Resizing can rebuild the whole character view. A retired source must not
	# leave a detached/stale tooltip; hover the newly rendered source again.
	for dims in [Vector2i(960,540),Vector2i(1920,1080),Vector2i(1180,812)]:
		var old=result.popup
		root.size=dims;await settle()
		check(not is_instance_valid(old) or not old.visible,"F4 resize retires old hover with its rebuilt source "+str(dims))
		source=equipped("rightHand");source.configure(definition.name,definition,{"names":game.campaign().skillNames,"definitions":game.campaign().skillDefinitions,"title_size":20,"detail_size":16})
		result=await popup_for(source);geometry(result,"resize and rehover "+str(dims))
		check(result.box.find_child("EquipmentTooltipDetails",true,false).get_parsed_text().ends_with(note),"F4 resized hover keeps entire original note "+str(dims))
	await close_popup(result)
	# Comparison and description hover exclude each other, without changing
	# the selected item or taking keyboard focus away from the character view.
	var equipped_source=equipped("rightHand");var other_source=equipped("upperBody")
	equipped_source.show_hover();await frames(2);var first=equipped_source.hover_window
	other_source.show_hover();await frames(2)
	check(not first.visible and other_source.hover_window.visible,"F4 opening another equipment hover hides the previous one")
	var compare=preload("res://hover_comparison.gd").new();compare.ui=game;game.dialog.window.add_child(compare);compare.content.text="比較の確認";compare.show_for(equipped_source);await frames(2)
	check(not other_source.hover_window.visible and compare.visible,"F4 comparison hides full hover without replacing selected equipment")
	equipped_source.show_hover();await frames(2)
	check(not compare.visible and equipped_source.hover_window.visible,"F4 full hover hides stale comparison")
	compare.queue_free();await frames(2)
	game.dialog.escape();await settle()
	check(not is_instance_valid(equipped_source.hover_window) if is_instance_valid(equipped_source) else true,"F4 Escape frees source-owned root hover")
	check(game.page=="shop" and game.pages.facility_entry.view=="buy","F4 status hover and closing preserve shop purchase context")
	var product=node("Product_spear-wood")
	check(product!=null,"F4 actual root shop product is available")
	product.show_hover();product.hover_window.idle=-1000;await frames(3)
	var product_popup=product.hover_window;var at_origin=product_popup.position
	var old_position=root.position;root.position=Vector2i(94,61);await frames(3)
	product.show_hover();product.hover_window.idle=-1000;await frames(3)
	check(product.game_window_offset()==Vector2.ZERO and product_popup.position==at_origin,"F4 root OS position does not offset game-coordinate product hover")
	check(not product_popup.input_guard.visible,"F4 root product hover does not guard purchase/comparison controls")
	game.open_menu();await frames(3)
	check(not product_popup.visible,"F4 opening unrelated menu hides old product hover above embedded UI")
	game.open_menu();root.position=old_position;await frames(3)
	check((await saved())==before and game.audio.muted.values().all(func(value):return value),"F4 all previews remain read-only with BGM voice SE OFF")
	var f=FileAccess.open(evidence.path_join("equipment-hover-f4-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"measurements":measurements},"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
