extends "res://tests/ui_feedback_20261016.gd"
func quote_ready():
 await settle()
 for i in range(300):
  if node("ShopComparisonPayment")!=null and not node("ShopComparisonPayment").text.contains("確認中"):return
  await process_frame
 check(false,"quote completes")
func contrast(a: Color,b: Color) -> float:
 var x=a.srgb_to_linear().get_luminance();var y=b.srgb_to_linear().get_luminance()
 return (maxf(x,y)+.05)/(minf(x,y)+.05)
func capture(label: String):
 if OS.get_environment("TRADE_CAPTURE")!="1":return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(evidence.path_join(label+".png"))
func run():
 create_timer(120).timeout.connect(func():push_error("trade watchdog");quit(2))
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.audio.fast_mode=true;game.checks_fast=true
 var seed=await saved();seed.state.location="east";seed.state.gold=55
 await game.update({"op":"campaign_load","data":seed});await enter_facility("shop")
 var shop=game.pages.shop_view
 shop.open_comparison("greatsword-wood");await quote_ready()
 var payment=node("ShopComparisonPayment");var buy=node("ShopComparisonBuy");var trial=node("ProductTrial_greatsword-wood")
 check(payment.text.contains("購入不可") and buy.disabled,"insufficient funds remain blocked")
 check(payment.get_theme_color("font_color")==Color("#a84432"),"insufficient funds use negative information color")
 check(payment.get_global_rect().position.y>node("ShopTransactionScroll").get_global_rect().end.y-1 and payment.get_global_rect().end.y<=buy.get_global_rect().position.y,"payment warning stays below scrollable detail and above actions")
 check(trial.get_parent()==buy.get_parent() and trial.get_index()<buy.get_index() and trial.get_global_rect().end.x<=buy.get_global_rect().position.x,"trial sits immediately left of purchase in footer")
 var skills=node("ShopComparisonSkills").find_children("ComparisonSkill*","Button",true,false)
 check(not skills.is_empty(),"real comparison supplies skill hover")
 if not skills.is_empty():
  var tip=skills[0]._make_custom_tooltip(skills[0].tooltip_text);game.add_child(tip)
  check(contrast(tip.get_theme_color("font_color"),skills[0].get_theme_stylebox("panel","TooltipPanel").bg_color)>=4.5,"skill hover text contrasts with its actual tooltip surface")
  check(tip.text==skills[0].tooltip_text,"hover preserves complete skill description");tip.queue_free()
 node("ShopTransactionScroll").scroll_vertical=200;await frames()
 check(payment.get_global_rect().end.y<=buy.get_global_rect().position.y and trial.get_parent()==buy.get_parent(),"scrolling cannot hide warning or trial action")
 node("ShopTransactionScroll").scroll_vertical=0;await frames()
 await capture("trade-insufficient")
 if OS.get_environment("TRADE_CAPTURE")=="1" and not skills.is_empty():
  var motion=InputEventMouseMotion.new();motion.position=skills[0].get_global_rect().get_center();motion.global_position=motion.position
  root.push_input(motion);await create_timer(1.2).timeout
  await capture("trade-skill-hover")
  Input.warp_mouse(Vector2(1900,1060));await create_timer(.2).timeout
 await click("ProductTrial_greatsword-wood")
 check(game.modal_open() and game.dialog.window.title=="木人で試す人物","relocated trial opens its original recipient selection even without purchase funds")
 await click("TrialRecipientCancel")
 seed.state.gold=1000;await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");shop.open_comparison("greatsword-wood");await quote_ready()
 payment=node("ShopComparisonPayment")
 check(payment.text=="所持金 1000G − 購入 140G = 残金 860G","purchase displays correct subtraction equation")
 check(payment.get_parent().find_child("Icon_money",true,false)!=null,"payment equation includes existing money icon")
 check(not node("ShopComparisonBuy").disabled and payment.get_theme_color("font_color")!=Color("#a84432"),"affordable selection clears negative state")
 await capture("trade-equation")
 var before=await saved();await click("ShopComparisonBuy");await click("PurchaseDecline")
 check(await saved()==before,"cancel preserves money inventory and equipment")
 seed.state.gold=140;await game.update({"op":"campaign_load","data":seed});await enter_facility("shop");shop.open_comparison("greatsword-wood");await quote_ready()
 check(node("ShopComparisonPayment").text=="所持金 140G − 購入 140G = 残金 0G" and not node("ShopComparisonBuy").disabled,"exact funds permit purchase with zero remainder")
 seed.state.gold=1000;await game.update({"op":"campaign_load","data":seed});await enter_facility("shop")
 shop.open_comparison("guard-shield-wood");await quote_ready()
 check(node("ShopComparisonPayment").text=="所持金 1000G − 購入 0G = 残金 1000G","zero-cost equipment retains explicit equation")
 await capture("trade-zero-cost")
 game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
 var failed=checks.filter(func(c):return not c.passed);print("TRADE_FEEDBACK_261111 "+str(checks.size()-failed.size())+"/"+str(checks.size()));quit(1 if failed.size() else 0)
