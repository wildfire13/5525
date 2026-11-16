extends "res://tests/brushup_gui.gd"
const RESEARCH_OWNER="character_mirei"
func cases2():
 var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([ProjectSettings.globalize_path("res://tests/research_current_fixtures.cjs")]),output,true,false)
 return JSON.parse_string("".join(output))
func reveal_control(control: Control):
 var parent=control.get_parent()
 while parent!=null:
  if parent is ScrollContainer:parent.ensure_control_visible(control)
  parent=parent.get_parent()
 await settle()
func skill_tab():
 var tabs=game.find_children("*","Button",true,false).filter(func(b):return b.is_visible_in_tree() and b.text=="スキル")
 await os_click(tabs[0])
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
 var owner_name=game.campaign().roster.filter(func(c):return c.id==RESEARCH_OWNER)[0].name
 await game.update({"op":"campaign_load","data":cases.sweep50});await settle()
 await os_click(game.hud.buttons.action_skill);await os_click(node("BattleSkillDetails_skill_leg_sweep"))
 check(node("SkillDetailsWindow")!=null and node("SkillDetailsSummary").text.contains("使用者自身（中心指定）"),"OS opens full skill details with exact center and effect scope")
 await snapshot("skill-details-"+str(width));var before=await saved();await tab_click(1)
 check(node("SkillDetailsGlossary").is_visible_in_tree(),"OS terms tab separates timing and inventory vocabulary")
 await snapshot("skill-terms-"+str(width));await os_key("Tab");await os_key("Escape")
 check(node("SkillDetailsWindow")==null and game.hud.skill_list and (await saved())==before,"OS keyboard returns to unchanged skill selection")
 await os_click(node("BattleSkill_skill_leg_sweep"));check(game.can_commit() and game.preview.cells.size()==8,"OS skill selection still selects the canonical eight-cell preview")
 var pending=game.pending;var preview=game.preview.duplicate(true)
 game.show_skill_details("skill_leg_sweep","足払い",1);await settle()
 await os_mouse(game.board.global_position+game.board.project_cell(25),"click")
 check(game.pending==pending and game.preview==preview and (await saved())==before,"exclusive details do not pass clicks to the battle board")
 await os_click(node("SkillDetailsBack"));await os_click(game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="battle_cancel")[0])
 check(game.pending==null and (await saved())==before,"OS target cancel consumes no action MP or item")
 # Long body only: fixed summary and back, actual wheel/key scrolling to last line.
 var copy=preload("res://skill_text.gd");var doc=copy.document("skill_pincer","挟撃",1,game.campaign());doc.conditions=[];doc.limits=[];doc.effect=["長い説明の折返し確認。".repeat(180)+"最終行の到達確認"]
 var detail=preload("res://skill_details.gd").new();game.add_child(detail);detail.configure(game,doc,owner_name+" / 足払い");await settle()
 var body=node("SkillDetailsBody");var scroll=body.get_parent();var summary_at=node("SkillDetailsSummary").get_global_rect();var back_at=node("SkillDetailsBack").get_global_rect()
 await os_mouse(scroll.get_global_rect().get_center()+Vector2(detail.position),"click")
 await os_wheel(scroll.get_global_rect().get_center()+Vector2(detail.position),100)
 check(scroll.scroll_vertical>0 and scroll.scroll_vertical+scroll.size.y>=scroll.get_v_scroll_bar().max_value-2 and body.text.ends_with("最終行の到達確認") and node("SkillDetailsSummary").get_global_rect()==summary_at and node("SkillDetailsBack").get_global_rect()==back_at,"OS wheel reaches last line while target/range/back stay fixed")
 await snapshot("long-description-"+str(width));await os_key("Escape")
 # Many real IDs; no invented stack or capacity rules.
 var output=[];OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray(["-e","const C=require(process.argv[1]);process.stdout.write(JSON.stringify(C.gear.filter(g=>!g.virtualDefault&&g.type!=='empty'&&!g.id.startsWith('fist-')).map(g=>g.id)));",ProjectSettings.globalize_path("res://../native/campaign.js")]),output,true,false)
 var seed=original.duplicate(true);seed.state.location="east";seed.state.gold=500;seed.state.characters[RESEARCH_OWNER].inventory={}
 for id in JSON.parse_string("".join(output)):seed.state.characters[RESEARCH_OWNER].inventory[id]=3
 seed.state.characters[RESEARCH_OWNER].inventory.potion=3;seed.state.characters[RESEARCH_OWNER].inventory.ether=2
 await game.update({"op":"campaign_load","data":seed});game.pages.party_view.open_inventory(RESEARCH_OWNER);await settle()
 await snapshot("inventory-"+str(width))
 var row=character_item(RESEARCH_OWNER,"kungfu-pants");await reveal_control(row);await os_click(row);await os_click(node("CharacterItemDetails"))
 check(node("SkillDetailsBody").text.contains("50%") and node("SkillDetailsBody").text.contains("周囲8マス") and node("SkillDetailsContext").text.contains(owner_name),"unequipped item explanation preserves owner and effects")
 await tab_click(node("SkillDetailsNote").get_parent().get_index());check(node("SkillDetailsNote").is_visible_in_tree(),"item note is separately readable")
 await snapshot("equipment-note-"+str(width));await os_key("Escape")
 check(node("CharacterItemDetails").has_focus(),"explanation returns focus to selected item")
 await skill_tab();var skill=game.find_child("CharacterSkill_*_skill_cover_*",true,false);await reveal_control(skill);await os_click(skill)
 check(node("SkillDetailsWindow")!=null and game.pages.party_uid==RESEARCH_OWNER,"skill detail preserves owner")
 await os_key("Tab");await os_key("Escape");check(skill.has_focus() and game.page=="character","keyboard close returns to same skill")
 await enter_facility("shop");await settle()
 await os_click(node("ShopInventoryTab_inventory"));var source=node("SaleItem_spear-wood");await reveal_control(source)
 var position=node("ShopInventoryScroll").scroll_vertical;before=await saved();await os_click(source)
 var quantity=node("FacilitySaleQuantity");await reveal_control(quantity);await os_click(quantity.get_line_edit());await os_key("Home");await os_key("Delete");await os_key("2");await os_key("Return")
 var sale=game.pages.shop_view.sale
 check(sale.amount==2 and sale.quote.count==2 and node("FacilitySaleTotals").text.contains(str(int(sale.quote.proceeds))+"G"),"quantity editing updates canonical total")
 await snapshot("sale-"+str(width));await os_click(node("FacilitySalePrepare"));await os_click(node("FacilitySaleCancel"))
 check(sale.amount==2 and sale.item_id=="spear-wood" and sale.owner_id==RESEARCH_OWNER and (await saved())==before,"sale cancel preserves item quantity owner and save")
 check(node("ShopInventoryScroll").scroll_vertical==position,"sale cancel preserves originating list position")
 await os_click(node("RosterMember_character_shion"));check(sale.item_id.is_empty() and node("FacilitySaleTotals")==null,"owner switch clears previous sale target and price")
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"research2 OS checks kept all sound OFF")
 var f=FileAccess.open(evidence.path_join("checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
