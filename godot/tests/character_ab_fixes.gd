extends SceneTree
var game
var failures=[]
func _initialize():call_deferred("run")
func check(ok,label):
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failures.append(label)
func settle():
 for i in range(15):await process_frame
 while game.locked or game.engine.busy:await process_frame
 for i in range(10):await process_frame
func shot(label):
 if OS.get_environment("CHARACTER_FIX_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("CHARACTER_FIX_CAPTURE").path_join(label+".png"))
func drag_item(source: Control,target: Vector2):
 var start=source.get_global_rect().get_center()
 var motion=InputEventMouseMotion.new();motion.position=start;root.push_input(motion)
 var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=start;root.push_input(press)
 await process_frame
 for point in [start+Vector2(22,0),target]:
  motion=InputEventMouseMotion.new();motion.position=point;motion.relative=point-start;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion)
  await process_frame
 check(root.gui_is_dragging(),"inventory row starts a pointer drag")
 var release=InputEventMouseButton.new();release.position=target;release.button_index=MOUSE_BUTTON_LEFT;root.push_input(release)
 await settle()
func item_row(name_: String):
 for b in game.find_children("*","Button",true,false):
  if b.tooltip_text==name_ and b.text.contains("Wt"):return b
 return null
func click_and_close_details(button: Button,expects_detail:=true):
 button.pressed.emit();await settle()
 var detail=game.find_child("SkillDetailsWindow",true,false)
 if expects_detail:check(detail!=null and detail.visible,"item click opens common details")
 if detail!=null:detail.finish();await settle()
func run():
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 var uid=str(game.campaign().selected[0]);var save=(await game.engine.request({"op":"campaign_save"})).data
 save.state.characters[uid].inventory={"potion":2,"javelin-wood":1}
 await game.update({"op":"campaign_load","data":save});game.navigate("character");await settle()
 var ws=game.pages.party_view.workspace;ws.set_tab("inventory");await settle()
 var candidate=game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="javelin-wood")[0]
 await click_and_close_details(item_row(candidate.name))
 check(game.find_child("CharacterEquipCancel",true,false)!=null and game.find_child("CharacterDiscard",true,false)!=null,"clicked gear offers comparison cancel and separate discard")
 game.find_child("CharacterEquipCancel",true,false).pressed.emit();await settle()
 check(ws.picked.is_empty(),"cancel returns to inventory without equipping")
 await drag_item(item_row(candidate.name),game.find_child("RosterMember_"+uid,true,false).get_global_rect().get_center())
 check(ws.picked.get("id")==candidate.id and not game.modal_open(),"drop on owner previews equipment without discarding")
 check(game.find_children("CharacterEquip","Button",true,false).size()==1,"single equip action")
 check(not game.find_children("*","Button",true,false).any(func(b):return b.is_visible_in_tree() and b.text.ends_with("に使う")),"equipment has no consumable target controls")
 var selector=game.find_child("CharacterEquipSlot",true,false)
 for i in range(selector.item_count):
  if selector.get_item_metadata(i)=="leftHand":selector.item_selected.emit(i);break
 await settle()
 ws.equip_slot="rightHand";game.render()
 check(game.find_child("CharacterEquip",true,false).disabled,"equip disabled while replacement quote pending")
 ws.equip_slot="leftHand";game.render();await settle()
 var comparison=game.find_child("CharacterEquipmentComparison",true,false)
 check(comparison.text.contains("左手") and comparison.text.contains("9 → 7"),"left slot preview reports actual shield defense loss")
 var party_comparison_width=game.find_child("CharacterEquipmentDetail",true,false).size.x
 var pair=game.find_child("ShopComparisonSkills",true,false)
 check(pair.get_child(0).find_child("CharacterComparisonSkill_失う_*",true,false)!=null and pair.get_child(1).find_child("CharacterComparisonSkill_追加_*",true,false)!=null,"lost and gained skills belong to the current and candidate columns")
 await shot("fixed-inventory-left")
 game.find_child("CharacterEquip",true,false).pressed.emit();await settle()
 check(game.roster().filter(func(u):return u.id==uid)[0].stats.def==7,"selected slot equip matches displayed preview")
 var potion=game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="potion")[0]
 await drag_item(item_row(potion.name),game.get_viewport_rect().end-Vector2(3,3))
 check(game.find_child("CharacterDiscardConfirm",true,false)!=null,"outside drop asks for discard quantity")
 game.dialog.close();await settle()
 check(game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="potion")[0].count==2,"discard cancel preserves inventory")
 ws.confirm_discard(uid,potion);await settle();game.pages.epoch+=1;game.find_child("CharacterDiscardConfirm",true,false).pressed.emit();await settle()
 check(game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="potion")[0].count==2,"stale discard confirmation cannot mutate inventory")
 await drag_item(item_row(potion.name),game.get_viewport_rect().end-Vector2(3,3));await settle();game.find_child("CharacterDiscardQuantity",true,false).value=1;game.find_child("CharacterDiscardConfirm",true,false).pressed.emit();await settle()
 check(game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="potion")[0].count==1,"discard quantity uses canonical commit")
 var other=str(game.campaign().selected[1])
 var previous=int(game.campaign().characters[other].inventory.get("potion",0))
 await drag_item(item_row(potion.name),game.find_child("RosterMember_"+other,true,false).get_global_rect().get_center())
 check(not game.modal_open() and int(game.campaign().characters[other].inventory.get("potion",0))==previous+1,"drop on teammate transfers the item without a discard prompt")
 ws.set_tab("skills");await settle()
 check(game.find_children("CharacterSkill_active_skill_secret_pouch*","Button",true,false).is_empty(),"passive sources excluded from active group")
 check(game.find_children("CharacterSkill_passive_skill_secret_pouch*","Button",true,false).size()==2,"passive stacking sources retained separately")
 check(game.find_children("CharacterSkill_passive_skill_secret_pouch*","Button",true,false).all(func(b):return b.text.begins_with(game.campaign().skillNames.skill_secret_pouch) and not b.tooltip_text.is_empty()),"skill buttons show the skill name with details on hover")
 await shot("fixed-skills")
 ws.set_tab("ability");await settle()
 var labels="\n".join(game.find_children("*","Label",true,false).filter(func(n):return n.is_visible_in_tree()).map(func(n):return n.text))
 check(labels.contains("EXP 0") and labels.contains("通常ATK") and labels.contains("射程") and labels.contains("属性ATK") and labels.contains("人間"),"ability retains experience identity attack reach and elemental attack")
 var elemental=game.find_children("ElementIcon_fire","TextureRect",true,false)
 check(elemental.size()>=2 and elemental.all(func(icon):return icon.texture!=null and icon.get_parent().size.y<50),"elemental attack and defense use artwork in single-line rows")
 await shot("fixed-ability")
 ws.set_tab("inventory");await settle();var filter=game.find_child("CharacterInventoryFilter",true,false);filter.item_selected.emit(1);await settle()
 check(not game.find_children("*","Button",true,false).any(func(b):return b.text.contains("護衛盾") and b.text.contains("×")),"consumable filter hides equipment")
 save.state.location="east"
 await game.update({"op":"campaign_load","data":save});game.navigate("shop");await settle()
 game.find_child("FacilityChoice_buy",true,false).pressed.emit();await settle()
 var shop=game.pages.shop_view
 shop.set_inventory_tab("inventory");await settle()
 var own=game.find_child("RosterMember_"+uid,true,false).get_global_rect().get_center()
 var source=game.find_child("SaleItem_javelin-wood",true,false)
 var before_shop=(await game.engine.request({"op":"campaign_save"})).data
 await drag_item(source,own)
 var confirm=game.find_child("CharacterEquip",true,false)
 check(confirm!=null and not confirm.disabled,"shop owner drop offers the live equip quote")
 if confirm!=null:
  var panel=game.find_child("ShopTransaction",true,false)
  check(absf(panel.size.x-party_comparison_width)<=1,"party equipment change and shop transaction widths: %s / %s" % [party_comparison_width,panel.size.x])
  game.find_child("CharacterEquipCancel",true,false).pressed.emit();await settle()
  check((await game.engine.request({"op":"campaign_save"})).data==before_shop,"shop equip cancel preserves gold and equipment")
  await drag_item(game.find_child("SaleItem_javelin-wood",true,false),own)
  game.find_child("CharacterEquip",true,false).pressed.emit();await settle()
  check(not game.campaign().characters[uid].inventory.has("javelin-wood") and int(game.campaign().gold)==int(before_shop.state.gold),"equipping owned stock consumes it without charging gold")
 shop.set_inventory_tab("equipment");await settle()
 await click_and_close_details(game.find_child("ShopEquipped_feet",true,false),false)
 await click_and_close_details(game.find_child("Product_javelin-wood",true,false))
 check(game.find_child("ShopEquipped_rightHand",true,false).get_meta("selected",false),"product selection moves highlight to a compatible hand")
 await click_and_close_details(game.find_child("ShopEquipped_leftHand",true,false))
 check(shop.comparison_view.slot=="leftHand" and game.find_child("ShopEquipped_leftHand",true,false).get_meta("selected",false),"clicking the left hand compares against that hand")
 var notes=game.find_child("ShopComparisonNotes",true,false)
 check(notes!=null and shop.comparison_view.panels[1].is_ancestor_of(notes),"candidate note stays inside its own column")
 await shot("shop-left-hand")
 save.state.location="north"
 await game.update({"op":"campaign_load","data":save});game.navigate("shop");await settle()
 game.find_child("FacilityChoice_buy",true,false).pressed.emit();await settle()
 shop.set_inventory_tab("equipment");await settle()
 await click_and_close_details(game.find_child("Product_lone-ring-1",true,false))
 await click_and_close_details(game.find_child("ShopEquipped_accessory2",true,false),false)
 check(shop.comparison_view.slot=="accessory2" and game.find_child("ShopEquipped_accessory2",true,false).get_meta("selected",false),"second accessory icon switches comparison and highlight")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
