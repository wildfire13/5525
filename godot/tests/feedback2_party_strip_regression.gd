extends SceneTree
## Synthetic twelfth card is a UI boundary only; the shipped roster stays eleven.
var game
var checks=[]
var evidence=OS.get_environment("INVENTORY_QA_ROOT")
func _initialize():call_deferred("run")
func check(ok,label):checks.append({"passed":bool(ok),"label":label});print(("PASS " if ok else "FAIL ")+label)
func frames(n:=5):
	for i in range(n):await process_frame
func settle():
	await frames()
	while game.locked or game.presenting or game.engine.busy or game.pages.shop_view.sale.previewing:await process_frame
	await frames()
func node(name_):return game.find_child(name_,true,false)
func saved():return (await game.engine.request({"op":"campaign_save"})).data
func run():
	create_timer(120).timeout.connect(func():print("FAIL strip watchdog");quit(2))
	root.size=Vector2i(1920,1080);game=load("res://main.tscn").instantiate();root.add_child(game)
	while game.data.is_empty():await process_frame
	game.checks_fast=true;game.audio.fast_mode=true;await settle()
	var ids=game.roster().map(func(m):return str(m.id));check(ids.size()==11,"eleven real people, no invented twelfth character")
	await game.act("select",[ids]);await settle()
	var before=await saved()
	for dims in [Vector2i(1920,1080),Vector2i(1180,812),Vector2i(960,540),Vector2i(1920,1080)]:
		root.size=dims;await frames(8);game.render();await settle()
		var bar=node("PartyFaceBar");var scroll=node("PartyFacesScroll")
		check(node("PartyFaces").get_child_count()==11,"all eleven short cards at "+str(dims))
		check(bar.get_global_rect().end.x<=game.size.x+1 and bar.get_global_rect().end.y<=game.size.y+1,"strip contained at "+str(dims))
		check(node("PartySlideLeft")!=null and node("PartySlideRight")!=null,"both slide buttons exist "+str(dims))
		if dims.x==960:
			check(scroll.get_h_scroll_bar().max_value>scroll.size.x,"real eleven cards overflow narrow strip")
			bar.slide(1);await frames();check(scroll.scroll_horizontal>0,"right arrow scrolls real roster")
			var offset=scroll.scroll_horizontal;game.render();await settle();check(node("PartyFacesScroll").scroll_horizontal==offset,"rerender restores horizontal context")
			node("PartyFace_"+ids[-1]).grab_focus();await frames();var face=node("PartyFace_"+ids[-1]);check(node("PartyFacesScroll").get_global_rect().intersects(face.get_global_rect()),"keyboard focus reaches last card")
		check(await saved()==before,"scroll and layout preserve exact save "+str(dims))
	# Simulated touch positions are local to a card that moves while scrolling.
	root.size=Vector2i(960,540);await frames();var touch_scroll=node("PartyFacesScroll");touch_scroll.scroll_horizontal=0;await frames()
	var touch_card=node("PartyFace_guard");var origin=touch_scroll.get_global_rect().get_center()
	var touch=InputEventScreenTouch.new();touch.pressed=true;touch.position=touch_card.get_global_transform_with_canvas().affine_inverse()*origin;touch_card._gui_input(touch)
	var motion=InputEventScreenDrag.new();motion.position=touch_card.get_global_transform_with_canvas().affine_inverse()*(origin-Vector2(100,0));touch_card._gui_input(motion);await frames()
	check(touch_scroll.scroll_horizontal==100,"first simulated touch step follows global pointer")
	motion=InputEventScreenDrag.new();motion.position=touch_card.get_global_transform_with_canvas().affine_inverse()*(origin-Vector2(150,0));touch_card._gui_input(motion);await frames()
	check(touch_scroll.scroll_horizontal==150,"second touch step stays monotonic after card itself moves")
	touch.pressed=false;touch_card._gui_input(touch)
	check(game.pages.party_view.detail_uid.is_empty() and await saved()==before,"simulated touch swipe does not activate person or mutate save")
	root.size=Vector2i(960,540);await frames();var synthetic=game.campaign().roster[0].duplicate(true);synthetic.id="qa-ui-twelfth";synthetic.name="表示境界12"
	game.data.campaign.roster.append(synthetic);game.data.campaign.selected.append(synthetic.id);game.render();await settle()
	check(node("PartyFaces").get_child_count()==12,"explicit synthetic twelfth UI card")
	node("PartyFace_qa-ui-twelfth").grab_focus();await frames();check(node("PartyFacesScroll").get_global_rect().intersects(node("PartyFace_qa-ui-twelfth").get_global_rect()),"synthetic twelfth reachable")
	check(await saved()==before,"synthetic UI boundary never alters backend")
	var east=before.duplicate(true);east.state.location="east";east.state.characters.guard.inventory["spear-wood"]=3
	game.save_notice.display("前のプロフィールの取引")
	await game.update({"op":"campaign_load","data":east});check(not game.save_notice.visible and game.save_notice.caption.text.is_empty(),"load clears previous campaign toast");game.navigate("shop");await settle()
	check(node("FacilityEntry")!=null,"ordinary facility entry precedes sale")
	node("FacilityChoice_sell").pressed.emit();await settle()
	var sale_before=await saved();node("PartyFace_guard").pressed.emit();await settle()
	check(node("FacilitySaleOwner").text.contains("ガロ") and game.pages.party_view.detail_uid.is_empty(),"first click selects sale owner in place")
	var card=node("PartyFace_guard");check(card.get_theme_stylebox("normal").bg_color.b>card.get_theme_stylebox("normal").bg_color.r,"sale owner card is blue")
	node("PartyFace_guard").pressed.emit();await settle();check(game.pages.party_view.detail_uid=="guard" and is_instance_valid(game.dialog.window),"same owner second click opens details")
	var other=node("PartyFace_archer");node("PartyFacesScroll").ensure_control_visible(other);await frames()
	check(not game.pages.party_view.outside_press(other.get_global_rect().get_center()),"mousedown on strip defers owner action until release")
	other.pressed.emit();await settle();check(game.pages.party_view.detail_uid=="archer","released card switches detail owner")
	game.dialog.close();await settle();check(game.pages.shop_view.selected_owner()=="archer" and game.pages.shop_view.sale.item_id.is_empty() and game.pages.shop_view.sale.quote.is_empty(),"closing changed detail preserves latest sale owner and clears old item/quote")
	node("PartyFace_guard").pressed.emit();await settle();check(game.pages.shop_view.selected_owner()=="guard" and game.pages.party_view.detail_uid.is_empty(),"different first click changes sale owner without opening window")
	check(await saved()==sale_before,"owner and detail operations do not consume or sell")
	game.pages.facility_entry.back();await settle();check(node("FacilityEntry")!=null,"sale returns to cushion page")
	game.pages.facility_entry.back();await settle();check(game.page=="hub","entry returns to plaza")
	# Old saves can deploy an incapacitated warrior: there must be a visible way
	# to free that occupied slot without resurrecting or changing that character.
	var wounded=before.duplicate(true);wounded.state.characters.guard.hp=0
	await game.update({"op":"campaign_load","data":wounded});await game.act("depart",["east"]);await game.act("travel",["safe"]);await settle()
	var removal=node("DeploymentRemoveInactive_guard")
	check(removal!=null and not removal.disabled,"incapacitated deployed warrior has a removal affordance")
	var pre_remove=await saved();removal.pressed.emit();await settle();var post_remove=await saved()
	check(not game.campaign().deploymentRoster.deployed.has("guard"),"inactive removal frees one deployment slot")
	check(post_remove.state.characters==pre_remove.state.characters,"inactive removal changes no HP equipment inventory or progression")
	check(preload("res://deployment_drag.gd").make_payload(game,"guard","party")==null,"dead reserve cannot be dragged into battle")
	await game.deployment_assigned("guard-2",24);await settle()
	check(game.campaign().deploymentRoster.deployed.has("guard-2") and game.campaign().deploymentRoster.canBegin,"living reserve can use the freed slot and begin")
	check(game.audio.muted.values().all(func(v):return v),"audio off")
	var f=FileAccess.open(evidence.path_join("party-strip-checks.json"),FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free();await frames()
	print("Party strip "+str(checks.filter(func(c):return c.passed).size())+"/"+str(checks.size()));quit(0 if checks.all(func(c):return c.passed) else 1)
