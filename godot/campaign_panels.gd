extends RefCounted
## Presentation of existing Campaign.view fields. Mutations stay in the bridge.
var ui
func _init(frontend):ui=frontend
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
		if u.hp<=0 or u.hp*4<u.max:line.add_theme_color_override("font_color",Color("#ff8484"))
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
			var actions=row(parent)
			b(actions,"休息済み" if journey_.get("rested",false) else "2時間休む: HP+60 / MP+2",ui.forecast_action.bind("rest","rest",[]),journey_.get("rested",false))
			b(actions,"次の区間へ",ui.act.bind("onward",[]));items(parent)
		"arrival","delivery":
			l(parent,town(journey_.get("destination",""))+"に到着しました",true)
			b(parent,"荷物を渡して報酬を確認" if quest is Dictionary else "町へ入る（配達報酬なし）",ui.act.bind("arrive",[]))
	l(parent,"\n".join(journey_.get("history",[]).slice(-4)))
func party(parent):
	var guild=c().get("guildAvailable",false)
	l(parent,"アスタリスのギルド" if guild else "仲間と装備",true)
	muted(parent,"候補11人・最大5人 / 雇用無料 / 出発にはポーター必須" if guild else "編成変更はアスタリスのギルドで行います。装備はキャラクターごとに保持されます。")
	var grid=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(grid)
	for u in roster():
		var box=card(grid);box.custom_minimum_size.x=350;box.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
		ui.portrait(box,u,false,100)
		var active=c().selected.has(u.id)
		b(box,("● " if active else "○ ")+u.name+" / "+u.get("role",""),ui.toggle_member.bind(u.id),not guild or (not active and c().selected.size()>=5))
		l(box,"HP %d/%d / MP %d/%d%s" % [u.hp,u.max,u.mp,u.maxMp," 戦闘不能" if u.hp<=0 else ""])
		l(box,member_stats(u));equipment(box,u)
		l(box,"Lv.%d / 能力ポイント %d" % [u.get("level",1),u.get("statPoints",0)])
		if u.get("skillPoints",0)>0:l(box,"スキルポイント %d（配分は未実装）" % u.skillPoints)
		if u.get("statPoints",0)>0:
			var actions=row(box)
			for stat in ["str","int","agi"]:b(actions,stat.to_upper()+"+1",ui.act.bind("allocate",[u.id,stat,1]),c().phase!="town")
	muted(parent,"離脱・再編入しても買い替えた装備は保持されます。能力値・装備条件・成長値は試作値です。")
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
	var location=c().location
	l(parent,{"east":"イースの武器屋","west":"ウエスの防具屋","south":"サウスの道具屋"}.get(location,"この拠点にお店はありません"),true)
	if location=="south":
		muted(parent,"所持上限は各99個（試作値）。回復量はHP+55 / MP+3です。")
		for item in c().shop:
			var count=c().inventory[item.id];var actions=row(card(parent))
			l(actions,"%s %dG / 所持%d" % [item.name,item.price,count])
			for amount in [1,5]:b(actions,"%d個購入" % amount,ui.act.bind("buyItem",[item.id,amount]),count+amount>99 or c().gold<item.price*amount)
	elif location in ["east","west"]:
		muted(parent,"買い替え時に現在の装備を下取りします。購入前に木人で試せます。")
		var members=row(parent)
		for u in roster():
			if not c().selected.has(u.id):continue
			var box=card(members);ui.portrait(box,u,false,82);b(box,("● " if u.id==ui.shop_uid else "")+u.name,ui.select_shop.bind(u.id))
		if not c().selected.has(ui.shop_uid):ui.shop_uid=c().selected[0]
		var member={}
		for u in roster():
			if u.id==ui.shop_uid:member=u
		l(parent,member_stats(member));equipment(card(parent),member)
		muted(parent,"片手装備は1枠、両手装備は2枠。通常攻撃・攻撃スキルは、対象に届く各攻撃武器のATK合算＋成長補正1回。スナイプは各武器の射程+1。同スキル効果は重複しません。")
		var slots=c().slots
		if (location=="east")!=(ui.shop_slot in ["rightHand","leftHand"]):ui.shop_slot="rightHand" if location=="east" else "upperBody"
		var choices=row(parent)
		for slot in slots:
			if (location=="east")==(slot in ["rightHand","leftHand"]):b(choices,("● " if slot==ui.shop_slot else "")+slots[slot],select_slot.bind(slot))
		l(parent,"選択中: %s / %s" % [ui.member_name(ui.shop_uid),slots[ui.shop_slot]])
		if not ui.gear_preview.is_empty():quote(card(parent),ui.gear_preview)
		for g in c().shop:
			var allowed=g.get("allowedSlots",["rightHand"] if g.get("hands",1)==2 else ["rightHand","leftHand"] if g.slot=="weapon" else ["upperBody"] if g.slot=="armor" else ["accessory1","accessory2"] if g.get("type")=="accessory" else [g.slot])
			if not allowed.has(ui.shop_slot):continue
			var box=card(parent);l(box,"%s / %dG" % [g.name,g.price],true)
			var requirements=[]
			for key in ["str","int","agi"]:
				if g.get(key,0)>0:requirements.append("%s %d" % [key.to_upper(),g[key]])
			var effect="ATK %d / 射程 %d" % [g.get("atk",0),g.get("reach",0)] if g.slot=="weapon" else "最大HP +%d" % g.get("hp",0)
			l(box,effect+" / 必要能力 "+(" / ".join(requirements) if not requirements.is_empty() else "なし"))
			if not str(g.get("note","")).is_empty():muted(box,g.note)
			b(box,"差額・条件を確認 / 試着",ui.preview_gear.bind(g.id))
	else:muted(parent,"ノースの施設は掲示板です。お店や固有施設はまだ設定されていません。" if location=="north" else "武器はイース、防具はウエス、道具はサウスで購入できます。")
	items(parent)
func select_slot(slot: String):ui.shop_slot=slot;ui.gear_preview={};ui.render()
func quote(parent,q: Dictionary):
	parent.get_parent().name="GearQuote"
	l(parent,ui.member_name(ui.shop_uid)+"の装備を買い替え",true)
	l(parent,"現在: %s\n候補: %s" % [q.get("current",{}).get("name",q.get("oldGearId","")),q.gear.name])
	l(parent,"価格%d − 下取り%d = 差額%dG\n所持金%dG → 購入後%dG" % [q.price,q.tradeIn,q.cost,c().gold,q.afterGold])
	var table=GridContainer.new();table.name="GearComparison";table.columns=3;table.size_flags_horizontal=Control.SIZE_EXPAND_FILL;table.add_theme_constant_override("h_separation",40);parent.add_child(table)
	for title in ["能力","変更前","変更後"]:l(table,title)
	for stat in [["max","HP上限"],["maxMp","MP上限"]]:
		l(table,stat[1]);l(table,str(int(q.before.get(stat[0],0))));l(table,str(int(q.after.get(stat[0],0))))
	for distance in range(1,maxi(1,maxi(normal_reach(q.before),normal_reach(q.after)))+1):
		l(table,"通常ATK / 距離%d" % distance)
		for stats in [q.before,q.after]:
			l(table,str(normal_atk(stats,distance)) if distance<=normal_reach(stats) else "射程外")
	l(table,"最大通常射程");l(table,str(normal_reach(q.before)));l(table,str(normal_reach(q.after)))
	l(table,"行動速度");l(table,str(int(q.before.get("speed",0))));l(table,str(int(q.after.get("speed",0))))
	muted(parent,"通常ATKはその距離に届く武器の合算＋成長補正1回。陣形・スキル倍率・相手の防御は含みません。")
	for field in table.get_children():
		field.autowrap_mode=TextServer.AUTOWRAP_OFF;field.custom_minimum_size.x=120;field.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	l(parent,"装備中のスキル: "+q.get("skillName",""))
	if not str(q.get("effectDescription","")).is_empty():l(parent,q.effectDescription)
	if q.get("reason") is String and not q.reason.is_empty():l(parent,q.reason)
	if not q.eligible:l(parent,"装備条件を満たしていません")
	if not q.affordable:l(parent,"所持金が不足しています。購入せずに試着できます。")
	if q.same:l(parent,"すでにこの装備を装備しています")
	if not q.available:l(parent,"このお店では購入できません")
	muted(parent,"購入すると現在の同じ枠の装備は下取りされます。予備装備としては残りません。")
	muted(parent,q.get("warning","試着と取消では所持金・装備は変わりません"))
	var actions=row(parent)
	b(actions,"木人で試す",ui.act.bind("trial",[ui.shop_uid,q.gearId,ui.shop_slot]),not q.eligible or not q.available)
	b(actions,"この差額で買い替える",purchase.bind(q.duplicate(true)),not(q.eligible and q.affordable and q.available) or q.same)
	b(actions,"取消 / 戻る",cancel_quote)
func purchase(q: Dictionary):
	ui.confirm("差額%dGで買い替えます。現在の同じ枠の装備は下取りされます。" % q.cost,buy.bind(q.gearId))
func buy(id: String):
	ui.gear_preview={};await ui.act("buyGear",[ui.shop_uid,id,ui.shop_slot])
func cancel_quote():ui.gear_preview={};ui.audio.ui("cancel");ui.render()
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
