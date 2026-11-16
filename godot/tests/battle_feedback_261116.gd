extends "res://tests/combat_b_ui.gd"

func mouse_click(control):
	var point=control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.global_position=point
		event.pressed=pressed
		root.push_input(event,true)
		await process_frame
	await settle()

func run():
	create_timer(80).timeout.connect(func():print("FAIL battle feedback watchdog");quit(2))
	var generated=[]
	var fixture=ProjectSettings.globalize_path("res://tests/inventory_battle_fixtures.cjs")
	var status=OS.execute(OS.get_environment("NATIVE5525_NODE"),[fixture],generated)
	if status!=0:quit(2);return
	var save=JSON.parse_string("".join(generated)).guard
	var battle=save.state.battle
	battle.actor="scout"
	for fighter in battle.units:
		fighter.next=4
		if fighter.side=="enemy":fighter.next=2
		if fighter.id=="guard":fighter.next=3
		if fighter.id=="scout":fighter.next=1
		if fighter.id=="scout":fighter.pos=24;fighter.mp=0
		if fighter.id=="archer":fighter.pos=4
	root.size=Vector2i(1920,1080)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true
	game.audio.fast_mode=true
	await game.update({"op":"campaign_load","data":save})
	await settle()
	var hud=game.hud
	var left=hud.left_panel.body
	check(left.find_child("Inspect_hp",true,false)!=null and left.find_child("Inspect_mp",true,false)!=null,"actor has HP and MP gauges")
	check(not left.find_children("*","Button",true,false).any(func(b):return b.text=="能力・行動条件の詳細"),"redundant action details removed")
	for prefix in ["SPD","Wt"]:
		var labels=left.find_children("*","Label",true,false).filter(func(label):return label.text.begins_with(prefix))
		check(labels.size()==1 and labels[0].tooltip_text.contains("行動速度"),prefix+" tooltip")
	var foe=game.board.unit_at(25)
	await game.choose_command("skill")
	await settle()
	var chosen=await game.engine.request({"op":"hover_preview","kind":"skill","uid":foe.id})
	check(chosen.hover.status=="insufficient_mp","in-range ambush identifies missing MP")
	var invalid=await game.engine.request({"op":"hover_preview","kind":"skill","uid":"porter"})
	check(invalid.hover.status=="unavailable","wrong side stays unavailable")
	await game.on_cell(25)
	await settle()
	hud.pin_inspection(25)
	game.board.hover_uid=foe.id
	hud.invalidate_hover()
	hud.refresh_hover()
	await settle()
	check(game.board.hover_caption=="実行不可（MP不足）","board caption")
	check(not hud.target_box.find_child("ActionCost",true,false).visible and not hud.target_box.find_child("TargetSummary",true,false).visible,"redundant target summary hidden")
	check(hud.person_box.find_child("EnemyInventory",true,false)==null,"enemy inventory removed from inspection")
	var profile=hud.person_box.find_child("ElementalCombatProfile",true,false)
	check(profile.columns==5 and profile.get_child_count()==10,"ATK and DEF each show physical and three elemental values")
	var mage=foe.merged({"job":"mage","role":"ヒーラー"},true)
	var sample=VBoxContainer.new()
	root.add_child(sample)
	hud.render_person_content(sample,mage,true)
	check(sample.find_children("*","Label",true,false).any(func(label):return label.text.ends_with(" / 魔法使い")),"mage job label for legacy enemy")
	sample.free()
	await shot("battle-feedback")
	var sides={}
	for card in game.find_children("TurnCard_*","PanelContainer",true,false):
		var id=card.get_meta("unit_id")
		sides[hud.unit(id).side]=true
		await mouse_click(card.find_child("InspectTurnMember",true,false))
		var member=game.find_child("EquipmentMember_"+id,true,false)
		check(member!=null and member.get_meta("selected",false),"turn card opens "+id)
		var bag=game.find_child("BattleInventory",true,false)
		check(bag!=null and bag.get_child_count()>0,"inventory for "+id)
		if bag==null:break
		if hud.unit(id).side=="enemy":
			var potions=hud.unit(id).get("inventory",{}).get("potion",0)
			var inventory_text=bag.get_child(0).text
			check(inventory_text==("ポーション ×%d" % potions if potions>0 else "なし"),"enemy carried quantity")
			await shot("battle-equipment")
		if id=="guard":check(bag.get_child(0).text=="ポーション ×3","ally carried quantity")
		game.dialog.close()
		await settle()
	check(sides.has("ally") and sides.has("enemy"),"both factions inspected")
	game.cancel()
	await settle()
	check(hud.acting().mp==0 and game.pending==null,"cancel preserves MP and clears target")
	game.closing=true
	await game.audio.finish_audio()
	game.engine.close_engine()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
