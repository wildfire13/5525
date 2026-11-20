extends "res://tests/research2_gui.gd"
## Real X11 routes, plus explicitly validated synthetic QA boundaries.
var icons_baseline=OS.get_environment("INDIVIDUAL_ICONS_BASELINE")=="1"
var icon_records=[]
var boundaries=[]
var canvas_seen={}
func screen_rect(control: Control) -> Rect2:
 return Rect2(control.get_global_rect().position+Vector2(control.get_window().position),control.size)

var ui_cases={}
func fixtures_icons():
 var path=OS.get_environment("INDIVIDUAL_ICONS_FIXTURES")
 if path.is_empty():path=ProjectSettings.globalize_path("res://tests/individual_icons_fixtures.cjs")
 var output=[];var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([path]),output,true,false)
 check(code==0,"QA boundaries pass canonical C.validate and save roundtrip")
 var parsed=JSON.parse_string("".join(output));check(parsed.meta.gear_count==65,"fixture inventory contains 65 current canonical equipment IDs")
 return parsed.cases
func art_path(id: String) -> String:
 if not id.begins_with("approved:"):return game.icons.path_for(id)
 var parts=id.split(":")
 var spec=game.icons.approved.fist if parts[1]=="fist" else game.icons.approved.equipment.get(parts[2],{}) if parts[1]=="equipment" else game.icons.approved.skills.get(parts[2],{})
 return str(spec.get("base",""))
func visible_rect(control: Control) -> Rect2:
 var rect=control.get_global_rect();var ancestor=control.get_parent()
 while ancestor is Control:
  if ancestor.clip_contents:rect=rect.intersection(ancestor.get_global_rect())
  ancestor=ancestor.get_parent()
 return rect.intersection(Rect2(Vector2.ZERO,Vector2(control.get_window().size)))
func record_icons(label: String):
 for control in game.find_children("*","Control",true,false):
  if not control.is_visible_in_tree() or not control.has_meta("ui_icon_id"):continue
  var id=str(control.get_meta("ui_icon_id"));var texture=control.icon if control is Button else control.texture if control is TextureRect else null
  if texture==null:continue
  var maximum=control.get_theme_constant("icon_max_width") if control is Button else control.size.x
  var source=art_path(id)
  var copy=control.text if control is Button else ""
  icon_records.append({"case":label,"control":str(control.name),"id":id,"source_path":source,"texture_size":str(texture.get_size()),"icon_max_width":maximum,"control_rect":str(control.get_global_rect()),"visible_clip_rect":str(visible_rect(control)),"actually_in_clip":visible_rect(control).has_area(),"name_text":copy,"window_title":control.get_window().title})
  if not canvas_seen.has(id):
   canvas_seen[id]=true
   texture.get_image().save_png(evidence.path_join("rendered/"+id.replace(":","_")+".png"))
   if not icons_baseline and id.begins_with("approved:"):check(texture.get_size()==Vector2(64,64),"real UI composed canvas stays64 "+id)
func capture(label: String):
 await settle();record_icons(label);await snapshot(label)
func at_fixture(key: String):
 boundaries.append({"key":key,"kind":"canonical validated synthetic save; preceding play not observed"})
 check((await game.update({"op":"campaign_load","data":ui_cases[key]})).get("ok",false),"canonical fixture load "+key)
 await settle()
func reveal(id: String,scroll_id: String):
 var control=node(id);check(control!=null,"named target exists "+id)
 if control==null:return
 var scroll=node(scroll_id)
 if scroll!=null:scroll.ensure_control_visible(control)
 await settle()
func inventory_category(value: String):
 var chooser=node("ShopInventoryFilter");var wanted=-1
 for index in range(chooser.item_count):
  if chooser.get_item_metadata(index)==value:wanted=index
 check(wanted>=0,"canonical inventory category exists "+value)
 await os_click(chooser);var popup=chooser.get_popup();var steps=0
 while popup.visible and popup.get_focused_item()!=wanted and steps<=chooser.item_count:
  await os_key("Down");steps+=1
 check(popup.visible and popup.get_focused_item()==wanted,"actual OS focuses canonical inventory category "+value)
 await os_key("Return")
 check(game.pages.shop_view.sale.inventory_filter==value,"actual OS category selection applied "+value)
func reveal_battle_row(skill: String):
 var control=node("BattleSkillDetails_"+skill);var parent=control.get_parent()
 while parent!=null and not parent is ScrollContainer:parent=parent.get_parent()
 if parent is ScrollContainer:parent.ensure_control_visible(control)
 await settle()
func battle_draw_contract(skill: String,label: String):
 var row=game.data.skillset.filter(func(data):return data.id==skill)[0]
 var level=int(row.get("level",1))
 var badged=game.icons.approved.skills.get(skill,{}).has("levels")
 var expected=32 if badged and not icons_baseline else 24
 var control=node("BattleSkill_"+skill);var info=node("BattleSkillDetails_"+skill)
 check(control.get_theme_constant("icon_max_width")==expected,label+" actual draw width "+str(expected)+" "+skill)
 var caption=str(row.name)+(" Lv%d" % level if badged and not icons_baseline else "")
 var source=game.hud.skill_source_short(row)
 if not source.is_empty():caption+="（"+source+"）"
 if int(row.get("cooldown",0))>0:caption+="\nクールタイム中"
 check(control.text.trim_prefix("● ")==caption,label+" caption equals canonical name and source level "+skill)
 check(visible_rect(control).encloses(control.get_global_rect()) and visible_rect(info).encloses(info.get_global_rect()),label+" skill and explanation button both fit panel clip "+skill)
func selected_flow(skill: String,label: String):
 await reveal_battle_row(skill);await os_click(node("BattleSkill_"+skill))
 var selected_boundary=await saved()
 if not game.can_commit():
  var candidates=game.data.choices.get("action_skill",[])
  var points=[]
  for id in candidates:
   var cell=int(id) if id is float or id is int else int(game.hud.unit(str(id)).get("pos",-1))
   if cell<0:continue
   var point=game.board.global_position+game.board.project_cell(cell)
   if not game.hud.left_panel.get_global_rect().has_point(point) and not game.hud.right_panel.get_global_rect().has_point(point):points.append(point)
  check(not points.is_empty(),label+" canonical target is exposed for real OS selection")
  if not points.is_empty():await os_mouse(points[0],"click")
 check(game.can_commit(),label+" actual OS reaches canonical target preview")
 await reveal_battle_row(skill);battle_draw_contract(skill,label+" selected")
 await capture(label+"-selected-target")
 var pending=game.pending;var preview=game.preview.duplicate(true)
 await os_click(node("BattleSkillDetails_"+skill));await capture(label+"-selected-full")
 await os_key("Escape")
 check(game.pending==pending and game.preview==preview and await saved()==selected_boundary,label+" full explanation preserves selected preview and exact selection-boundary save")
 await reveal_battle_row(skill);battle_draw_contract(skill,label+" after explanation")
 var cancel=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="battle_cancel" and b.is_visible_in_tree())
 check(not cancel.is_empty(),label+" cancel control exists")
 if not cancel.is_empty():await os_click(cancel[0])
 check(await saved()==selected_boundary,label+" actual target cancellation consumes nothing")
 await capture(label+"-cancelled")
func normal_route():
 check(game.campaign().phase=="town" and game.campaign().location=="astaris","historical roster starts in normal square")
 boundaries.append({"key":"historical-roster-through-first-battle","kind":"validated historical roster, OS route"})
 await os_click(node("RosterMember_guard"));var empty=node("CharacterSlot_head")
 check(empty.icon==null,"empty equipped slot remains iconless")
 await capture("normal-equipped")
 await os_click(node("Header_character"));await os_click(node("HubMap"));await os_click(node("Town_east"));await os_click(node("DepartButton"))
 var river=game.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("川沿いの道"))[0]
 await os_click(river);await os_click(node("DeploymentBegin"))
 check(game.campaign().phase=="battle","actual OS square/map/east/river/start reaches live battle")
 await os_click(game.hud.buttons.action_skill);await reveal_battle_row("skill_snipe");battle_draw_contract("skill_snipe","normal list");await capture("normal-battle-skills")
 await selected_flow("skill_snipe","normal-archer")
func inventory_cases():
 await at_fixture("east");await enter_facility("shop");await settle();await os_click(node("ShopInventoryTab_inventory"))
 var before=await saved()
 check(node("ShopInventoryScroll").find_children("SaleItem_*","Button",true,false).size()>=65,"all real equipment remains in existing personal list")
 await reveal("SaleItem_javelin-wood","ShopInventoryScroll");await capture("owned-thin-spears")
 var pixels=[]
 for id in ["spear-wood","longspear-wood","javelin-wood"]:
  var b=node("SaleItem_"+id);check(not b.text.is_empty() and b.icon!=null,"spear ID retains name beside art "+id);pixels.append(b.icon.get_image().get_data())
  await reveal("SaleItem_"+id,"ShopInventoryScroll");await capture("owned-spear-"+id)
 if not icons_baseline:check(pixels[0]!=pixels[1] and pixels[1]!=pixels[2] and pixels[0]!=pixels[2],"three spear forms retain distinct actual rendered pixels")
 await reveal("SaleItem_bow-silver-2","ShopInventoryScroll");await capture("owned-wood-iron-silver")
 await inventory_category("upperBody")
 await reveal("SaleItem_armor-cloth","ShopInventoryScroll");await capture("owned-cloth-leather-metal")
 game.pages.party_view.open_inventory("character_mirei");await settle();await os_click(node("CharacterTab_equipment"))
 var equipped=node("CharacterSlot_rightHand");await os_mouse(screen_rect(equipped).get_center());await create_timer(.85).timeout
 check(equipped.icon!=null and not equipped.tooltip_text.is_empty(),"equipped weapon has art and hover label");await capture("pincer-equipped")
 await skill_tab();var skill=game.find_child("CharacterSkill_*_skill_pincer_*",true,false);await reveal_control(skill);await capture("person-skills")
 await os_click(skill);check(node("SkillDetailsBody")!=null,"character skill opens full details")
 await capture("pincer-full-person");await os_key("Escape")
 check(await saved()==before,"owned list and full details preserve save")
func shop_cases():
 for place in ["east","west","north","south"]:
  await at_fixture(place);await enter_facility("shop");await settle();var before=await saved()
  if place=="south":
   await capture("shop-items");check(await saved()==before,"item shop inspection preserves save");continue
  var product="javelin-wood" if place=="east" else "armor-silver-1" if place=="west" else "lone-ring-1"
  await reveal("Product_"+product,"ShopProductsScroll");await capture("shop-"+place)
  await os_click(node("Product_"+product));check(node("ShopComparisonStats")!=null and not node("ShopComparisonProduct").text.is_empty(),"named product comparison opens "+place)
  await capture("comparison-"+place);await os_click(node("ShopExit"))
  check(await saved()==before,"comparison and cancellation preserve exact save "+place)
 # Representative ordinary purchase, cancel, and two-count sale use canonical quotes.
 await at_fixture("east");await enter_facility("shop");await settle();var before=await saved()
 await reveal("Product_spear-wood","ShopProductsScroll");await os_click(node("Product_spear-wood"))
 check(await saved()==before,"ordinary product preview consumes no money or inventory")
 await os_click(node("ShopComparisonBuy"));await os_click(node("PurchaseReceiptClose"))
 var bought=await saved();var price=game.campaign().shop.filter(func(g):return g.id=="spear-wood")[0].price
 check(int(bought.state.gold)==int(before.state.gold)-int(price) and int(bought.state.characters["character_mirei"].inventory["spear-wood"])==int(before.state.characters["character_mirei"].inventory["spear-wood"])+1,"actual ordinary purchase matches displayed canonical price and owner quantity")
 await os_click(node("ShopInventoryTab_inventory"));await reveal("SaleItem_spear-wood","ShopInventoryScroll");await os_click(node("SaleItem_spear-wood"))
 var quantity=node("FacilitySaleQuantity");await reveal_control(quantity);await os_click(quantity.get_line_edit());await os_key("Home");await os_key("Delete");await os_key("2");await os_key("Return")
 check(int(node("FacilitySaleQuantity").value)==2,"actual OS sale quantity is two")
 var quote=(await game.engine.request({"op":"campaign","action":"saleQuote","args":["character_mirei","spear-wood",2]})).saleQuote
 await capture("sale-quantity");await os_click(node("FacilitySalePrepare"));await os_click(node("FacilitySaleCancel"))
 check(await saved()==bought,"actual sale NO preserves all inventory and money")
 await os_click(node("FacilitySalePrepare"));await os_click(node("FacilitySaleConfirm"));var sold=await saved()
 check(int(sold.state.gold)==int(quote.afterGold) and int(sold.state.characters["character_mirei"].inventory["spear-wood"])==int(bought.state.characters["character_mirei"].inventory["spear-wood"])-2,"actual sale matches canonical total and exact owner quantity")
 await os_key("Escape")
func battle_cases():
 for key in ["sweep1","sweep2","sweep3","skill_pincer","item1","item3"]:
  await at_fixture(key);var before=await saved();await os_click(game.hud.buttons.action_skill)
  var skill="skill_pincer" if key=="skill_pincer" else "skill_item_use" if key.begins_with("item") else "skill_leg_sweep"
  var button=node("BattleSkill_"+skill)
  check(button!=null and button.icon!=null,"canonical skill has actual battle icon "+key)
  await reveal_battle_row(skill);battle_draw_contract(skill,key+" list")
  await capture("battle-"+key)
  if key in ["sweep1","skill_pincer"]:
   var detail="skill_stamp" if key=="sweep1" else "skill_pincer"
   var control=node("BattleSkill_"+detail)
   await os_mouse(screen_rect(control).get_center());await create_timer(.85).timeout;await frames()
   await capture("battle-hover-"+detail)
   await os_click(node("BattleSkillDetails_"+detail));check(node("SkillDetailsBody")!=null,"actual battle skill opens long/short full text "+detail)
   await capture("battle-full-"+detail);await os_key("Escape")
  check(await saved()==before,"battle skill list hover/full details preserve exact save "+key)
  if key=="sweep1":await selected_flow("skill_leg_sweep","sweep-selected")
func run():
 create_timer(600).timeout.connect(func():print("FAIL individual icons GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","individual icons use real X11 rendering and XTest input")
 var width=int(OS.get_environment("BRUSHUP_GUI_WIDTH"));width=1180 if width==0 else width
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(width,812 if width==1180 else 1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;await settle()
 DirAccess.make_dir_recursive_absolute(evidence.path_join("rendered"));ui_cases=fixtures_icons()
 await game.new_game();await settle()
 await normal_route();await inventory_cases();await shop_cases();await battle_cases()
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"all individual icon UI checks keep BGM voice SE OFF")
 for spec in [["checks.json",checks],["icon-ui-observations.json",icon_records],["fixture-boundaries.json",boundaries]]:
  var file=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);file.store_string(JSON.stringify(spec[1],"\t"));file.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
