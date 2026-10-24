extends "res://tests/brushup_gui.gd"
func cases2():
 var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/feedback_261019_fixtures.cjs")]),output,true,false)
 return JSON.parse_string("".join(output))
func tab_click(index: int):
 var bar=node("SkillDetailsTabs").get_tab_bar();var point=bar.global_position+bar.get_tab_rect(index).get_center()+Vector2(bar.get_window().position)
 await os_mouse(point,"click")
func os_wheel(point: Vector2,steps: int):
 request_id+=1
 var f=FileAccess.open(evidence.path_join("request.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"id":request_id,"action":"wheel_down","x":point.x,"y":point.y,"steps":steps}));f.close()
 var deadline=Time.get_ticks_msec()+10000
 while Time.get_ticks_msec()<deadline:
  if FileAccess.file_exists(evidence.path_join("response.json")):
   var response=JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("response.json")))
   if response is Dictionary and response.get("id")==request_id:break
  await process_frame
 check(Time.get_ticks_msec()<deadline,"OS wheel request acknowledged")
 await create_timer(.3).timeout;await settle()
func run():
 create_timer(400).timeout.connect(func():print("FAIL research2 GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","real X11 rendering for description and inventory loop")
 var width=int(OS.get_environment("BRUSHUP_GUI_WIDTH"));width=1920 if width==0 else width
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(width,812 if width==1180 else 1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle();var cases=cases2();var original=await saved()
 await game.update({"op":"campaign_load","data":cases.sweep50});await settle()
 await os_click(game.hud.buttons.skill);await os_click(node("BattleSkillDetails_legSweep"))
 check(node("SkillDetailsWindow")!=null and node("SkillDetailsSummary").text.contains("使用者自身（中心指定）"),"OS opens full skill details with exact center and effect scope")
 await snapshot("skill-details-"+str(width));var before=await saved();await tab_click(1)
 check(node("SkillDetailsGlossary").is_visible_in_tree(),"OS terms tab separates timing and inventory vocabulary")
 await snapshot("skill-terms-"+str(width));await os_key("Tab");await os_key("Escape")
 check(node("SkillDetailsWindow")==null and game.hud.skill_list and (await saved())==before,"OS keyboard returns to unchanged skill selection")
 await os_click(node("BattleSkill_legSweep"));check(game.can_commit() and game.preview.cells.size()==8,"OS skill selection still selects the canonical eight-cell preview")
 var pending=game.pending;var preview=game.preview.duplicate(true)
 game.show_skill_details("legSweep","足払い",1);await settle()
 await os_mouse(game.board.global_position+game.board.project_cell(25),"click")
 check(game.pending==pending and game.preview==preview and (await saved())==before,"exclusive details do not pass clicks to the battle board")
 await os_click(node("SkillDetailsBack"));await os_click(game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="battle_cancel")[0])
 check(game.pending==null and (await saved())==before,"OS target cancel consumes no action MP or item")
 # Long body only: fixed summary and back, actual wheel/key scrolling to last line.
 var copy=preload("res://skill_text.gd");var doc=copy.document("pincer","挟撃",1,game.campaign());doc.conditions=[];doc.limits=[];doc.effect=["長い説明の折返し確認。".repeat(180)+"最終行の到達確認"]
 var detail=preload("res://skill_details.gd").new();game.add_child(detail);detail.configure(game,doc,"ガロ / 相棒の短剣");await settle()
 var body=node("SkillDetailsBody");var scroll=body.get_parent();var summary_at=node("SkillDetailsSummary").get_global_rect();var back_at=node("SkillDetailsBack").get_global_rect()
 await os_mouse(scroll.get_global_rect().get_center()+Vector2(detail.position),"click")
 await os_wheel(scroll.get_global_rect().get_center()+Vector2(detail.position),100)
 check(scroll.scroll_vertical>0 and scroll.scroll_vertical+scroll.size.y>=scroll.get_v_scroll_bar().max_value-2 and body.text.ends_with("最終行の到達確認") and node("SkillDetailsSummary").get_global_rect()==summary_at and node("SkillDetailsBack").get_global_rect()==back_at,"OS wheel reaches last line while target/range/back stay fixed")
 await snapshot("long-description-"+str(width));await os_key("Escape")
 # Many real IDs; no invented stack or capacity rules.
 var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e","const C=require(process.argv[1]);process.stdout.write(JSON.stringify(C.gear.filter(g=>!g.virtualDefault&&g.type!=='empty'&&!g.id.startsWith('fist-')).map(g=>g.id)));",ProjectSettings.globalize_path("res://../native/campaign.js")]),output,true,false)
 var seed=original.duplicate(true);seed.state.location="east";seed.state.gold=500;seed.state.characters.guard.inventory={}
 for id in JSON.parse_string("".join(output)):seed.state.characters.guard.inventory[id]=3
 seed.state.characters.guard.inventory.potion=3;seed.state.characters.guard.inventory.ether=2
 game.pages.facility_art.rng.seed=12345
 await game.update({"op":"campaign_load","data":seed});game.navigate("shop");await settle();await os_click(node("PartyFace_guard"))
 await snapshot("inventory-"+str(width));var list=node("OwnedEquipmentScroll")
 list.ensure_control_visible(node("OwnedEquipment_kungfu-pants"));await settle();await os_click(node("OwnedEquipment_kungfu-pants"));await os_click(node("InventoryDetails"))
 check(node("SkillDetailsBody").text.contains("50%") and node("SkillDetailsBody").text.contains("周囲8マス") and node("SkillDetailsContext").text.contains("ガロ"),"OS unequipped item explanation preserves owner and canonical effects")
 await tab_click(2);check(node("SkillDetailsNote").is_visible_in_tree(),"OS item note is separately readable")
 await snapshot("equipment-note-"+str(width));await os_key("Escape")
 check(node("InventoryDetails").has_focus(),"OS item explanation returns focus to same selected item")
 await os_click(node("InventoryList"))
 var source=node("OwnedInventorySell_spear-wood");list=node("OwnedEquipmentScroll");list.ensure_control_visible(source);await settle();var position=list.scroll_vertical;before=await saved()
 await os_click(source);var quantity=node("InventoryQuantity");await os_click(quantity.get_line_edit());await os_key("Home");await os_key("Delete");await os_key("2");await os_key("Return")
 check(int(node("InventoryQuantity").value)==2 and node("InventorySaleTotals").text.contains("×2"),"OS quantity editing retains named item and updates canonical total")
 await snapshot("sale-"+str(width));await os_click(node("InventoryPrepareSale"));await os_click(node("InventoryCancel"))
 check(game.pages.party_view.inventory_view.amount==2 and node("InventoryQuantity").get_line_edit().has_focus() and (await saved())==before,"OS NO preserves quantity owner inventory and editing focus")
 await os_click(node("InventoryList"));check(node("OwnedEquipmentScroll").scroll_vertical==position,"OS return restores originating list position")
 await os_click(node("StatusTab_2"));await os_click(node("PartySkillDetails_guard"));check(game.pages.party_view.detail_uid=="guard" and node("SkillDetailsWindow")!=null,"OS nested skill detail preserves character owner")
 await os_key("Tab");await os_key("Escape");check(game.dialog.window!=null and node("SkillDetailsWindow")==null and game.pages.party_view.detail_uid=="guard","OS nested keyboard close returns to same status")
 await os_click(node("PartyFace_archer"));check(node("InventorySaleTotals")==null,"OS owner switch clears previous sale target and price")
 await os_key("Escape");await settle()
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"research2 OS checks kept all sound OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
