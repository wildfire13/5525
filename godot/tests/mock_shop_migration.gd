extends SceneTree
var game
var checks=[]
func _initialize():call_deferred("run")
func frames(count:=10):
 for i in range(count):await process_frame
func check(ok: bool,label: String):
 checks.append(ok);print(("PASS " if ok else "FAIL ")+label)
func settle():
 await frames()
 while game.locked or game.engine.busy or game.presenting:await process_frame
 await frames()
func capture(label: String):
 if OS.get_environment("MOCK_SHOP_CAPTURE").is_empty():return
 await frames(4);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("MOCK_SHOP_CAPTURE").path_join(label+".png"))
func run():
 root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();root.add_child(game)
 var deadline=Time.get_ticks_msec()+20000
 while game.data.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 if game.data.is_empty():push_error("initialization timeout");quit(2);return
 game.audio.fast_mode=true;game.checks_fast=true
 var save=(await game.engine.request({"op":"campaign_save"})).data
 save.state.location="east";save.state.gold=1000
 await game.update({"op":"campaign_load","data":save})
 game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
 var shop=game.pages.shop_view
 check(game.find_child("ShopInventory",true,false)!=null and game.find_child("ShopCatalog",true,false)!=null,"inventory and stock shown together")
 check(game.find_child("ShopExit",true,false)!=null,"transaction exit exists without selection")
 check(is_equal_approx(game.find_child("ShopCustomerArt",true,false).modulate.a,.22) and is_equal_approx(game.find_child("ShopKeeperArt",true,false).modulate.a,.2),"both portraits use translucent backdrop")
 var stock=game.find_child("ShopCatalog",true,false);var own=game.find_child("ShopInventory",true,false);var middle=game.find_child("ShopTransaction",true,false)
 check(own.global_position.x<middle.global_position.x and middle.global_position.x<stock.global_position.x,"inventory comparison stock order")
 check(absf(own.get_global_rect().end.y-middle.get_global_rect().end.y)<2 and absf(stock.size.y-middle.size.y)<2,"three panels share lower edge")
 shop.set_inventory_tab("equipment");await frames()
 check(game.find_child("ShopEquipped_head",true,false)!=null and game.find_child("ShopEquipped_feet",true,false)!=null,"equipment body icons available")
 var shop_rects=[]
 var party_nodes=["CharacterTab_equipment","CharacterTab_inventory","CharacterPortrait"]
 for n in ["ShopInventoryTab_equipment","ShopInventoryTab_inventory","ShopCustomerArt"]:
  shop_rects.append(game.find_child(n,true,false).get_global_rect())
 for part in ["head","rightHand","upperBody","leftHand","lowerBody","feet","accessory1","accessory2"]:
  shop_rects.append(game.find_child("ShopEquipped_"+part,true,false).get_global_rect())
  party_nodes.append("CharacterSlot_"+part)
 game.mock_shell.toggle_character();await settle()
 for i in range(party_nodes.size()):
  check(game.find_child(party_nodes[i],true,false).get_global_rect()==shop_rects[i],"same geometry for "+party_nodes[i])
 game.mock_shell.toggle_character();await settle()
 await capture("shop-equipment")
 shop.set_inventory_tab("inventory")
 shop.open_comparison("javelin-wood");await settle()
 check(not game.modal_open() and game.find_child("ShopComparisonStats",true,false)!=null,"product comparison is inline")
 check(game.find_child("ShopComparisonNotes",true,false)!=null and game.find_child("ShopComparisonNotes",true,false).text.contains("戦闘後に回収する"),"purchase comparison preserves mechanical recovery note")
 await capture("shop-comparison")
 var purchase_rect=game.find_child("ShopComparisonBuy",true,false).get_global_rect()
 check(root.get_visible_rect().encloses(purchase_rect),"purchase button visible at FHD")
 var buyer=shop.selected_owner();var before_gold=int(game.campaign().gold)
 game.find_child("ShopComparisonBuy",true,false).pressed.emit();await settle()
 check(game.find_child("PurchaseAgree",true,false)!=null,"purchase confirmation uses canonical quote")
 game.dialog.close();await settle()
 check(int(game.campaign().gold)==before_gold,"cancel preserves money")
 game.find_child("ShopComparisonBuy",true,false).pressed.emit();await settle()
 game.find_child("PurchaseAgree",true,false).pressed.emit();await settle()
 check(int(game.campaign().gold)<before_gold,"purchase deducts canonical cost")
 check(shop.sale.entries().any(func(item):return item.id=="javelin-wood"),"purchased product enters selected inventory")
 var filter=game.find_child("ShopInventoryFilter",true,false)
 filter.select(1);filter.item_selected.emit(1);await settle()
 check(game.find_child("SaleItem_javelin-wood",true,false)==null,"consumable filter hides purchased weapon")
 filter=game.find_child("ShopInventoryFilter",true,false)
 filter.select(0);filter.item_selected.emit(0);await settle()
 game.find_child("SaleItem_javelin-wood",true,false).pressed.emit();await settle()
 var title_count=game.find_child("ShopTransactionScroll",true,false).find_children("*","Label",true,false).filter(func(label):return label.text=="木製の投げ槍").size()
 check(title_count==1,"sale detail names the selected weapon once")
 check(game.find_child("FacilitySalePrepare",true,false)!=null and shop.sale.quote.get("ok",false),"same workspace prepares sell quote")
 var quote=shop.sale.quote.duplicate(true)
 shop.sale.confirm_sale();await settle()
 check(shop.sale.stage=="confirm","sell confirmation opens")
 shop.sale.confirmation.canceled.emit();shop.sale.confirmation.hide();shop.sale.confirmation.queue_free();await settle()
 check(int(game.campaign().gold)==before_gold-int(shop.receipt.cost),"sell cancel preserves resources")
 shop.sale.confirm_sale();await settle();shop.sale.confirmation.confirmed.emit();await settle()
 check(int(game.campaign().gold)==int(quote.afterGold),"sale applies canonical proceeds once")
 shop.finish_trading();await settle()
 check(game.pages.facility_entry.at_top("shop") and shop.selection_kind.is_empty() and shop.sale.item_id.is_empty(),"transaction exit resets selection and returns entry")
 await recipient_regression()
 for place in ["west","north","south"]:
  var next=(await game.engine.request({"op":"campaign_save"})).data;next.state.location=place;next.state.gold=1000
  await game.update({"op":"campaign_load","data":next});game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
  check(game.find_child("ShopCatalog",true,false)!=null and game.find_child("ShopInventory",true,false)!=null,place+" shared trading layout")
  var product=shop.offered()[0]
  shop.open_comparison(str(product.id));await settle()
  var target=str(game.campaign().selected[1]);shop.owner_pressed(target);await settle()
  check(shop.selected_owner()==target and shop.sale.owner_id==target,place+" roster selection changes inventory and quote owner")
  if place=="south":
   game.find_child("ShopPurchaseQuantity",true,false).value=3;await settle()
   var money=int(game.campaign().gold);var old_count=int(game.campaign().characters[target].inventory.get(product.id,0))
   game.find_child("ProductBuy_"+str(product.id)+"_1",true,false).pressed.emit();await settle()
   game.find_child("PurchaseAgree",true,false).pressed.emit();await settle()
   check(int(game.campaign().gold)==money-3*int(product.price) and int(game.campaign().characters[target].inventory.get(product.id,0))==old_count+3,"consumable quantity applies exact selected amount to chosen member")
  else:
   check(game.find_child("ShopComparisonStats",true,false)!=null and not game.modal_open(),place+" inline gear comparison")
  await capture("shop-"+place)
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames(4)
 quit(0 if checks.all(func(value):return value) else 1)
func recipient_regression():
 var shop=game.pages.shop_view
 var ids=game.campaign().selected
 var old=str(ids[0]);var chosen=str(ids[1])
 var seed=(await game.engine.request({"op":"campaign_save"})).data
 seed.state.characters[chosen].inventory={};seed.state.characters[old].inventory={};seed.state.gold=1000
 await game.update({"op":"campaign_load","data":seed})
 game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
 game.mock_shell.activate(old);shop.finish_trading();await settle()
 game.mock_shell.toggle_character();game.mock_shell.activate(chosen);await settle()
 game.mock_shell.toggle_character();game.navigate("hub");game.navigate("shop");await settle()
 game.find_child("FacilityChoice_buy",true,false).pressed.emit();await settle()
 check(game.shop_uid==chosen and shop.sale.owner_id==chosen and game.pages.party_uid==chosen,"entry adopts party selection for card and inventory owner")
 shop.open_comparison("javelin-wood");await settle()
 check(shop.comparison_view.owner_id==chosen,"entry comparison uses selected party member")
 game.find_child("ShopComparisonBuy",true,false).pressed.emit();await settle()
 check(game.dialog.window.find_children("*","Label",true,false).any(func(label):return label.text.contains(game.member_name(chosen)+"のインベントリ")),"purchase confirmation names selected member")
 var before=(await game.engine.request({"op":"campaign_save"})).data
 game.mock_shell.activate(old);await settle()
 check(game.pages.party_uid==chosen and game.shop_uid==chosen,"modal blocks card selection as well as transaction owner")
 game.dialog.close();await settle()
 check((await game.engine.request({"op":"campaign_save"})).data==before,"recipient cancellation preserves exact save")
 game.find_child("ShopComparisonBuy",true,false).pressed.emit();await settle()
 game.find_child("PurchaseAgree",true,false).pressed.emit();await settle()
 check(int(game.campaign().characters[chosen].inventory.get("javelin-wood",0))==1 and int(game.campaign().characters[old].inventory.get("javelin-wood",0))==0,"purchase goes only to party-selected member")
 # Explicit drag destination takes priority without changing the browsing owner.
 var payload={"kind":"shop_product","item":"javelin-wood","connection":game.engine.connection_generation,"epoch":game.pages.epoch,"token":game.campaign().get("inventoryToken")}
 check(game.mock_shell.can_drop(payload,old) and not game.mock_shell.can_drop(payload,"missing-member"),"drag accepts roster destination and rejects missing member")
 var stale=payload.duplicate();stale.epoch=-1
 check(not game.mock_shell.can_drop(stale,old),"drag rejects stale visit payload")
 game.mock_shell.drop(payload,old);await settle()
 check(game.dialog.window.find_children("*","Label",true,false).any(func(label):return label.text.contains(game.member_name(old)+"のインベントリ")),"drag confirmation names explicit destination")
 game.find_child("PurchaseAgree",true,false).pressed.emit();await settle()
 check(int(game.campaign().characters[old].inventory.get("javelin-wood",0))==1 and game.shop_uid==chosen and game.pages.party_uid==chosen,"drag buys for destination and preserves browsing selection")
 before=(await game.engine.request({"op":"campaign_save"})).data
 await shop.start_trial("javelin-wood");await settle()
 var trial=game.find_child("TrialRecipient_"+old,true,false)
 check(trial!=null and not trial.disabled,"other member can try selected product")
 if trial!=null and not trial.disabled:
  trial.pressed.emit();await settle()
  check(game.data.get("trial")!=null,"trial starts for explicit member")
  await game.act("endTrial",[]);await settle()
  check(game.shop_uid==old and game.pages.party_uid==old and shop.sale.owner_id==old and shop.comparison_view.owner_id==old,"trial return aligns card inventory and comparison with tried member")
  check((await game.engine.request({"op":"campaign_save"})).data==before,"trial preserves exact campaign save")
  check(game.pages.gear_id=="javelin-wood","trial return retains selected product")
