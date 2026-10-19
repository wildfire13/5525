extends RefCounted
## Presentation of existing Campaign.view fields. Mutations stay in the bridge.
var ui
var party_uid := ""
var gear_id := ""
var epoch := 0
var quote_generation := 0
var quote_pending := false
var quote_stamp := ""
var trial_return: Dictionary={}
var cached_quotes: Dictionary={}
var party_focus_after := ""
var shop_view
var party_view
var guild_view
var hub_view
var item_stage := "entry"
var item_id := ""
const ItemMenu=preload("res://item_menu.gd")
func _init(frontend):
	hub_view=preload("res://town_hub.gd").new(frontend)
	ui=frontend;shop_view=preload("res://shop_view.gd").new(self);party_view=preload("res://party_view.gd").new(self);guild_view=preload("res://guild_view.gd").new(self)
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func row(parent):return ui.row(parent)
func card(parent):return ui.card(parent)
func c() -> Dictionary:return ui.campaign()
func roster() -> Array:return ui.roster()
func town(id) -> String:return ui.town_name(id)
func muted(parent,text):
	var label=l(parent,text);label.add_theme_color_override("font_color",Color("#bcc9d3"));return label
func selected_party() -> Array:
	var journey=c().get("journey")
	if journey is Dictionary and journey.get("party") is Array:return journey.party
	return roster().filter(func(u):return c().get("selected",[]).has(u.id))
func party_status(parent):
	for u in selected_party():
		var line=l(parent,"%s［%s］ HP %d/%d / MP %d/%d%s" % [u.name,u.get("role",""),u.hp,u.max,u.mp,u.maxMp," 戦闘不能" if u.hp<=0 else ""])
		ui.emphasize_low_hp(line,u)
# Display normal attack power before formation, skills and target defense.
# Match the battle rule: only reaching weapons, with growth added once.
func normal_reach(stats: Dictionary) -> int:
	return int(stats.get("normalReach",stats.get("reach",0)))
func normal_atk(stats: Dictionary,distance: int) -> int:
	if not stats.has("attackWeapons"):
		return int(stats.get("atk",0)) if distance<=normal_reach(stats) else 0
	var power=0;var reaches=false
	for weapon in stats.attackWeapons:
		if distance<=int(weapon.reach):power+=int(weapon.atk);reaches=true
	return power+int(stats.get("attackBonus",0)) if reaches else 0
func attack_profile(stats: Dictionary) -> String:
	var parts=[]
	for distance in range(1,normal_reach(stats)+1):
		parts.append("距離%d: %d" % [distance,normal_atk(stats,distance)])
	return "通常ATK "+(" / ".join(parts) if not parts.is_empty() else "なし")+" / 最大通常射程 %d" % normal_reach(stats)
func stats_text(stats: Dictionary) -> String:
	return "HP上限 %d / MP上限 %d / %s / DEF %d / 行動速度 %d" % [stats.get("max",0),stats.get("maxMp",0),attack_profile(stats),stats.get("def",0),stats.get("speed",stats.get("agi",0))]
func member_stats(u: Dictionary) -> String:
	var s=u.get("stats",u)
	return "STR %d / INT %d / AGI %d\n%s" % [s.get("str",0),s.get("int",0),s.get("agi",0),attack_profile(s)]
func equipment(parent,u):
	for e in u.get("equipmentSlots",[]):l(parent,e.label+": "+str(e.name).trim_prefix(e.label+":").trim_prefix(e.label+"：").strip_edges())
	l(parent,"使用可能: "+" / ".join(u.get("activeSkillNames",[])))
	l(parent,"装飾: "+" / ".join(u.get("accessoryNames",[])))
	l(parent,"効果: "+" / ".join(u.get("effectNames",[])))
func quest_info(parent,q: Dictionary):
	l(parent,"行先 %s / 依頼主 %s" % [town(q.to),q.get("client","")])
	l(parent,q.get("text",""))
	l(parent,"荷物 %s / %d枠 / 納期 %d時間 / 報酬 %dG" % [q.get("cargo",""),q.get("weight",0),q.get("deadline",0),q.get("reward",0)])
func hub(parent):hub_view.render(parent)
func board(parent):
	var town_data={}
	for t in c().get("locations",[]):
		if t.id==c().location:town_data=t
	ui.icons.line(ui,parent,ui.icons.place(str(c().location)),"掲示板",true)
	muted(parent,town_data.get("description",town_data.get("text","掲示板で依頼を選ぶか、依頼を受けずに次の拠点へ移動できます。")))
	l(parent,"同時に受ける依頼は一件")
	var quest=c().get("activeQuest")
	if quest is Dictionary:
		var box=card(parent);l(box,"受注中: "+quest.name,true);quest_info(box,quest)
		if c().location==quest.to:
			var missing=not c().get("cargoAboard",false)
			if missing:l(box,"同行ポーターがこの依頼の荷物を持っていません。依頼は未完了です。")
			b(box,"拠点で荷物を届ける",ui.navigate.bind("hub"))
		b(box,"地図で出発を準備",ui.navigate.bind("map"))
	else:
		muted(parent,"依頼文・期限・報酬は、繰り返し試遊のための仮設定です。")
		if c().get("board",[]).is_empty():l(parent,"いま受注できる依頼はありません。地図から自由移動できます。")
		for q in c().get("board",[]):
			var box=card(parent);l(box,q.name,true);quest_info(box,q)
			b(box,"この依頼を引き受ける",accept.bind(q.id),not c().get("hasPorter",false))
		b(parent,"地図・出発 / 自由移動",ui.navigate.bind("map"))
	if not c().get("hasPorter",false):l(parent,"クエスト受注には最低1人のポーターが必要です。ギルドで編成してください。自由移動は可能です。")

func accept(id: String):
	if ui.locked or ui.modal_open():return
	var token=c().get("inventoryToken");var epoch=ui.pages.epoch
	ui.dialog.open("荷物を持つポーターを選択",func(body,actions):
		l(body,"この依頼の「荷物」を受け取るポーターを選んでください。")
		for member in roster():
			if c().selected.has(member.id) and member.job=="porter":
				b(body,member.name,accept_with_owner.bind(id,member.id,token,epoch)).name="QuestCargoOwner_"+member.id
		b(actions,"キャンセル",ui.dialog.close).name="QuestCargoCancel")
func accept_with_owner(id: String,owner_id: String,token,epoch):
	if ui.locked or epoch!=ui.pages.epoch or token!=c().get("inventoryToken"):return
	ui.dialog.close(false)
	await ui.act("accept",[id,owner_id])
	if c().get("activeQuest") is Dictionary:ui.destination=c().activeQuest.to;ui.navigate("map")
func select_destination(id: String):
	ui.destination=id;ui.render()
func map(parent):
	l(parent,"次の行先を選ぶ",true)
	var available=[]
	for place in c().get("destinations",[]):available.append(place.id if place is Dictionary else place)
	var quest=c().get("activeQuest")
	if quest is Dictionary:
		l(parent,"受注中: %s → %s" % [quest.name,town(quest.to)])
	if not available.has(ui.destination):ui.destination=str(available[0]) if not available.is_empty() else ""
	muted(parent,"接続・距離・方角は試作用の模式図です。各移動は二つの区間を通ります。")
	shop_guide(parent)
	var chart=preload("res://town_map.gd").new();chart.name="TownMap"
	chart.towns=c().get("locations",[]);chart.current=c().location;chart.selected=ui.destination;chart.available=available;chart.routes=c().get("routes",{});chart.icons=ui.icons
	chart.quest_destination=str(quest.to) if quest is Dictionary else ""
	parent.add_child(chart);chart.destination_selected.connect(select_destination)
	for id in chart.buttons:ui.widgets.append(chart.buttons[id])
	muted(parent,"未受注での移動も戦闘・消耗があります。配達報酬はありません。追加の移動料金はありません。")
	var depart=b(parent,town(ui.destination)+"へ出発" if not ui.destination.is_empty() else "行先がありません",ui.act.bind("depart",[ui.destination,"convoy"]),ui.destination.is_empty());depart.name="DepartButton"
	depart.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;depart.custom_minimum_size=Vector2(280,44)
	for state_ in ["normal","hover","pressed"]:
		var style=depart.get_theme_stylebox(state_).duplicate();style.bg_color=Color("#2f7652") if state_=="hover" else Color("#236044");depart.add_theme_stylebox_override(state_,style)
func choose_formation(value: String):ui.formation=value;ui.render()
func shop_guide(parent):
	var facilities=row(parent)
	for item in [["weapon_shop","武器店"],["armor_shop","防具店"],["item_shop","道具店"],["accessory_shop","装飾品店"]]:ui.icons.line(ui,facilities,item[0],item[1])
func journey(parent):
	var phase=c().get("phase","");var journey_: Dictionary=c().get("journey") if c().get("journey") is Dictionary else {}
	if phase=="result":result(parent);return
	if phase=="prepare":map(parent);return
	l(parent,town(journey_.get("destination",c().get("destination","")))+"への旅",true)
	l(parent,"旅のBGM: "+ui.audio.quest_title())
	var quest=c().get("activeQuest")
	if quest is Dictionary:
		l(parent,"%s / %d時間経過・納期%d時間" % [quest.name,journey_.get("hours",0),quest.get("deadline",0)])
	else:l(parent,"自由移動 / %d時間経過 / 配達報酬なし" % journey_.get("hours",0))
	match phase:
		"road":
			var stage=int(journey_.get("stage",0))
			l(parent,"第%d区間: 進む道を選ぶ" % (stage+1),true)
			b(parent,"峠の近道: 2時間 / 敵%d人" % (3 if stage==0 else 4),ui.forecast_action.bind("short","travel",["short"]))
			b(parent,"川沿いの道: 4時間 / 敵%d人" % (2 if stage==0 else 3),ui.forecast_action.bind("safe","travel",["safe"]))
		"camp":
			l(parent,"街道の野営地 / あと一区間",true)
			var actions=row(parent);actions.name="CampActions"
			var rest=b(actions,"2時間休む: HP+60 / MP+2",ui.forecast_action.bind("rest","rest",[]),journey_.get("rested",false))
			rest.custom_minimum_size.x=rest.get_combined_minimum_size().x
			if journey_.get("rested",false):rest.text="休息済み"
			b(actions,"次の区間へ",ui.act.bind("onward",[]));items(parent)
		"arrival","delivery":
			l(parent,town(journey_.get("destination",""))+"に到着しました",true)
			b(parent,"町へ入る（依頼は未完了）" if quest is Dictionary else "町へ入る（配達報酬なし）",ui.act.bind("arrive",[]))
	l(parent,"\n".join(journey_.get("history",[]).slice(-4)))
func party(parent):party_view.render(parent)
func reset_items():item_stage="entry";item_id=""
func show_items(stage: String,id: String=""):
	if ui.locked or ui.presenting or ui.closing:return
	var previous=item_id;item_stage=stage;item_id=id
	if stage=="entry":ui.memory.request_focus("campaign_item_entry",true)
	elif stage=="list":ui.memory.request_focus("campaign_item_"+(previous if not previous.is_empty() else "potion"),true)
	else:
		for item in ItemMenu.definitions(c()):
			if item.id!=id:continue
			for u in roster():
				if c().selected.has(u.id) and ItemMenu.camp_reason(item,u,c().inventory).is_empty():
					ui.memory.request_focus("item_target_"+str(u.id),true);break
	ui.render()
func close_items() -> bool:
	if c().get("phase") not in ["town","camp"] or item_stage=="entry":return false
	show_items("list" if item_stage=="target" else "entry");return true
func use_selected_item(uid: String):
	if item_stage!="target" or item_id.is_empty():return
	await ui.act("useItem",[item_id,uid])
func items(parent):
	if c().phase not in ["town","camp"]:l(parent,"町・野営で使用できます");return
	if c().has("inventoryByCharacter"):
		l(parent,"インベントリ / 所持者を選択",true)
		var members=row(parent);members.name="CampParty" if c().phase=="camp" else "ItemParty"
		for uid in c().get("selected",[]):
			var u=roster().filter(func(member):return member.id==uid)[0]
			var member=card(members);member.name="ItemMember_"+str(uid);member.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var portrait=ui.portrait(member,u,false,64);portrait.name="FullBodyPortrait";portrait.custom_minimum_size=Vector2(64,160 if ui.ui_size_mode=="standard" else 96);portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var name_label=l(member,u.name);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ui.short_name(name_label,str(u.name))
			var hp=ui.icons.line(ui,member,"hp","HP %d/%d" % [u.hp,u.max]);ui.emphasize_low_hp(hp,u)
			ui.icons.line(ui,member,"mp","MP %d/%d" % [u.mp,u.maxMp])
			if u.hp<=0:l(member,"戦闘不能")
			b(member,"インベントリ",party_view.open_inventory.bind(str(uid))).name="InventoryOwner_"+str(uid)
		return
	var catalog=ItemMenu.definitions(c());var inventory: Dictionary=c().inventory
	var selected_item={}
	for item in catalog:
		if item.id==item_id:selected_item=item
	if item_stage=="target" and selected_item.is_empty():reset_items()
	var controls=card(parent);controls.name="CampaignItems"
	if item_stage=="entry":
		var entry=ui.icons.apply(b(controls,"アイテム",show_items.bind("list")),"items");entry.name="CampaignItemEntry";ui.memory.key(entry,"campaign_item_entry")
	elif item_stage=="list":
		l(controls,"アイテム / 種類を選択",true)
		var choices=row(controls);choices.name="CampaignItemList"
		for item in catalog:
			ui.memory.key(ui.icons.apply(b(choices,"%s %s / %d個" % [item.name,ItemMenu.effect(item),inventory.get(item.id,0)],show_items.bind("target",item.id),int(inventory.get(item.id,0))<=0),str(item.id)),"campaign_item_"+str(item.id))
		b(controls,"戻る",show_items.bind("entry"))
	else:
		ui.icons.line(ui,controls,str(selected_item.id),"%s / 対象を選択" % selected_item.name,true)
		l(controls,"%s / 残り%d個。生存している編成中の仲間に使用します。" % [ItemMenu.effect(selected_item),inventory.get(item_id,0)])
		b(controls,"アイテム一覧へ",show_items.bind("list"))
	var members=row(parent);members.name="CampParty" if c().phase=="camp" else "ItemParty"
	for u in roster():
		if not c().selected.has(u.id):continue
		var member=card(members);member.name="ItemMember_"+str(u.id);member.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var portrait=ui.portrait(member,u,false,64);portrait.name="FullBodyPortrait";portrait.custom_minimum_size=Vector2(64,160 if ui.ui_size_mode=="standard" else 96);portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var name_label=l(member,u.name);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ui.short_name(name_label,str(u.name))
		var hp=ui.icons.line(ui,member,"hp","HP %d/%d" % [u.hp,u.max]);ui.emphasize_low_hp(hp,u)
		ui.icons.line(ui,member,"mp","MP %d/%d" % [u.mp,u.maxMp])
		if u.hp<=0:l(member,"戦闘不能")
		if item_stage=="target":
			var reason=ItemMenu.camp_reason(selected_item,u,inventory)
			var target=b(member,"使う" if reason.is_empty() else reason,use_selected_item.bind(u.id),not reason.is_empty());target.name="ItemTarget_"+str(u.id);ui.memory.key(target,"item_target_"+str(u.id))
func inn(parent):
	var q: Dictionary=c().get("inn",{})
	ui.icons.line(ui,parent,"inn","宿屋",true)
	if not q.get("available",false):l(parent,"宿屋はアスタリスで利用できます。");return
	l(parent,"パーティ全員で%dG（仮料金）" % q.price)
	l(parent,"編成中の全員のHP・MPを上限まで回復します。戦闘不能の仲間も回復します。")
	muted(parent,"控えの仲間は対象外。時間は経過しません（試作仕様）。");inn_cards(parent)
	if not q.get("needsRecovery",false):l(parent,"全員が全回復しています。料金はかかりません。")
	elif not q.get("affordable",false):l(parent,"所持金が足りません。宿泊には%dG必要です。" % q.price)
	var actions=row(parent);actions.alignment=BoxContainer.ALIGNMENT_CENTER
	ui.green_button(b(actions,"%dGで宿泊する / 確認" % q.price,stay_inn,not q.get("needsRecovery",false) or not q.get("affordable",false))).name="InnStay"
func inn_cards(parent):
	var scroll=ScrollContainer.new();scroll.name="InnPartyScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(scroll)
	var members=row(scroll);members.name="InnParty";members.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for id in c().get("selected",[]):
		var matches=roster().filter(func(u):return u.id==id)
		if matches.is_empty():continue
		var u=matches[0];var member=card(members);member.name="InnMember_"+str(id)
		member.get_parent().custom_minimum_size.x=180;member.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var face=ui.portrait(member,u,false,64);face.name="InnPortrait_"+str(id);face.custom_minimum_size.y=160;face.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var name_label=l(member,u.name);name_label.name="InnName_"+str(id);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ui.short_name(name_label,str(u.name))
		var hp=ui.icons.line(ui,member,"hp","HP %d/%d" % [u.hp,u.max]);hp.name="InnHP_"+str(id);ui.emphasize_low_hp(hp,u)
		ui.icons.line(ui,member,"mp","MP %d/%d" % [u.mp,u.maxMp]).name="InnMP_"+str(id)
		if u.hp<=0:l(member,"戦闘不能")
func stay_inn():
	var q=c().get("inn",{})
	ui.confirm("%dGを支払い、編成中の全員のHP・MPを全回復しますか？\n戦闘不能も回復。控えは対象外、時間は経過しません。" % q.get("price",30),ui.act.bind("inn",[]))
func shop(parent):
	var location=c().get("location","")
	if location not in ["east","west","north"]:l(parent,{"south":"道具店"}.get(location,"この拠点にお店はありません"),true)
	if location=="south":
		var body=ui.scroller(parent);ui.memory.watch(body.get_parent(),"consumable_shop")
		if not c().get("selected",[]).has(ui.shop_uid):ui.shop_uid=str(c().selected[0])
		var receiving=row(body);l(receiving,"購入品の受取人")
		var recipient=OptionButton.new();recipient.name="ConsumableRecipient";recipient.custom_minimum_size=Vector2(180,44);receiving.add_child(recipient)
		for uid in c().get("selected",[]):
			recipient.add_item(ui.member_name(str(uid)));recipient.set_item_metadata(recipient.item_count-1,uid)
			if uid==ui.shop_uid:recipient.select(recipient.item_count-1)
		recipient.item_selected.connect(func(i):ui.shop_uid=str(recipient.get_item_metadata(i));ui.render())
		muted(body,"購入品は選んだ受取人のインベントリへ入ります。消耗品の合計上限は各99個。回復量はHP+55 / MP+3です。")
		shop_view.product_filter(body)
		for item in shop_view.offered():
			var count=c().characters[ui.shop_uid].get("inventory",{}).get(item.id,0);var actions=row(card(body))
			ui.icons.line(ui,actions,str(item.id),"%s %dG / %sの所持%d個" % [item.name,item.price,ui.member_name(ui.shop_uid),count])
			for amount in [1,5]:b(actions,"%d個購入" % amount,ui.act.bind("buyItem",[item.id,amount,ui.shop_uid,c().get("inventoryToken")]),c().gold<item.price*amount or c().get("inventoryTotals",{}).get(item.id,0)+amount>99)
		items(body);return
	if location not in ["east","west","north"]:
		shop_guide(parent);return
	shop_view.render(parent)
func select_slot(slot: String):await shop_view.select_slot(slot)
func purchase(_q: Dictionary):shop_view.confirm_purchase()
func buy(id: String):
	await shop_view.confirm_purchase(id)
func cancel_quote():shop_view.back_list()
func result(parent):
	var result_: Dictionary=c().get("result",{});var outcome=result_.get("outcome","")
	l(parent,{"success":"配達完了！","late":"配達完了！ / 遅配","failed":"クエスト失敗 / 出発前へ","travel":"目的地に到着"}.get(outcome,"旅の結果"),true)
	if outcome=="failed":
		l(parent,result_.get("reason","護送隊が敗北しました"))
		l(parent,"受注直前の状態へ戻しました。自由移動の場合は出発直前へ戻ります。")
		muted(parent,"所持金・装備・編成・HP/MP・道具・経験値・経過時間を復元しています。")
	elif outcome=="travel":l(parent,"依頼を受けずに移動しました。配達報酬はありません。戦闘の経験値は保持されます。")
	else:l(parent,"荷物を届けました。報酬と成長を持ち越して、次の依頼や買い物へ進めます。")
	ui.icons.line(ui,parent,"money","今回の配達報酬 %dG" % result_.get("gold",0),true)
	ui.icons.line(ui,parent,"experience","各同行者の配達経験値 %d" % result_.get("xp",0))
	ui.icons.line(ui,parent,"money","所持金 %dG" % c().gold)
	if result_.get("hours")!=null:l(parent,"所要時間 %d時間" % result_.hours)
	l(parent,"現在地: "+town(c().location)+"。ここで施設を利用し、次の出発を選べます。")

func acknowledge(page: String):ui.page=page;await ui.act("acknowledge",[])

func select_party(id: String):
	if not ui.can_inspect_member(id):return
	if id!=party_uid and not party_view.guard_leave(select_party.bind(id)):return
	party_uid=id;ui.memory.request_focus("party_"+id);ui.render()
func change_membership(id: String):
	if not c().get("guildAvailable",false):return
	party_uid=id
	await ui.toggle_member(id)
	ui.memory.request_focus("party_"+id,true);ui.memory.restore()
func offered() -> Array:
	return shop_view.offered()
func selection_key(id: String) -> String:
	var character=c().get("characters",{}).get(ui.shop_uid,{}).duplicate(true)
	for key in ["inventory","hp","mp"]:character.erase(key)
	return JSON.stringify([epoch,ui.engine.connection_generation,c().get("location"),ui.shop_uid,ui.shop_slot,id,c().get("gold"),character,c().get("selected")])
func quote_valid() -> bool:
	return not quote_pending and not ui.gear_preview.is_empty() and quote_stamp==selection_key(gear_id)
func invalidate_quote(clear_id:=false):
	quote_generation+=1;quote_pending=false;quote_stamp="";ui.gear_preview={}
	if clear_id:gear_id=""
func reset_context(plan_mode: String="discard",campaign_id: String=""):
	hub_view.reset()
	if ui.hud!=null:ui.hud.reset_context()
	reset_items();shop_view.reset(plan_mode,campaign_id);guild_view.reset();party_view.reset();party_view.tab=0;party_view.highlight_slot=""
	epoch+=1;invalidate_quote(true);trial_return={};cached_quotes={}
func request_quote(id: String):await shop_view.select_product(id)
func select_member(uid: String):await shop_view.select_member(uid)
func remember_trial(args: Array):
	shop_view.stage="S8";shop_view.background.clear()
	ui.memory.capture()
	trial_return={"epoch":epoch,"location":c().get("location"),"uid":args[0],"gear":args[1],"slot":args[2],"filter":shop_view.filter_slot,"scrolls":ui.memory.scrolls.duplicate(true),"focus":"product_"+str(args[1])}
func start_trial():await shop_view.start_trial()
func restore_trial():
	if trial_return.is_empty() or trial_return.get("epoch")!=epoch:return
	var previous=trial_return.duplicate(true);trial_return={}
	if c().get("location")!=previous.location:ui.notice="試用前の店が変わったため選択を解除しました";invalidate_quote(true);return
	ui.page="shop";ui.shop_uid=previous.uid;ui.shop_slot=previous.slot;shop_view.filter_slot=previous.get("filter","all")
	if not c().get("selected",[]).has(ui.shop_uid) or not offered().any(func(g):return g.id==previous.gear):
		invalidate_quote(true);ui.notice="試用前の人物・商品を確認できないため選択を解除しました";ui.render();return
	ui.memory.scrolls.merge(previous.scrolls,true)
	shop_view.back_list()
	ui.memory.scrolls.merge(previous.scrolls,true);ui.memory.request_focus(previous.focus);ui.memory.restore()

func gear_type(gear: Dictionary) -> String:
	if gear.get("type")=="empty" and gear.get("slot") not in ["weapon","rightHand","leftHand"]:return "なし"
	return {"empty":"なし（手占有0）","sword":"片手剣","greatsword":"両手剣","spear":"槍","dagger":"短剣","bow":"弓","staff":"杖","hammer":"槌","shield":"盾","book":"魔導書","armor":"防具","accessory":"装飾","boots":"足装備"}.get(gear.get("type",""),str(c().get("slots",{}).get(gear.get("slot",""),"装備")))
func describe_gear(parent,gear: Dictionary):
	ui.icons.line(ui,parent,ui.icons.equipment(gear),str(gear.get("name","装備")),true)
	l(parent,gear_type(gear)+" / "+("両手・2枠" if gear.get("hands",1)==2 else "手占有0" if gear.get("type")=="empty" and gear.get("slot") in ["weapon","rightHand","leftHand"] else "片手・1枠" if gear.get("slot") in ["weapon","rightHand","leftHand"] else str(c().get("slots",{}).get(gear.get("slot",""),"装備"))))
	var fields={"price":"購入価格G","atk":"武器ATK","reach":"武器射程","hp":"追加HP上限","mp":"追加MP上限","agiBonus":"行動速度補正","str":"必要STR","int":"必要INT","agi":"必要AGI"}
	for field in fields:
		if gear.has(field):l(parent,fields[field]+": "+str(int(gear[field])))
	if gear.has("allowedSlots"):l(parent,"装備枠: "+" / ".join(gear.allowedSlots.map(func(slot):return str(c().get("slots",{}).get(slot,slot)))))
	for field in ["skill","effect"]:
		if gear.get(field)!=null:
			ui.icons.line(ui,parent,ui.icons.skill(str(gear[field])),("スキル: " if field=="skill" else "効果: ")+str(c().get("skillNames",{}).get(gear[field],gear[field])))
			l(parent,skill_description(str(gear[field]),int(gear.get("skillLevel",1))))
	if gear.has("note"):l(parent,gear.note)

func skill_description(id: String,stage: int=1) -> String:
	if id=="itemUse":return "アイテム使用Lv%d：%s。本人の所持品1個・MP0・1行動。" % [stage,["自分のみ","自分と縦横隣接の味方","距離制限なしの味方"][clampi(stage-1,0,2)]]
	if id=="legSweep":return "足払いLv%d：周囲8マスの敵にそれぞれ%d%%で次の1手番をスキップ（重複なし）。ダメージ0・MP1。" % [stage,[50,75,100][clampi(stage-1,0,2)]]
	var definition=c().get("skillDefinitions",{}).get(id,{})
	return str(definition.description) if definition.has("description") else ui.legacy_skill_description(str(c().get("skillNames",{}).get(id,id)),stage)
