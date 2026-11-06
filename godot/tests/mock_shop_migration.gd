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
 check(is_equal_approx(game.find_child("ShopCustomerArt",true,false).modulate.a,.2) and is_equal_approx(game.find_child("ShopKeeperArt",true,false).modulate.a,.2),"both portraits use translucent backdrop")
 var stock=game.find_child("ShopCatalog",true,false);var own=game.find_child("ShopInventory",true,false);var middle=game.find_child("ShopTransaction",true,false)
 check(own.global_position.x<middle.global_position.x and middle.global_position.x<stock.global_position.x,"inventory comparison stock order")
 check(absf(own.size.y-middle.size.y)<2 and absf(stock.size.y-middle.size.y)<2,"three panels share lower edge")
 shop.set_inventory_tab("equipment");await frames()
 check(game.find_child("ShopEquipped_head",true,false)!=null and game.find_child("ShopEquipped_feet",true,false)!=null,"equipment body icons available")
 await capture("shop-equipment")
 shop.set_inventory_tab("inventory")
 shop.open_comparison("javelin-wood");await settle()
 check(not game.modal_open() and game.find_child("ShopComparisonStats",true,false)!=null,"product comparison is inline")
 await capture("shop-comparison")
 var buyer=shop.selected_owner();var before_gold=int(game.campaign().gold)
 game.find_child("ShopComparisonBuy",true,false).pressed.emit();await settle()
 check(game.find_child("PurchaseAgree",true,false)!=null,"purchase confirmation uses canonical quote")
 game.dialog.close();await settle()
 check(int(game.campaign().gold)==before_gold,"cancel preserves money")
 game.find_child("ShopComparisonBuy",true,false).pressed.emit();await settle()
 game.find_child("PurchaseAgree",true,false).pressed.emit();await settle()
 check(int(game.campaign().gold)<before_gold,"purchase deducts canonical cost")
 check(shop.sale.entries().any(func(item):return item.id=="javelin-wood"),"purchased product enters selected inventory")
 shop.sale.select_item("javelin-wood");await settle()
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
