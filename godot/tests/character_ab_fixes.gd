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
func run():
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 var uid=str(game.campaign().selected[0]);var save=(await game.engine.request({"op":"campaign_save"})).data
 save.state.characters[uid].inventory={"potion":2,"javelin-wood":1}
 await game.update({"op":"campaign_load","data":save});game.navigate("character");await settle()
 var ws=game.pages.party_view.workspace;ws.set_tab("inventory");await settle()
 ws.picked=game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="javelin-wood")[0];game.render();await settle()
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
 await shot("fixed-inventory-left")
 game.find_child("CharacterEquip",true,false).pressed.emit();await settle()
 check(game.roster().filter(func(u):return u.id==uid)[0].stats.def==7,"selected slot equip matches displayed preview")
 var potion=game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="potion")[0]
 ws.confirm_discard(uid,potion);await settle();game.dialog.close();await settle()
 check(game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="potion")[0].count==2,"discard cancel preserves inventory")
 ws.confirm_discard(uid,potion);await settle();game.pages.epoch+=1;game.find_child("CharacterDiscardConfirm",true,false).pressed.emit();await settle()
 check(game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="potion")[0].count==2,"stale discard confirmation cannot mutate inventory")
 ws.confirm_discard(uid,potion);await settle();game.find_child("CharacterDiscardQuantity",true,false).value=1;game.find_child("CharacterDiscardConfirm",true,false).pressed.emit();await settle()
 check(game.campaign().inventoryByCharacter[uid].entries.filter(func(e):return e.id=="potion")[0].count==1,"discard quantity uses canonical commit")
 ws.set_tab("skills");await settle()
 check(game.find_children("CharacterSkill_active_secretPouch*","Button",true,false).is_empty(),"passive sources excluded from active group")
 check(game.find_children("CharacterSkill_passive_secretPouch*","Button",true,false).size()==2,"passive stacking sources retained separately")
 check(game.find_children("CharacterSkill_passive_secretPouch*","Button",true,false).all(func(b):return b.text.contains("Lv1") and b.text.contains("/")),"passive source and level visible")
 await shot("fixed-skills")
 ws.set_tab("ability");await settle()
 var labels="\n".join(game.find_children("*","Label",true,false).filter(func(n):return n.is_visible_in_tree()).map(func(n):return n.text))
 check(labels.contains("EXP 0") and labels.contains("通常ATK") and labels.contains("射程") and labels.contains("属性ATK") and labels.contains("人間"),"ability retains experience identity attack reach and elemental attack")
 await shot("fixed-ability")
 ws.set_tab("inventory");await settle();var filter=game.find_child("CharacterInventoryFilter",true,false);filter.item_selected.emit(1);await settle()
 check(not game.find_children("*","Button",true,false).any(func(b):return b.text.contains("護衛盾") and b.text.contains("×")),"consumable filter hides equipment")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
