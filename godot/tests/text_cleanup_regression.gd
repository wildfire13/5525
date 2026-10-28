extends "res://tests/feedback_261019_3.gd"
func run():
 create_timer(100).timeout.connect(func():print("FAIL text cleanup watchdog");quit(2))
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 var seed=await saved()
 for dims in [Vector2i(1920,1080),Vector2i(960,540)]:
  root.size=dims;await game.update({"op":"campaign_load","data":seed});await enter_facility("inn");await settle()
  check(not labels().any(func(s):return s.begins_with("パーティ全員で")) and labels().has("全員が全回復しています。料金はかかりません。"),"full party hides charge but retains free status "+str(dims))
  var injured=seed.duplicate(true);injured.state.characters.guard.hp=1
  await game.update({"op":"campaign_load","data":injured});await enter_facility("inn");await settle()
  check(labels().has("パーティ全員で%dG" % game.campaign().inn.price) and not labels().any(func(s):return s.contains("仮料金")),"injured party retains exact price "+str(dims))
  game.page="map";game.render();await settle()
  check(labels().has("地図は模式図です。各移動は二つの区間を通ります。"),"map warning and travel count retained "+str(dims))
 var gear={"id":"test","name":"試験装備","slot":"lowerBody","flavor":"一般的な作業用のズボン。","note":"必要な効果の注記"}
 var entry={"kind":"equipment","name":gear.name,"count":1,"definition":gear}
 var tip=preload("res://equipment_tooltip.gd").new();tip.configure_entry(entry,game.campaign())
 check(tip.tooltip_text.contains("説明\n"+gear.flavor) and tip.tooltip_text.contains("装備メモ（原文）\n"+gear.note),"hover preserves independent flavor and original note")
 var doc=tip.detail_document(entry)
 check(not doc.body_text.contains(gear.flavor) and not doc.body_text.contains(gear.note) and doc.body_text.contains("付与スキル：なし"),"effect body excludes separate prose without losing stats")
 tip.free()
 var item_tip=preload("res://equipment_tooltip.gd").new()
 var item={"kind":"item","name":"試験アイテム","count":1,"definition":{"description":"説明"}}
 item_tip.configure_entry(item,game.campaign())
 check(item_tip.detail_document(item).body_text=="説明","item description is not treated as equipment flavor separator")
 item_tip.free();game.show_equipment_details(entry);await settle()
 check(node("SkillDetailsFlavor").text==gear.flavor and node("SkillDetailsNote").text==gear.note,"full details preserve separate description and note tabs")
 await click("SkillDetailsBack")
 var target=VBoxContainer.new();game.add_child(target);var footer=VBoxContainer.new();game.add_child(footer)
 game.hud.target_box=target;game.hud.decision_footer=footer
 var phase={"phase":"action","action_id":"test","label":"ガロ：攻撃"}
 game.hud.render_presentation(phase)
 check(target.get_children().filter(func(n):return n is Label and n.text=="ガロ：攻撃").size()==1,"identical action label appears once")
 for n in target.get_children():target.remove_child(n);n.queue_free()
 game.hud.render_presentation({"phase":"result","action_id":"test","label":"対象への結果"})
 check(target.get_children().filter(func(n):return n is Label and n.text in ["ガロ：攻撃","対象への結果"]).size()==2,"different action and result labels both remain")
 target.queue_free();footer.queue_free()
 check(game.audio.muted.values().all(func(v):return v),"audio remains OFF")
 game.closing=true;await game.audio.finish_audio();await game.engine.finish_diagnostics();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
