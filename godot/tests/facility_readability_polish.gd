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
 if OS.get_environment("POLISH_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("POLISH_CAPTURE").path_join(label+".png"))
func run():
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 var seed=(await game.engine.request({"op":"campaign_save"})).data
 seed.state.location="east";seed.state.gold=1000
 await game.update({"op":"campaign_load","data":seed});game.navigate("shop");game.pages.facility_entry.choose("buy");await settle()
 var scroll=game.find_child("ShopProductsScroll",true,false);var visible=0
 for row in game.find_children("Product_*","Button",true,false):
  if row.is_visible_in_tree() and scroll.get_global_rect().encloses(row.get_global_rect()):visible+=1
 check(visible>=11,"FHD catalog shows at least eleven complete products")
 check(game.find_child("ShopWorkspace",true,false).size.y==game.mock_shell.content_height(),"shop height matches shared roster")
 game.pages.shop_view.open_comparison("javelin-wood");await settle()
 check(game.find_child("ShopComparisonStats",true,false).get_theme_font_size("normal_font_size")==22,"comparison body 22px")
 check(game.find_child("ShopComparisonProduct",true,false).get_theme_font_size("font_size")==28,"comparison heading 28px")
 await shot("shop-readable")
 var items=game.campaign().shop.filter(func(e):return e.get("type")!="empty" and e.get("shopProductId",e.id)==e.id)
 seed.state.location="astaris";seed.state.warehouse={"potion":50,"ether":50}
 var porter=str(game.campaign().selected[4]);seed.state.characters[porter].inventory={"potion":20,"ether":20}
 for item in items:
  seed.state.warehouse[item.id]=2;seed.state.characters[porter].inventory[item.id]=1
 var loaded=await game.update({"op":"campaign_load","data":seed});print("LOAD_WAREHOUSE ",loaded.get("ok")," ",loaded.get("error",""));game.navigate("party");game.pages.facility_entry.choose("warehouse");await settle()
 var warehouse=game.pages.warehouse_view;warehouse.select_owner(porter);warehouse.choose("warehouse","potion");await settle()
 check(game.find_child("WarehouseItemEffect",true,false).text=="HPを55回復","warehouse effect uses canonical item definition")
 check(game.find_child("WarehouseStorage",true,false).get_parent().size.x>=420,"warehouse lists widened")
 check(game.find_child("WarehouseColumns",true,false).size.y==game.mock_shell.content_height(),"warehouse lower edge matches roster")
 await shot("warehouse-many")
 warehouse.choose("warehouse","javelin-wood");await settle()
 var labels="\n".join(game.find_child("WarehouseSelectedItem",true,false).find_children("*","Label",true,false).map(func(n):return n.text))
 check(labels.contains("戦闘後に回収"),"warehouse gear detail preserves practical equipment note")
 game.navigate("board");await settle()
 # UI stress projection uses the existing cargoItems/rewards fields; not a new backend reward system.
 var quest=game.campaign().board[0]
 quest.cargoItems=[]
 for i in range(14):quest.cargoItems.append({"name":"検証用の荷物%d" % i,"icon":"potion" if i%2==0 else "ether","quantity":99,"weight":.5})
 quest.rewards={"type":"experience","base":999999,"bonus":888888,"baseRP":777777,"bonusRP":666666,"legacyXP":true};quest.xp=345
 game.render();await settle()
 var cargo=game.find_child("QuestCargoItems",true,false)
 check(cargo.get_child_count()==14,"all fourteen cargo groups render")
 check(cargo.size.y>40,"cargo wraps instead of pushing detail width")
 check(game.find_child("QuestCargoWeight",true,false).text=="合計Wt 693","multi cargo total weight correct")
 check(cargo.get_child(0).get_child(0).tooltip_text=="検証用の荷物0","cargo identity available on icon hover")
 labels="\n".join(game.find_child("QuestDetailBody",true,false).find_children("*","Label",true,false).map(func(n):return n.text))
 check(labels.contains("×345") and labels.contains("×999999") and labels.contains("RP ×777777"),"large EXP RP and legacy boolean rewards preserve quantities")
 check(game.find_child("QuestBoardColumns",true,false).get_global_rect().end.x<=1920,"stress quest remains within FHD width")
 await shot("quest-cargo-stress")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
