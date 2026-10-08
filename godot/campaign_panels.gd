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
var current_equipment_open := false
var cached_quotes: Dictionary={}
var party_focus_after := ""
func _init(frontend):ui=frontend
func l(parent,text,large:=false):return ui.label_(parent,str(text),large)
func b(parent,text,fn,disabled:=false):return ui.button(parent,text,fn,disabled)
func row(parent):return ui.row(parent)
func card(parent):return ui.card(parent)
func c() -> Dictionary:return ui.campaign()
func roster() -> Array:return ui.roster()
func town(id) -> String:return ui.town_name(id)
func muted(parent,text):
	var label=l(parent,text);label.add_theme_color_override("font_color",Color("#bcc9d3"));return label;return label
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
	return "HP上限 %d / MP上限 %d / %s / 行動速度 %d" % [stats.get("max",0),stats.get("maxMp",0),attack_profile(stats),stats.get("speed",stats.get("agi",0))]
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
func board(parent):
	var town_data={}
	for t in c().get("locations",[]):
		if t.id==c().location:town_data=t
	l(parent,town(c().location),true)
	muted(parent,town_data.get("description",town_data.get("text","掲示板で依頼を選ぶか、依頼を受けずに次の拠点へ移動できます。")))
	l(parent,"掲示板 / 同時に受ける依頼は一件",true)
	var quest=c().get("activeQuest")
	if quest is Dictionary:
		var box=card(parent);l(box,"受注中: "+quest.name,true);quest_info(box,quest)
		b(box,"地図で出発を準備",ui.navigate.bind("map"))
	else:
		muted(parent,"依頼文・期限・報酬は、繰り返し試遊のための仮設定です。")
		if c().get("board",[]).is_empty():l(parent,"いま受注できる依頼はありません。地図から自由移動できます。")
		for q in c().get("board",[]):
			var box=card(parent);l(box,q.name,true);quest_info(box,q)
			b(box,"この依頼を引き受ける",accept.bind(q.id),not c().get("hasPorter",false))
		b(parent,"地図・出発 / 自由移動",ui.navigate.bind("map"))
	if not c().get("hasPorter",false):l(parent,"受注・出発にはポーターが必要です。ギルドで編成してください。")
	l(parent,"直近の記録");l(parent,"\n".join(c().get("history",[]).slice(-6)))
func accept(id: String):
	await ui.act("accept",[id])
	if c().get("activeQuest") is Dictionary:ui.destination=c().activeQuest.to;ui.navigate("map")
func select_destination(id: String):
	ui.destination=id;ui.render()
func map(parent):
	l(parent,"次の行先を選ぶ",true)
	var available=[]
	for place in c().get("destinations",[]):available.append(place.id if place is Dictionary else place)
	var quest=c().get("activeQuest")
	if quest is Dictionary:
		ui.destination=quest.to;l(parent,"受注中: %s → %s" % [quest.name,town(quest.to)])
	elif not available.has(ui.destination):ui.destination=str(available[0]) if not available.is_empty() else ""
	muted(parent,"接続・距離・方角は試作用の模式図です。各移動は二つの区間を通ります。")
	var chart=preload("res://town_map.gd").new();chart.name="TownMap"
	chart.towns=c().get("locations",[]);chart.current=c().location;chart.selected=ui.destination;chart.available=available
	chart.quest_destination=str(quest.to) if quest is Dictionary else ""
	parent.add_child(chart);chart.destination_selected.connect(select_destination)
	for id in chart.buttons:ui.widgets.append(chart.buttons[id])
	var choices=row(parent)
	for id in available:b(choices,("● " if ui.destination==id else "")+town(id),select_destination.bind(id),quest is Dictionary and quest.to!=id)
	muted(parent,"未受注での移動も戦闘・消耗があります。配達報酬はありません。追加の移動料金はありません。")
	l(parent,"編成: "+" / ".join(roster().filter(func(u):return c().selected.has(u.id)).map(func(u):return u.name)))
	var formations=row(parent)
	for pair in [["convoy","基本配置"],["flank","切り込み配置"]]:
		b(formations,("● " if ui.formation==pair[0] else "○ ")+pair[1],choose_formation.bind(pair[0]))
	b(parent,town(ui.destination)+"へ出発" if not ui.destination.is_empty() else "行先がありません",ui.act.bind("depart",[ui.destination,ui.formation]),ui.destination.is_empty() or not c().get("hasPorter",false))
func choose_formation(value: String):ui.formation=value;ui.render()
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
	party_status(card(parent))
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
			b(parent,"荷物を渡して報酬を確認" if quest is Dictionary else "町へ入る（配達報酬なし）",ui.act.bind("arrive",[]))
	l(parent,"\n".join(journey_.get("history",[]).slice(-4)))
func party(parent):
	var members=roster();var selected_ids=c().get("selected",[])
	if not members.any(func(u):return u.id==party_uid):
		party_uid=str(selected_ids[0]) if not selected_ids.is_empty() else str(members[0].id) if not members.is_empty() else ""
	var split=VBoxContainer.new() if ui.ui_size_mode=="narrow" else HBoxContainer.new();split.name="PartySplit";split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_theme_constant_override("separation",8);parent.add_child(split)
	var list_=VBoxContainer.new();list_.name="PartyRoster";split.add_child(list_)
	if ui.ui_size_mode!="narrow":list_.custom_minimum_size.x=320 if ui.ui_size_mode=="standard" else 280
	l(list_,"編成 %d/5 / %s" % [selected_ids.size(),"ポーター在籍" if c().get("hasPorter",false) else "ポーター不在"],true)
	if ui.ui_size_mode=="narrow":
		for id in selected_ids:
			for u in members:
				if u.id==id:
					var line=l(list_,"%s / HP %d/%d MP %d/%d%s" % [u.name,u.hp,u.max,u.mp,u.maxMp," KO" if u.hp<=0 else ""]);ui.short_name(line,str(u.name));ui.emphasize_low_hp(line,u)
		var chooser=OptionButton.new();chooser.custom_minimum_size.y=40;chooser.clip_text=true;list_.add_child(chooser)
		for u in members:
			chooser.add_item(("編成 / " if selected_ids.has(u.id) else "控え / ")+str(u.name));chooser.set_item_metadata(chooser.item_count-1,u.id)
			if u.id==party_uid:chooser.select(chooser.item_count-1)
		chooser.item_selected.connect(func(i):select_party(str(chooser.get_item_metadata(i))));ui.memory.key(chooser,"party_narrow_select")
	else:
		for id in selected_ids:
			for u in members:
				if u.id==id:party_row(list_,u)
		l(list_,"控え / 行選択は詳細を見るだけ")
		var reserve=ui.scroller(list_);reserve.get_parent().custom_minimum_size.y=60;ui.memory.watch(reserve.get_parent(),"party_reserve")
		for u in members:
			if not selected_ids.has(u.id):party_row(reserve,u)
	var detail=VBoxContainer.new();detail.name="PartyDetail";detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_child(detail)
	var member={}
	for u in members:
		if u.id==party_uid:member=u;break
	if member.is_empty():l(detail,"仲間がいません");return
	var hero=row(detail);ui.portrait(hero,member,false,64)
	var heading=VBoxContainer.new();heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;hero.add_child(heading)
	var name_=l(heading,str(member.name),true);ui.short_name(name_,str(member.name))
	l(heading,str(member.get("role",""))+" / "+("編成中" if selected_ids.has(member.id) else "控え"))
	var active=selected_ids.has(member.id);var guild=c().get("guildAvailable",false)
	var membership=b(hero,"編成から外す" if active else "編成に加える",change_membership.bind(member.id),not guild or (not active and selected_ids.size()>=5));ui.memory.key(membership,"party_membership")
	var reason="雇用無料 / 最大5人 / 出発にはポーター必須"
	if not guild:reason="編成変更はアスタリスのギルドで行います。ここでは閲覧できます。"
	elif not active and selected_ids.size()>=5:reason="満員です。先に1人外してください。"
	elif not c().get("hasPorter",false):reason="ポーター不在: 出発にはポーターが必要です。"
	l(detail,reason)
	var body=ui.scroller(detail);body.get_parent().name="PartyDetailScroll";ui.memory.watch(body.get_parent(),"party_detail_"+party_uid)
	var hp=l(body,"HP %d/%d / MP %d/%d%s" % [member.hp,member.max,member.mp,member.maxMp," 戦闘不能" if member.hp<=0 else ""]);ui.emphasize_low_hp(hp,member);ui.memory.item(hp,"hp")
	ui.memory.item(l(body,"Lv.%d / 能力ポイント %d" % [member.get("level",1),member.get("statPoints",0)]),"level")
	ui.memory.item(l(body,member_stats(member)),"stats")
	l(body,stats_text(member.get("stats",member)))
	var allocate=row(body)
	for stat in ["str","int","agi"]:
		var control=b(allocate,stat.to_upper()+"+1",ui.act.bind("allocate",[member.id,stat,1]),c().get("phase")!="town" or member.get("statPoints",0)<=0);ui.memory.key(control,"allocate_"+stat)
	l(body,"スキルポイント %d（配分は未実装）" % member.get("skillPoints",0))
	ui.memory.item(l(body,"装備8枠",true),"equipment")
	equipment(body,member)
	for source in member.get("stats",member).get("skillSources",[]):
		l(body,"由来: %s / %s" % [c().get("slots",{}).get(source.get("slot",""),source.get("slot","")),source.get("itemName",source.get("itemId",""))])
	muted(body,"離脱・再編入しても人物ごとの装備・成長・HP/MPを保持します。装備の買替は対応する店で行います。")
func items(parent):
	l(parent,"道具 / ポーション %d ・エーテル %d" % [c().inventory.potion,c().inventory.ether],true)
	if c().phase not in ["town","camp"]:l(parent,"町・野営で使用できます");return
	muted(parent,"町と野営地で使用可能。HP+55 / MP+3。戦闘不能の仲間には使えません。")
	for u in roster():
		if not c().selected.has(u.id):continue
		var actions=row(card(parent));ui.portrait(actions,u,true,55)
		l(actions,"%s HP %d/%d MP %d/%d%s" % [u.name,u.hp,u.max,u.mp,u.maxMp," 戦闘不能" if u.hp<=0 else ""])
		b(actions,"ポーション HP+55",ui.act.bind("useItem",["potion",u.id]),c().inventory.potion<=0 or u.hp>=u.max or u.hp<=0)
		b(actions,"エーテル MP+3",ui.act.bind("useItem",["ether",u.id]),c().inventory.ether<=0 or u.mp>=u.maxMp or u.hp<=0)
func inn(parent):
	var q: Dictionary=c().get("inn",{})
	l(parent,"アスタリスの宿屋",true)
	if not q.get("available",false):l(parent,"宿屋はアスタリスで利用できます。");return
	l(parent,"パーティ全員で%dG（仮料金）" % q.price)
	l(parent,"編成中の全員のHP・MPを上限まで回復します。戦闘不能の仲間も回復します。")
	muted(parent,"控えの仲間は対象外。時間は経過しません（試作仕様）。");party_status(card(parent))
	if not q.get("needsRecovery",false):l(parent,"全員が全回復しています。料金はかかりません。")
	elif not q.get("affordable",false):l(parent,"所持金が足りません。宿泊には%dG必要です。" % q.price)
	b(parent,"%dGで宿泊する / 確認" % q.price,stay_inn,not q.get("needsRecovery",false) or not q.get("affordable",false))
func stay_inn():
	var q=c().get("inn",{})
	ui.confirm("%dGを支払い、編成中の全員のHP・MPを全回復しますか？\n戦闘不能も回復。控えは対象外、時間は経過しません。" % q.get("price",30),ui.act.bind("inn",[]))
func shop(parent):
	var location=c().get("location","")
	l(parent,{"east":"イースの武器屋","west":"ウエスの防具屋","south":"サウスの道具屋"}.get(location,"この拠点にお店はありません")+" / 所持金%dG" % c().get("gold",0),true)
	if location=="south":
		var body=ui.scroller(parent);ui.memory.watch(body.get_parent(),"consumable_shop")
		muted(body,"所持上限は各99個（試作値）。回復量はHP+55 / MP+3です。")
		for item in c().shop:
			var count=c().inventory[item.id];var actions=row(card(body))
			l(actions,"%s %dG / 所持%d" % [item.name,item.price,count])
			for amount in [1,5]:b(actions,"%d個購入" % amount,ui.act.bind("buyItem",[item.id,amount]),count+amount>99 or c().gold<item.price*amount)
		items(body);return
	if location not in ["east","west"]:
		muted(parent,"ノースの施設は掲示板です。お店や固有施設はまだ設定されていません。" if location=="north" else "武器はイース、防具はウエス、道具はサウスで購入できます。");return
	var ids=c().get("selected",[])
	if ids.is_empty():l(parent,"編成中の仲間がいません。ギルドで編成してください。");return
	if not ids.has(ui.shop_uid):ui.shop_uid=str(ids[0]);invalidate_quote(true)
	var members=row(parent)
	for id in ids:
		for u in roster():
			if u.id!=id:continue
			var box=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;members.add_child(box)
			ui.portrait(box,u,true,32)
			var control=ui.local_button(box,("● " if u.id==ui.shop_uid else "")+str(u.name),ui.select_shop.bind(u.id));control.clip_text=true;control.tooltip_text=str(u.name);ui.memory.key(control,"shop_member_"+str(u.id))
	var slots=c().get("slots",{})
	if (location=="east")!=(ui.shop_slot in ["rightHand","leftHand"]):ui.shop_slot="rightHand" if location=="east" else "upperBody";invalidate_quote(true)
	var choices=row(parent)
	for slot in slots:
		if (location=="east")==(slot in ["rightHand","leftHand"]):
			var control=ui.local_button(choices,("● " if slot==ui.shop_slot else "")+str(slots[slot]),select_slot.bind(slot));ui.memory.key(control,"shop_slot_"+slot)
	var split=VBoxContainer.new() if ui.ui_size_mode=="narrow" else HBoxContainer.new();split.name="ShopSplit";split.size_flags_vertical=Control.SIZE_EXPAND_FILL;split.add_theme_constant_override("separation",8);parent.add_child(split)
	var list_scroll=ScrollContainer.new();list_scroll.name="ShopProducts";list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;list_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;list_scroll.size_flags_stretch_ratio=38 if ui.ui_size_mode=="standard" else 36;split.add_child(list_scroll)
	if ui.ui_size_mode=="narrow":list_scroll.size_flags_vertical=Control.SIZE_FILL;list_scroll.custom_minimum_size.y=112
	ui.memory.watch(list_scroll,"shop_products")
	var products=VBoxContainer.new();products.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list_scroll.add_child(products)
	for gear in offered():product_row(products,gear)
	var compare=VBoxContainer.new();compare.name="GearQuote";compare.size_flags_horizontal=Control.SIZE_EXPAND_FILL;compare.size_flags_vertical=Control.SIZE_EXPAND_FILL;compare.size_flags_stretch_ratio=62 if ui.ui_size_mode=="standard" else 64;split.add_child(compare)
	if quote_valid():quote(compare,ui.gear_preview)
	else:
		l(compare,"比較取得中…" if quote_pending else "商品を選んで比較",true)
		l(compare,ui.member_name(ui.shop_uid)+" / "+str(slots.get(ui.shop_slot,ui.shop_slot)))
		var body=ui.scroller(compare)
		muted(body,"商品を選ぶと必要能力・条件と差額を表示します。購入前に木人で試せます。現在品は同じ枠から下取りされ、予備には残りません。")
		muted(body,"対象に届く各攻撃武器のATK合算＋成長補正1回。スナイプは各武器の射程+1。同スキル効果は重複しません。")
		b(compare,"木人で試す",func():pass,true);ui.primary(b(compare,"商品を選んでください",func():pass,true))
func select_slot(slot: String):
	ui.shop_slot=slot;invalidate_quote(false)
	var keep=gear_id
	if not offered().any(func(g):return g.id==keep):gear_id="";keep=""
	ui.render()
	if not keep.is_empty():await request_quote(keep)
func quote(parent,q: Dictionary):
	var summary=l(parent,ui.member_name(ui.shop_uid)+" / "+str(c().get("slots",{}).get(ui.shop_slot,ui.shop_slot))+(" / " if ui.ui_size_mode=="narrow" else "\n")+str(q.get("current",{}).get("name",q.get("oldGearId","")))+" → "+str(q.gear.name));ui.short_name(summary,summary.text)
	if ui.ui_size_mode=="narrow":summary.max_lines_visible=1
	var money=l(parent,("価格%d − 下取り%d = 差額%dG"+(" / " if ui.ui_size_mode=="narrow" else "\n")+"所持金%dG → 購入後%dG") % [q.price,q.tradeIn,q.cost,c().gold,q.afterGold]);money.name="QuoteMoney"
	var reason=quote_reason(q)
	var body=ui.scroller(parent);body.get_parent().name="ShopComparisonScroll";body.get_parent().custom_minimum_size.y=64;ui.memory.watch(body.get_parent(),"shop_compare")
	if not reason.is_empty():l(body,reason)
	var table=GridContainer.new();table.name="GearComparison";table.columns=4;table.size_flags_horizontal=Control.SIZE_EXPAND_FILL;table.add_theme_constant_override("h_separation",12);body.add_child(table);ui.memory.item(table,"comparison")
	for title in ["項目","現在","候補","変化"]:l(table,title)
	for stat in [["max","HP上限"],["maxMp","MP上限"]]:compare_numbers(table,stat[1],int(q.before.get(stat[0],0)),int(q.after.get(stat[0],0)))
	for distance in range(1,maxi(1,maxi(normal_reach(q.before),normal_reach(q.after)))+1):
		l(table,"通常ATK / 距離%d" % distance)
		var old_reaches=distance<=normal_reach(q.before);var new_reaches=distance<=normal_reach(q.after)
		var before_=normal_atk(q.before,distance);var after_=normal_atk(q.after,distance)
		l(table,str(before_) if old_reaches else "射程外");l(table,str(after_) if new_reaches else "射程外")
		l(table,"%+d" % (after_-before_) if old_reaches and new_reaches else "届く" if new_reaches else "届かない" if old_reaches else "—")
	compare_numbers(table,"最大通常射程",normal_reach(q.before),normal_reach(q.after))
	compare_numbers(table,"行動速度",int(q.before.get("speed",0)),int(q.after.get("speed",0)))
	for field in table.get_children():
		field.autowrap_mode=TextServer.AUTOWRAP_OFF;field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	ui.memory.item(muted(body,"通常ATKはその距離に届く武器の合算＋成長補正1回。陣形・スキル倍率・相手の防御は含みません。"),"attack_explanation")
	ui.memory.item(l(body,"装備中のスキル: "+q.get("skillName","")),"skills")
	ui.memory.item(l(body,str(q.get("effectDescription",""))),"effects")
	if q.get("reason") is String and not q.reason.is_empty():l(body,q.reason)
	muted(body,"購入すると現在の同じ枠の装備は下取りされます。予備装備としては残りません。")
	muted(body,q.get("warning","試着と取消では所持金・装備は変わりません"))
	ui.local_button(body,"現在装備8枠を閉じる" if current_equipment_open else "現在装備8枠を見る",func():current_equipment_open=not current_equipment_open;ui.render())
	if current_equipment_open:
		for member in roster():
			if member.id==ui.shop_uid:equipment(body,member)
	var actions=row(parent);actions.name="ShopActions"
	b(actions,"木人で試す",start_trial,not q.eligible or not q.available)
	var purchase_button=ui.primary(b(actions,"差額%dGで買い替える" % q.cost,purchase.bind(q.duplicate(true)),not(q.eligible and q.affordable and q.available) or q.same));ui.memory.key(purchase_button,"shop_buy")
	purchase_button.tooltip_text=reason;purchase_button.disabled=true
	body.get_parent().resized.connect(refresh_purchase_availability.bind(purchase_button))
	body.get_parent().visibility_changed.connect(refresh_purchase_availability.bind(purchase_button))
	refresh_purchase_availability(purchase_button)
	ui.memory.key(ui.local_button(actions,"比較を閉じる",cancel_quote),"shop_close")
func comparison_visible() -> bool:
	var pane=ui.find_child("ShopComparisonScroll",true,false)
	return pane is ScrollContainer and pane.is_visible_in_tree() and pane.size.y>=64 and ui.get_viewport_rect().grow(1).encloses(pane.get_global_rect())
func refresh_purchase_availability(control):
	await ui.get_tree().process_frame
	if is_instance_valid(control) and control.is_inside_tree():
		control.disabled=control.get_meta("base_disabled",true) or not quote_valid() or ui.locked or ui.presenting or not comparison_visible()
func purchase(q: Dictionary):
	if not comparison_visible():ui.notice="比較欄を表示して性能を確認してください。";ui.render();return
	if not quote_valid() or q.gearId!=gear_id:return
	var stamp=quote_stamp;var ticket=quote_generation;var uid=ui.shop_uid;var slot=ui.shop_slot
	ui.confirm("%s / %s\n価格%d − 下取り%d = 差額%dG\n所持金%dG → 購入後%dG\n現在の同じ枠の装備は下取りされ、予備装備としては残りません。" % [ui.member_name(uid),c().slots[slot],q.price,q.tradeIn,q.cost,c().gold,q.afterGold],func():
		if stamp!=quote_stamp or ticket!=quote_generation or uid!=ui.shop_uid or slot!=ui.shop_slot or not quote_valid():ui.notice="比較条件が変わりました。最新の見積を確認してください。";ui.render();return
		buy(str(q.gearId)))
func buy(id: String):
	if not comparison_visible():return
	if not quote_valid() or id!=gear_id:return
	var uid=ui.shop_uid;var slot=ui.shop_slot
	invalidate_quote(false)
	var reply=await ui.act("buyGear",[uid,id,slot])
	var result_notice="購入済み / 現在装備を再確認しました" if reply is Dictionary and reply.get("ok",false) else ui.notice
	await request_quote(id)
	ui.notice=result_notice;ui.render()
func cancel_quote():
	invalidate_quote(false);ui.audio.ui("cancel");ui.render()
func result(parent):
	var result_: Dictionary=c().get("result",{});var outcome=result_.get("outcome","")
	l(parent,{"success":"配達達成","late":"配達達成 / 遅配","failed":"クエスト失敗 / 出発前へ","travel":"目的地に到着"}.get(outcome,"旅の結果"),true)
	if outcome=="failed":
		l(parent,result_.get("reason","護送隊が敗北しました"))
		l(parent,"受注直前の状態へ戻しました。自由移動の場合は出発直前へ戻ります。")
		muted(parent,"所持金・装備・編成・HP/MP・道具・経験値・経過時間を復元しています。")
	elif outcome=="travel":l(parent,"依頼を受けずに移動しました。配達報酬はありません。戦闘の経験値は保持されます。")
	else:l(parent,"荷物を届けました。報酬と成長を持ち越して、次の依頼や買い物へ進めます。")
	l(parent,"今回の配達報酬 %dG / 配達経験値 %d" % [result_.get("gold",0),result_.get("xp",0)],true)
	l(parent,"所持金 %dG / 累計経験値 %d / 隊Lv.%d" % [c().gold,c().xp,c().level])
	if result_.get("hours")!=null:l(parent,"所要時間 %d時間" % result_.hours)
	party_status(card(parent));l(parent,"現在地: "+town(c().location)+"。ここで施設を利用し、次の出発を選べます。")
	b(parent,town(c().location)+"に留まる / 掲示板へ",acknowledge.bind("board"))
	if c().location in ["east","west","south"]:b(parent,town(c().location)+"のお店へ",acknowledge.bind("shop"))
	elif c().location=="astaris":b(parent,"アスタリスの宿屋へ",acknowledge.bind("inn"))
	l(parent,"\n".join(c().get("history",[]).slice(-5)))
func acknowledge(page: String):ui.page=page;await ui.act("acknowledge",[])

func party_row(parent,u: Dictionary):
	var r=row(parent);ui.memory.item(r,str(u.id));ui.portrait(r,u,true,36)
	var box=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;r.add_child(box)
	var control=ui.local_button(box,("● " if u.id==party_uid else "")+str(u.name)+" / "+str(u.get("role","")),select_party.bind(str(u.id)))
	control.clip_text=true;control.alignment=HORIZONTAL_ALIGNMENT_LEFT;control.tooltip_text=str(u.name)+" / "+str(u.get("role",""));ui.memory.key(control,"party_"+str(u.id))
	control.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_UP,KEY_DOWN]:
			var ids=c().get("selected",[]).duplicate()
			for member in roster():
				if not ids.has(member.id):ids.append(member.id)
			var index=ids.find(u.id);var next=clampi(index+(-1 if event.keycode==KEY_UP else 1),0,ids.size()-1)
			ui.memory.request_focus("party_"+str(ids[next]),true);select_party(str(ids[next]));control.accept_event())
	var hp=l(box,"HP%d/%d MP%d/%d%s" % [u.hp,u.max,u.mp,u.maxMp," KO" if u.hp<=0 else ""]);hp.add_theme_font_size_override("font_size",16);ui.emphasize_low_hp(hp,u)
func select_party(id: String):
	party_uid=id;ui.memory.request_focus("party_"+id);ui.render()
func change_membership(id: String):
	party_uid=id
	await ui.toggle_member(id)
	ui.memory.request_focus("party_"+id,true);ui.memory.restore()
func offered() -> Array:
	return c().get("shop",[]).filter(func(g):
		var allowed=g.get("allowedSlots",["rightHand"] if g.get("hands",1)==2 else ["rightHand","leftHand"] if g.slot=="weapon" else ["upperBody"] if g.slot=="armor" else ["accessory1","accessory2"] if g.get("type")=="accessory" else [g.slot])
		return allowed.has(ui.shop_slot))
func product_effect(g: Dictionary) -> String:
	if str(g.id).begins_with("empty-"):return "装備なし"
	var parts=[]
	if g.slot=="weapon":parts.append("ATK%d 射程%d" % [g.get("atk",0),g.get("reach",0)])
	if g.get("hp",0)!=0:parts.append("HP%+d" % g.hp)
	# The catalog already owns the effect description; do not duplicate rules.
	if g.has("effect") or g.has("skill"):
		var note=str(g.get("note","")).split("。")[0]
		if not note.is_empty():parts.append(note)
	return " / ".join(parts) if not parts.is_empty() else "能力補正なし"
func product_row(parent,g: Dictionary):
	var requirements=[]
	for stat in ["str","int","agi"]:
		if g.get(stat,0)>0:requirements.append("%s%d" % [stat.to_upper(),g[stat]])
	var effect=product_effect(g)
	var eligibility="条件未確認"
	if cached_quotes.has(selection_key(str(g.id))):
		var cached: Dictionary=cached_quotes[selection_key(str(g.id))];eligibility="装備可" if cached.eligible else "条件不適合"
	var caption=("● " if gear_id==g.id else "")+str(g.name)+" / %dG" % g.price+"\n"+effect+" / "+("・".join(requirements) if not requirements.is_empty() else "条件なし")+" / "+eligibility
	var control=ui.local_button(parent,caption,ui.preview_gear.bind(str(g.id)));control.name="Product_"+str(g.id);control.custom_minimum_size.y=52;control.alignment=HORIZONTAL_ALIGNMENT_LEFT;control.clip_text=true
	control.tooltip_text=str(g.name)+"\n"+str(g.get("note",""))+"\n"+caption;ui.memory.key(control,"product_"+str(g.id));ui.memory.item(control,str(g.id))
	control.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_UP,KEY_DOWN]:
			var list=offered();var index=list.find(g);var next=clampi(index+(-1 if event.keycode==KEY_UP else 1),0,list.size()-1)
			ui.memory.request_focus("product_"+str(list[next].id),true);ui.preview_gear(str(list[next].id));control.accept_event())
func compare_numbers(parent,title: String,before_: int,after_: int):
	l(parent,title);l(parent,str(before_));l(parent,str(after_));l(parent,"%+d" % (after_-before_))
func quote_reason(q: Dictionary) -> String:
	var reasons=[]
	if not q.eligible:reasons.append(str(q.get("reason","装備条件を満たしていません")))
	if not q.affordable:reasons.append("所持金が不足 / 木人は試用可能" if q.eligible and q.available else "所持金が不足")
	if q.same:reasons.append("現在装備 / すでにこの装備を装備しています")
	if not q.available:reasons.append("この店の取扱外")
	return " / ".join(reasons)
func selection_key(id: String) -> String:
	return JSON.stringify([epoch,ui.engine.connection_generation,c().get("location"),ui.shop_uid,ui.shop_slot,id,c().get("gold"),c().get("characters"),c().get("selected")])
func quote_valid() -> bool:
	return not quote_pending and not ui.gear_preview.is_empty() and quote_stamp==selection_key(gear_id)
func invalidate_quote(clear_id:=false):
	quote_generation+=1;quote_pending=false;quote_stamp="";ui.gear_preview={}
	if clear_id:gear_id=""
func reset_context():
	epoch+=1;invalidate_quote(true);trial_return={};cached_quotes={};current_equipment_open=false
func request_quote(id: String):
	gear_id=id;invalidate_quote(false);quote_pending=true
	var token=quote_generation;var stamp=selection_key(id);var uid=ui.shop_uid;var slot=ui.shop_slot
	ui.render()
	while ui.engine.busy and not ui.closing:
		await ui.get_tree().process_frame
		if token!=quote_generation or stamp!=selection_key(id):return
	if ui.closing or token!=quote_generation or stamp!=selection_key(id):return
	var response=await ui.engine.request({"op":"campaign","action":"previewGear","args":[uid,id,slot]})
	if token!=quote_generation or stamp!=selection_key(id) or gear_id!=id:return
	quote_pending=false
	if response.get("ok",false) and response.get("previewGear") is Dictionary:
		ui.gear_preview=response.previewGear;quote_stamp=stamp;cached_quotes[stamp]=response.previewGear;ui.notice=""
	else:
		ui.notice=str(response.get("error","比較できません"));ui.gear_preview={}
		if response.get("connection_lost",false):reset_context();ui.invalidate_preview()
	ui.render()
func select_member(id: String):
	ui.shop_uid=id;invalidate_quote(false)
	var keep=gear_id;ui.render()
	if not keep.is_empty():await request_quote(keep)
func remember_trial(args: Array):
	ui.memory.capture()
	trial_return={"epoch":epoch,"location":c().get("location"),"uid":args[0],"gear":args[1],"slot":args[2],"scrolls":ui.memory.scrolls.duplicate(true),"focus":"product_"+str(args[1])}
func start_trial():
	if quote_valid():await ui.act("trial",[ui.shop_uid,gear_id,ui.shop_slot])
func restore_trial():
	if trial_return.is_empty() or trial_return.get("epoch")!=epoch:return
	var previous=trial_return.duplicate(true);trial_return={}
	if c().get("location")!=previous.location:ui.notice="試用前の店が変わったため選択を解除しました";invalidate_quote(true);return
	ui.page="shop";ui.shop_uid=previous.uid;ui.shop_slot=previous.slot
	if not c().get("selected",[]).has(ui.shop_uid) or not offered().any(func(g):return g.id==previous.gear):
		invalidate_quote(true);ui.notice="試用前の人物・商品を確認できないため選択を解除しました";ui.render();return
	ui.memory.scrolls.merge(previous.scrolls,true)
	await request_quote(str(previous.gear))
	ui.memory.scrolls.merge(previous.scrolls,true);ui.memory.request_focus(previous.focus);ui.memory.restore()
