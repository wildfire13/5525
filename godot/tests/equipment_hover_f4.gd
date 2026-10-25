extends "res://tests/inventory_header_261020.gd"
## First-pass popup measurement; actual OS hover is verified separately.
var measurements=[]
func equipped(slot: String):
	var controls=game.find_children("*","Button",true,false).filter(func(button):return button.get_meta("ui_key","")=="equipment_"+slot)
	check(controls.size()==1,"F4 equipped source uniquely identified "+slot)
	return controls[0]
func popup_for(source):
	var box=source._make_custom_tooltip(source.tooltip_text)
	var first_height=box.get_combined_minimum_size().y
	var popup=PopupPanel.new();popup.theme=game.theme;game.add_child(popup);popup.add_child(box);popup.popup_centered();await settle()
	return {"popup":popup,"box":box,"first_height":first_height}
func geometry(result,label: String):
	var popup=result.popup;var box=result.box;var body=box.find_child("EquipmentTooltipDetails",true,false);var hint=box.find_child("EquipmentTooltipHint",true,false)
	var children=box.get_theme_constant("separation")*(box.get_child_count()-1)
	for child in box.get_children():children+=child.get_combined_minimum_size().y
	check(hint.size.x==body.size.x and hint.custom_minimum_size.x==body.size.x,"F4 first-pass hint has final wrapping width "+label)
	check(absf(float(result.first_height)-box.get_combined_minimum_size().y)<=4,"F4 first and final minimum heights agree "+label)
	check(absf(box.size.y-children)<=4,"F4 background content has no blank tail "+label)
	check(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(Rect2(Vector2(popup.position),Vector2(popup.size))),"F4 popup fits actual viewport "+label)
	check(body.get_content_height()<=body.size.y+2 and body.get_visible_line_count()==body.get_line_count(),"F4 rendered body ends on complete visible lines "+label)
	measurements.append({"case":label,"root":str(root.size),"popup":str(Rect2(Vector2(popup.position),Vector2(popup.size))),"box":str(box.size),"first_height":result.first_height,"final_height":box.get_combined_minimum_size().y,"children_height":children,"body_height":body.size.y,"content_height":body.get_content_height(),"visible_lines":body.get_visible_line_count(),"total_lines":body.get_line_count(),"excerpt":body.get_meta("excerpt",false)})
func close_popup(result):
	result.popup.hide();result.popup.queue_free();await frames()
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
			game.navigate("shop");game.pages.party_view.open_detail("guard");await settle()
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
	# A pathological note must be an explicit, complete preview, with the entire
	# unmodified note still reachable through the existing full-detail window.
	root.size=Vector2i(1180,812);await game.update({"op":"campaign_load","data":seed});game.pages.party_view.open_detail("guard");await settle()
	var before=await saved();var source=equipped("rightHand");var definition=game.roster().filter(func(u):return u.id=="guard")[0].equipmentDetails.rightHand.duplicate(true)
	var note="長い原文 [角括弧] の完全保持。".repeat(220)+"原文の最後まで保持"
	definition.note=note;source.configure(definition.name,definition,{"names":game.campaign().skillNames,"definitions":game.campaign().skillDefinitions,"title_size":20,"detail_size":16})
	var full=source.tooltip_text;var result=await popup_for(source);geometry(result,"oversize original note")
	var body=result.box.find_child("EquipmentTooltipDetails",true,false);var hint=result.box.find_child("EquipmentTooltipHint",true,false)
	check(body.get_meta("excerpt",false) and hint.text.contains("抜粋") and body.get_parsed_text().ends_with("…（続きは全文で確認）"),"F4 oversize content is an explicit complete preview")
	check(source.tooltip_text==full and source.tooltip_text.ends_with(note),"F4 full original note is retained without clipping or rewriting")
	await close_popup(result)
	game.show_equipment_details({"id":definition.id,"name":definition.name,"kind":"equipment","count":1,"definition":definition});await settle()
	node("SkillDetailsTabs").current_tab=2;await frames();var raw=node("SkillDetailsNote");raw.get_parent().scroll_vertical=100000;await frames()
	check(raw.text==note and raw.get_parent().scroll_vertical>0,"F4 existing full-detail route reaches verbatim note end")
	await click("SkillDetailsBack")
	check((await saved())==before and game.audio.muted.values().all(func(value):return value),"F4 all previews remain read-only with BGM voice SE OFF")
	var f=FileAccess.open(evidence.path_join("equipment-hover-f4-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"measurements":measurements},"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
