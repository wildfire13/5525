extends RefCounted
const ElementBadges=preload("res://element_badges.gd")
## Presentation of existing Campaign.view fields. Mutations stay in the bridge.
var ui
var party_uid := ""
var gear_id := ""
var epoch := 0
var quote_generation := 0
var travel_map_expanded := false
var quote_pending := false
var quote_stamp := ""
var trial_return: Dictionary={}
var cached_quotes: Dictionary={}
var party_focus_after := ""
var shop_view
var facility_entry
var party_view
var guild_view
var warehouse_view
var hub_view
var quest_board
var inn_view
var facility_art=preload("res://facility_art.gd").new()
var item_stage := "entry"
var item_id := ""
const ItemMenu=preload("res://item_menu.gd")
func _init(frontend):
	ui=frontend
	quest_board=preload("res://quest_board.gd").new(self)
	inn_view=preload("res://inn_view.gd").new(self)
	hub_view=preload("res://town_hub.gd").new(frontend)
	ui=frontend;shop_view=preload("res://shop_view.gd").new(self);party_view=preload("res://party_view.gd").new(self);guild_view=preload("res://guild_view.gd").new(self);facility_entry=preload("res://facility_entry.gd").new(self)
	warehouse_view=preload("res://warehouse_view.gd").new(self)
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
	return "通常ATK（物理） "+(" / ".join(parts) if not parts.is_empty() else "なし")+" / 属性ATK 火%d 水%d 地%d / 最大射程 %d" % [stats.get("atkFire",0),stats.get("atkWater",0),stats.get("atkEarth",0),normal_reach(stats)]
func defense_profile(stats: Dictionary) -> String:
	return "DEF 物%d 火%d 水%d 地%d" % [stats.get("def",0),stats.get("defFire",0),stats.get("defWater",0),stats.get("defEarth",0)]
func element_name(element) -> String:
	return {"fire":"火","water":"水","earth":"地","none":"無属性"}.get(str(element),"無属性")
func elemental_combat_line(parent,stats: Dictionary):
	var detail=row(parent);detail.name="ElementalCombatProfile"
	var explanation="各属性攻撃は対応する属性DEFを引いてから相性を適用。火＞地＞水＞火。相性有利×1.25、不利×0.75。同属性・無属性・物理は等倍。"
	var title=l(detail,"属性 ATK/DEF",false);title.tooltip_text=explanation
	for element in ["fire","water","earth"]:
		ElementBadges.add(detail,element,24)
		var values=l(detail,"%d / %d" % [stats.get("atk"+element.capitalize(),0),stats.get("def"+element.capitalize(),0)])
		values.tooltip_text=explanation
	detail.tooltip_text=explanation
func elemental_badge(parent,element: String,pixels:=24):
	if element in ["fire","water","earth"]:ElementBadges.add(parent,element,pixels)
func stats_text(stats: Dictionary,character_id: String="") -> String:
	var text="HP上限 %d / MP上限 %d / %s / %s / SPD %d / 属性 %s" % [stats.get("max",0),stats.get("maxMp",0),attack_profile(stats),defense_profile(stats),stats.get("speed",stats.get("agi",0)),element_name(stats.get("element","none"))]
	if not character_id.is_empty():
		var weight=c().get("inventoryByCharacter",{}).get(character_id,{}).get("weight",{})
		if weight is Dictionary:
			var current=weight.get("total")
			text+=" / Wt %s / STR上限 %d" % [str(current) if current!=null else str(weight.get("known",0))+"（一部不明）",stats.get("str",0)]
			if current!=null and current>stats.get("str",0):text+="（超過中: SPD 50%）"
	return text
func member_stats(u: Dictionary) -> String:
	var s=u.get("stats",u)
	return "STR %d / INT %d / AGI %d\n%s / %s / 属性 %s" % [s.get("str",0),s.get("int",0),s.get("agi",0),attack_profile(s),defense_profile(s),element_name(s.get("element","none"))]
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
func board(parent):quest_board.render(parent)
func accept(id: String):quest_board.open_picker(id)
func select_destination(id: String):
	var chart=ui.find_child("TownMap",true,false)
	var view_zoom=chart.zoom if is_instance_valid(chart) else 1.0
	var view_pan=chart.pan if is_instance_valid(chart) else Vector2.ZERO
	ui.destination=id;ui.render()
	chart=ui.find_child("TownMap",true,false)
	if is_instance_valid(chart):chart.zoom=view_zoom;chart.pan=view_pan;chart.layout()
func active_quest_summary(parent):
	var quest=c().get("activeQuest")
	var line=row(parent);line.name="TravelQuestSummary"
	var copy=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(copy)
	if not quest is Dictionary:
		l(copy,"進行中のクエスト");l(copy,"なし");return
	var elapsed=int(c().get("worldTime",0))-int(quest.get("eventEpoch",quest.get("postedAt",0))) if quest.get("scenario",false) else int(quest.get("elapsedHours",0))
	if not quest.get("scenario",false) and c().get("journey") is Dictionary:elapsed+=int(c().journey.get("hours",0))
	if quest.get("meeting") is Dictionary:
		l(copy,str(quest.name)+" · 受取人: 行商人")
		l(copy,quest_board.meeting.status(quest.meeting))
		l(copy,quest_board.meeting.deadline_text(quest.meeting))
	else:
		l(copy,"進行中のクエスト · 期限まで %d時間" % maxi(0,int(quest.get("deadline",0))-elapsed))
		l(copy,str(quest.name)+" · 配達先 "+town(quest.to))
	b(line,"内容確認",ui.navigate.bind("board")).name="TravelQuestDetails"
func map(parent):
	var surface=card(parent);surface.get_parent().custom_minimum_size.y=ui.mock_shell.content_height();parent=surface
	var available=[]
	for place in c().get("destinations",[]):available.append(place.id if place is Dictionary else place)
	var quest=c().get("activeQuest")
	if not available.has(ui.destination):ui.destination=str(available[0]) if not available.is_empty() else ""
	var chart=preload("res://town_map.gd").new();chart.name="TownMap"
	chart.towns=c().get("locations",[]);chart.current=c().location;chart.selected=ui.destination;chart.available=available;chart.routes=c().get("routes",{});chart.icons=ui.icons
	chart.quest_destination=str(quest.to) if quest is Dictionary else ""
	parent.add_child(chart);chart.custom_minimum_size.y=ui.mock_shell.content_height()-228;chart.size_flags_vertical=Control.SIZE_EXPAND_FILL;chart.destination_selected.connect(select_destination)
	for id in chart.buttons:ui.widgets.append(chart.buttons[id])
	var actions=row(parent);actions.name="MapControls";actions.custom_minimum_size.y=72
	var route=VBoxContainer.new();route.custom_minimum_size.x=320;actions.add_child(route)
	l(route,town(c().location)+" → "+town(ui.destination),true)
	l(route,"最短の到着見込 6時間")
	var over=c().get("inventoryOverflow",[])
	var depart=ui.green_button(b(actions,"出発する",ui.act.bind("depart",[ui.destination,"convoy"]),ui.destination.is_empty() or not over.is_empty()));depart.name="DepartButton"
	if not over.is_empty():depart.tooltip_text="インベントリ枠を超えているメンバーがいます"
	b(actions,"都市に入る" if c().location=="astaris" else "村に入る",ui.navigate.bind("hub"))
	var space=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(space)
	b(actions,"全体表示",chart.reset_view).name="MapFit"
	parent.add_child(HSeparator.new());active_quest_summary(parent)
func choose_formation(value: String):ui.formation=value;ui.render()
func shop_guide(parent):
	var facilities=row(parent)
	for item in [["weapon_shop","武器店"],["armor_shop","防具店"],["item_shop","道具店"],["accessory_shop","装飾品店"]]:ui.icons.line(ui,facilities,item[0],item[1])
func journey(parent):
	var phase=c().get("phase","");var journey_: Dictionary=c().get("journey") if c().get("journey") is Dictionary else {}
	if phase=="result":result(parent);return
	if phase=="prepare":map(parent);return
	var strip=preload("res://travel_strip.gd").new();strip.name="TravelRouteStrip"
	strip.origin=town(journey_.get("origin",c().get("location","")))
	strip.destination=town(journey_.get("outboundDestination",journey_.get("destination","")))
	strip.returning=journey_.get("returning",false);strip.stage=int(journey_.get("stage",0));strip.phase=phase;parent.add_child(strip)
	var toggle=b(parent,"経路だけ表示" if travel_map_expanded else "ワールドマップを表示",func():travel_map_expanded=not travel_map_expanded;ui.render());toggle.name="TravelMapToggle";toggle.size_flags_horizontal=Control.SIZE_SHRINK_END
	if travel_map_expanded:
		var chart=preload("res://town_map.gd").new();chart.name="TravelFullMap";chart.read_only=true
		chart.towns=c().get("locations",[]);chart.current=str(journey_.get("origin",c().get("location","")));chart.selected=str(journey_.get("outboundDestination",journey_.get("destination","")))
		chart.available=chart.towns.map(func(place):return place.id);chart.routes=c().get("routes",{});chart.icons=ui.icons
		var quest=c().get("activeQuest");chart.quest_destination=str(quest.to) if quest is Dictionary else ""
		parent.add_child(chart);chart.custom_minimum_size.y=300;chart.size_flags_vertical=Control.SIZE_FILL
	var actions=row(parent);actions.name="CampActions";actions.custom_minimum_size.y=72
	var copy=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(copy)
	l(copy,"帰路" if strip.returning else "野営地" if phase=="camp" else "到着" if phase in ["arrival","delivery"] else "%d区間目の道" % (int(journey_.get("stage",0))+1),true)
	var remaining=maxi(0,2-int(journey_.get("stage",0)))*3
	if phase=="arrival" or phase=="delivery":remaining=0
	l(copy,"最短の到着見込 %d時間" % (int(journey_.get("hours",0))+remaining))
	match phase:
		"camp":
			ui.green_button(b(actions,"次の区間へ",ui.act.bind("onward",[])))
			var rest=b(actions,"休息済み" if journey_.get("rested",false) else "休息する",ui.forecast_action.bind("rest","rest",[]),journey_.get("rested",false));rest.tooltip_text="2時間 · HP +60 / MP +2"
			if c().get("canTurnBack",false):b(actions,"引き返す",ui.forecast_action.bind("turnBack","turnBack",[])).tooltip_text="通った経路を戻る · 帰着まで%d時間" % c().get("returnHours",0)
		"road":
			if c().get("canTurnBack",false):b(actions,"引き返す",ui.forecast_action.bind("turnBack","turnBack",[])).tooltip_text="通った経路を戻る · 帰着まで%d時間" % c().get("returnHours",0)
		"arrival","delivery":
			ui.green_button(b(actions,"都市に入る" if journey_.get("destination")=="astaris" else "村に入る",ui.act.bind("arrive",[])))
	if phase=="road":
		var choices=row(parent);choices.name="RouteChoices"
		var quest = c().get("activeQuest")
		var sluice_trip = quest is Dictionary and quest.get("id") == "sluice-bell" and journey_.get("destination") == "east" and not strip.returning
		for route in [["short","峠の近道",2],["safe","川沿いの道",4]]:
			var caption = "%s\n移動 %d時間" % [route[1], route[2]]
			if sluice_trip:
				caption += "\n陣形の外にいる味方が射手に狙われる" if route[0] == "short" else "\n番人が巻上機を塞ぐ"
			var choose = b(choices, caption, ui.forecast_action.bind(route[0], "travel", [route[0]]))
			choose.name = "RouteChoice_" + route[0]
			choose.custom_minimum_size = Vector2(400, 100) if sluice_trip else Vector2(260, 80)
		if sluice_trip:
			var gate_note = "守護者が通常移動で巻上機に入ると開門。離脱・撃破で閉門。"
			gate_note += "\n舟守の合図は一戦一度。開門後、味方が道を空けてポーターが一手で出口に届くと、次はポーターの手番。"
			if int(journey_.get("stage", 0)) == 0:
				gate_note += "\n最初の区間で川沿いの舟守を助けると、次の戦闘の出口が近くなる。"
			l(parent, gate_note)
	if phase=="camp":
		b(parent,"インベントリ",ui.navigate.bind("character"))
	parent.add_child(HSeparator.new());active_quest_summary(parent)
func party(parent):
	if not facility_entry.render_top(parent,"party"):
		if facility_entry.supported("party"):facility_entry.render_dialogue()
		party_view.render(parent)
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
		var members=ui.member_grid(parent,"CampParty" if c().phase=="camp" else "ItemParty")
		for uid in c().get("selected",[]):
			var u=roster().filter(func(member):return member.id==uid)[0]
			var member=card(members);member.name="ItemMember_"+str(uid);member.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var portrait=ui.portrait(member,u,false,64);portrait.name="FullBodyPortrait";portrait.custom_minimum_size=Vector2(64,160 if ui.ui_size_mode=="standard" else 48);portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var name_label=l(member,u.name);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;ui.short_name(name_label,str(u.name));name_label.add_theme_font_size_override("font_size",16)
			var hp=ui.icons.line(ui,member,"hp","HP %d/%d" % [u.hp,u.max]);ui.emphasize_low_hp(hp,u)
			ui.icons.line(ui,member,"mp","MP %d/%d" % [u.mp,u.maxMp])
			if u.hp<=0:l(member,"戦闘不能")
			var open_inventory=b(member,"インベントリ",party_view.open_inventory.bind(str(uid)));open_inventory.name="InventoryOwner_"+str(uid);open_inventory.add_theme_font_size_override("font_size",16)
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
	var members=ui.member_grid(parent,"CampParty" if c().phase=="camp" else "ItemParty")
	for u in roster():
		if not c().selected.has(u.id):continue
		var member=card(members);member.name="ItemMember_"+str(u.id);member.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var portrait=ui.portrait(member,u,false,64);portrait.name="FullBodyPortrait";portrait.custom_minimum_size=Vector2(64,160 if ui.ui_size_mode=="standard" else 48);portrait.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var name_label=l(member,u.name);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;ui.short_name(name_label,str(u.name));name_label.add_theme_font_size_override("font_size",16)
		var hp=ui.icons.line(ui,member,"hp","HP %d/%d" % [u.hp,u.max]);ui.emphasize_low_hp(hp,u)
		ui.icons.line(ui,member,"mp","MP %d/%d" % [u.mp,u.maxMp])
		if u.hp<=0:l(member,"戦闘不能")
		if item_stage=="target":
			var reason=ItemMenu.camp_reason(selected_item,u,inventory)
			var target=b(member,"使う" if reason.is_empty() else reason,use_selected_item.bind(u.id),not reason.is_empty());target.name="ItemTarget_"+str(u.id);ui.memory.key(target,"item_target_"+str(u.id))
func inn(parent):inn_view.render(parent)
func inn_cards(parent):inn_view.cards(parent)
func stay_inn():inn_view.stay()
func shop(parent):
	if facility_entry.render_top(parent,"shop"):return
	facility_entry.render_dialogue()
	if c().get("location") not in ["east","west","south","north"]:l(parent,"この拠点にお店はありません");return
	shop_view.render(parent)
func select_slot(slot: String):await shop_view.select_slot(slot)
func purchase(_q: Dictionary):shop_view.confirm_purchase()
func buy(id: String):
	await shop_view.confirm_purchase(id)
func cancel_quote():shop_view.back_list()
func result(parent):
	var result_: Dictionary=c().get("result",{});var outcome=result_.get("outcome","")
	l(parent,{"success":"配達完了！","late":"配達完了！ / 遅配","failed":"クエスト失敗 / 出発前へ","travel":"目的地に到着"}.get(outcome,"旅の結果"),true)
	quest_board.render_sluice_story(parent,result_)
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

func acknowledge(page: String):
	if ui.results_view.active and ui.results_view.current.get("acknowledge",false):await ui.results_view.advance_to(page);return
	ui.page=page;await ui.act("acknowledge",[])

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
	warehouse_view.reset()
	quest_board.reset();inn_view.reset()
	hub_view.reset()
	facility_art.reset()
	if ui.hud!=null:ui.hud.reset_context()
	reset_items();facility_entry.reset();shop_view.reset(plan_mode,campaign_id);guild_view.reset();party_view.reset();party_view.tab=0;party_view.highlight_slot=""
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
			ui.icons.line(ui,parent,ui.icons.skill(str(gear[field]),int(gear.get("skillLevel",1))),("スキル: " if field=="skill" else "効果: ")+str(c().get("skillNames",{}).get(gear[field],gear[field])))
			l(parent,skill_description(str(gear[field]),int(gear.get("skillLevel",1))))
	if not str(gear.get("flavor","")).is_empty():l(parent,"説明\n"+str(gear.flavor))
	if gear.has("note"):l(parent,gear.note)

func skill_description(id: String,stage: int=1) -> String:
	return preload("res://skill_text.gd").description(id,stage,c())
