extends "res://tests/equipment_hover_gui.gd"
## Real X11 routes, plus explicitly validated synthetic QA boundaries.
var icons_baseline=OS.get_environment("INDIVIDUAL_ICONS_BASELINE")=="1"
var icon_records=[]
var boundaries=[]
var canvas_seen={}
var ui_cases={}
func fixtures_icons():
 var path=OS.get_environment("INDIVIDUAL_ICONS_FIXTURES")
 if path.is_empty():path=ProjectSettings.globalize_path("res://tests/individual_icons_fixtures.cjs")
 var output=[];var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),PackedStringArray([path]),output,true,false)
 check(code==0,"QA boundaries pass canonical C.validate and save roundtrip")
 var parsed=JSON.parse_string("".join(output));check(parsed.meta.gear_count==47,"fixture inventory contains 47 current canonical equipment IDs")
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
 var chooser=node("OwnedEquipmentSlot");var wanted=-1
 for index in range(chooser.item_count):
  if chooser.get_item_metadata(index)==value:wanted=index
 check(wanted>=0,"canonical inventory category exists "+value)
 await os_click(chooser);var popup=chooser.get_popup();var steps=0
 while popup.visible and popup.get_focused_item()!=wanted and steps<=chooser.item_count:
  await os_key("Down");steps+=1
 check(popup.visible and popup.get_focused_item()==wanted,"actual OS focuses canonical inventory category "+value)
 await os_key("Return")
 check(game.pages.party_view.owned_equipment_view.slot==value,"actual OS category selection applied "+value)
func reveal_battle_row(skill: String):
 var control=node("BattleSkillDetails_"+skill);var parent=control.get_parent()
 while parent!=null and not parent is ScrollContainer:parent=parent.get_parent()
 if parent is ScrollContainer:parent.ensure_control_visible(control)
 await settle()
func battle_draw_contract(skill: String,label: String):
 var row=game.data.skillset.filter(func(data):return data.id==skill)[0]
 var level=1
 for source in row.get("sources",[]):level=maxi(level,int(source.get("level",1)))
 var badged=game.icons.approved.skills.get(skill,{}).has("levels")
 var expected=32 if badged and not icons_baseline else 24
 var control=node("BattleSkill_"+skill);var info=node("BattleSkillDetails_"+skill)
 check(control.get_theme_constant("icon_max_width")==expected,label+" actual draw width "+str(expected)+" "+skill)
 var caption=str(row.name)+(" Lv%d" % level if badged and not icons_baseline else "")
 check(control.text.trim_prefix("● ")==caption,label+" caption equals canonical name and source level "+skill)
 check(visible_rect(control).encloses(control.get_global_rect()) and visible_rect(info).encloses(info.get_global_rect()),label+" skill and explanation button both fit panel clip "+skill)
func selected_flow(skill: String,label: String):
 await reveal_battle_row(skill);await os_click(node("BattleSkill_"+skill))
 var selected_boundary=await saved()
 if not game.can_commit():
  var candidates=game.data.choices.get("skill",[])
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
 check(game.campaign().phase=="town" and game.campaign().location=="astaris","fresh profile starts in normal square")
 boundaries.append({"key":"fresh-through-first-battle","kind":"actual OS normal route, no fixture"})
 await os_click(node("HubFacility_guild"));await os_click(node("GuildMember_guard"));await os_click(node("GuildDetails"))
 var empty=game.find_children("*","Button",true,false).filter(func(b):return b.get_meta("ui_key","")=="equipment_head")[0]
 check(empty.icon==null,"empty equipped slot remains iconless in actual status")
 var before=await saved();await capture("normal-equipped")
 await os_key("Escape");await os_click(node("GuildReturn"));await os_click(node("HubMap"));await os_click(node("Town_east"));await os_click(node("DepartButton"))
 var river=game.find_children("*","Button",true,false).filter(func(b):return b.text.begins_with("川沿いの道"))[0]
 await os_click(river);await os_click(node("DeploymentBegin"))
 check(game.campaign().phase=="battle","actual OS square/map/east/river/start reaches live battle")
 await os_click(game.hud.buttons.skill);await reveal_battle_row("archer");battle_draw_contract("archer","normal list");await capture("normal-battle-skills")
 await selected_flow("archer","normal-archer")
func inventory_cases():
 await at_fixture("east");await enter_facility("shop");await settle();await os_click(node("PartyFace_guard"))
 var before=await saved()
 check(node("OwnedEquipmentList").get_child_count()/3>=47,"all real equipment remains in existing personal list")
 await reveal("OwnedEquipment_javelin-wood","OwnedEquipmentScroll");await capture("owned-thin-spears")
 var pixels=[]
 for id in ["spear-wood","longspear-wood","javelin-wood"]:
  var b=node("OwnedEquipment_"+id);check(not b.text.is_empty() and b.icon!=null,"spear ID retains name beside art "+id);pixels.append(b.icon.get_image().get_data())
  await reveal("OwnedEquipment_"+id,"OwnedEquipmentScroll");await capture("owned-spear-"+id)
 if not icons_baseline:check(pixels[0]!=pixels[1] and pixels[1]!=pixels[2] and pixels[0]!=pixels[2],"three spear forms retain distinct actual rendered pixels")
 await reveal("OwnedEquipment_bow-silver-2","OwnedEquipmentScroll");await capture("owned-wood-iron-silver")
 await inventory_category("upperBody")
 await reveal("OwnedEquipment_armor-cloth","OwnedEquipmentScroll");await capture("owned-cloth-leather-metal")
 # Actual equipped native tooltip, long pincer effect, then full details.
 await hover_equipped("rightHand","pincer-equipped")
 await os_click(node("StatusTab_2"));await capture("person-skills32")
 await os_click(node("PartySkillDetails_pincer"));check(node("SkillDetailsBody")!=null,"actual character skill opens body-based full details")
 await capture("pincer-full-person");await os_key("Escape")
 check(await saved()==before,"owned list scrolling, hover and full details never mutate save")
 await os_key("Escape")
func shop_cases():
 for place in ["east","west","north","south"]:
  await at_fixture(place);await enter_facility("shop");await settle();var before=await saved()
  if place=="south":
   await capture("shop-items");check(await saved()==before,"item shop inspection preserves save");continue
  var product="javelin-wood" if place=="east" else "armor-silver-1" if place=="west" else "lone-ring-1"
  await reveal("Product_"+product,"ShopProductsScroll");await capture("shop-"+place)
  await os_click(node("Product_"+product));check(node("ShopComparisonStats")!=null and not node("ShopComparisonProduct").text.is_empty(),"named product comparison opens "+place)
  await capture("comparison-"+place);await os_click(node("ShopComparisonBack"))
  check(await saved()==before,"comparison and cancellation preserve exact save "+place)
 # Representative ordinary purchase, cancel, and two-count sale use canonical quotes.
 await at_fixture("east");await enter_facility("shop");await settle();var before=await saved()
 await reveal("ProductBuy_spear-wood","ShopProductsScroll");await os_click(node("ProductBuy_spear-wood"));await os_click(node("PurchaseDecline"))
 check(await saved()==before,"ordinary purchase cancellation consumes no money or inventory")
 await os_click(node("ProductBuy_spear-wood"));await os_click(node("PurchaseAgree"));await os_click(node("PurchaseRecipient_guard"))
 var bought=await saved();var price=game.campaign().shop.filter(func(g):return g.id=="spear-wood")[0].price
 check(int(bought.state.gold)==int(before.state.gold)-int(price) and int(bought.state.characters.guard.inventory["spear-wood"])==int(before.state.characters.guard.inventory["spear-wood"])+1,"actual ordinary purchase matches displayed canonical price and owner quantity")
 await os_click(node("PartyFace_guard"));await reveal("OwnedInventorySell_spear-wood","OwnedEquipmentScroll");await os_click(node("OwnedInventorySell_spear-wood"))
 var quantity=node("InventoryQuantity");await os_click(quantity.get_line_edit());await os_key("Home");await os_key("Delete");await os_key("2");await os_key("Return")
 check(int(node("InventoryQuantity").value)==2,"actual OS sale quantity is two")
 var quote=(await game.engine.request({"op":"campaign","action":"saleQuote","args":["guard","spear-wood",2]})).saleQuote
 await capture("sale-quantity");await os_click(node("InventoryPrepareSale"));await os_click(node("InventoryCancel"))
 check(await saved()==bought,"actual sale NO preserves all inventory and money")
 await os_click(node("InventoryPrepareSale"));await os_click(node("InventoryConfirm"));var sold=await saved()
 check(int(sold.state.gold)==int(quote.afterGold) and int(sold.state.characters.guard.inventory["spear-wood"])==int(bought.state.characters.guard.inventory["spear-wood"])-2,"actual sale matches canonical total and exact owner quantity")
 await os_key("Escape")
func battle_cases():
 for key in ["sweep1","sweep2","sweep3","pincer","item1","item3"]:
  await at_fixture(key);var before=await saved();await os_click(game.hud.buttons.skill)
  var skill="pincer" if key=="pincer" else "itemUse" if key.begins_with("item") else "legSweep"
  var button=node("BattleSkill_"+skill)
  check(button!=null and button.icon!=null,"canonical skill has actual battle icon "+key)
  await reveal_battle_row(skill);battle_draw_contract(skill,key+" list")
  await capture("battle-"+key)
  if key in ["sweep1","pincer"]:
   var detail="stamp" if key=="sweep1" else "pincer"
   var control=node("BattleSkill_"+detail)
   await os_mouse(screen_rect(control).get_center());await create_timer(.85).timeout;await frames()
   await capture("battle-hover-"+detail)
   await os_click(node("BattleSkillDetails_"+detail));check(node("SkillDetailsBody")!=null,"actual battle skill opens long/short full text "+detail)
   await capture("battle-full-"+detail);await os_key("Escape")
  check(await saved()==before,"battle skill list hover/full details preserve exact save "+key)
  if key=="sweep1":await selected_flow("legSweep","sweep-selected")
func run():
 create_timer(600).timeout.connect(func():print("FAIL individual icons GUI watchdog");quit(2))
 check(DisplayServer.get_name()!="headless","individual icons use real X11 rendering and XTest input")
 var width=int(OS.get_environment("BRUSHUP_GUI_WIDTH"));width=1180 if width==0 else width
 root.borderless=true;root.position=Vector2i.ZERO;root.size=Vector2i(width,812 if width==1180 else 1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true;baseline=icons_baseline;await settle()
 DirAccess.make_dir_recursive_absolute(evidence.path_join("rendered"));ui_cases=fixtures_icons()
 await normal_route();await inventory_cases();await shop_cases();await battle_cases()
 check(game.audio.muted.bgm and game.audio.muted.voice and game.audio.muted.se,"all individual icon UI checks keep BGM voice SE OFF")
 for spec in [["checks.json",checks],["icon-ui-observations.json",icon_records],["fixture-boundaries.json",boundaries],["hover-layout.json",observations]]:
  var file=FileAccess.open(evidence.path_join(spec[0]),FileAccess.WRITE);file.store_string(JSON.stringify(spec[1],"\t"));file.close()
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames();quit(0 if checks.all(func(c):return c.passed) else 1)
