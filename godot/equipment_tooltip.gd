extends Button
## Native tooltip lifecycle, with no game-state mutation or retained UI owner.
const POSITIVE="#8ac7ff"
const NEGATIVE="#ff9494"
const SKILL="#c7a5ff"
const NEUTRAL="#b4c4cf"
var heading := ""
var details: Array[String]=[]
var plain_details: Array[String]=[]
var title_size := 24
var detail_size := 18
func escaped(text: String) -> String:return text.replace("[","[lb]")
func signed_value(value,show_sign:=true) -> String:
	var n=int(value);var color=POSITIVE if n>0 else NEGATIVE if n<0 else NEUTRAL
	return "[color="+color+"]"+("+" if show_sign and n>0 else "")+str(n)+"[/color]"
func line(plain: String,rich: String=""):
	plain_details.append(plain);details.append(escaped(plain) if rich.is_empty() else rich)
func colored_effect(text: String) -> String:
	# Only explicit signs, multipliers, percentages and stated recovery amounts.
	# Range/Lv/target counts remain purple; they are not fabricated modifiers.
	var regex=RegEx.new();regex.compile("[+＋−-][0-9]+(?:\\.[0-9]+)?(?:%|％)?|×[0-9]+(?:\\.[0-9]+)?|[0-9]+(?:\\.[0-9]+)?(?:%|％)|(?:HP|MP)(?:を)?(?:各)?[0-9]+(?=回復)")
	var result="";var cursor=0
	for match_ in regex.search_all(text):
		result+=escaped(text.substr(cursor,match_.get_start()-cursor))
		var token=match_.get_string();var numeric=RegEx.new();numeric.compile("[0-9]+(?:\\.[0-9]+)?");var number=numeric.search(token);var amount=float(number.get_string())
		var color=""
		if token.begins_with("+") or token.begins_with("＋"):color=POSITIVE if amount>0 else ""
		elif token.begins_with("-") or token.begins_with("−"):color=NEGATIVE if amount>0 else ""
		elif token.begins_with("×"):color=POSITIVE if amount>1 else NEGATIVE if amount<1 else ""
		elif token.ends_with("%") or token.ends_with("％"):color=POSITIVE if amount>100 else NEGATIVE if amount<100 else ""
		else:color=POSITIVE if amount>0 else ""
		if (token.begins_with("HP") or token.begins_with("MP")) and not color.is_empty():
			result+=escaped(token.substr(0,number.get_start()))+"[color="+color+"]"+number.get_string()+"[/color]"+escaped(token.substr(number.get_end()))
		else:result+=escaped(token) if color.is_empty() else "[color="+color+"]"+escaped(token)+"[/color]"
		cursor=match_.get_end()
	return result+escaped(text.substr(cursor))
func skill_range(id: String,gear: Dictionary,definition: Dictionary,passive: bool) -> String:
	if passive:return "該当なし（パッシブ）"
	if id=="scout":return "距離制限なし（装備Lvの方向・経路条件あり）"
	if id=="returnHome":return "距離制限なし（自陣の空きマス）"
	if id=="porter":return "0（使用者自身・成立中の陣形）"
	if definition.get("reach")!=null:return str(int(definition.reach))
	if id=="archer":return str(int(gear.get("reach",0))+1)+"（各攻撃武器の射程+1）"
	return {"guard":"1","mage":"2","stamp":"1（中心指定・3マス範囲）"}.get(id,"該当なし")
func configure(title: String,gear: Dictionary,context: Dictionary):
	heading=title;title_size=context.get("title_size",24);detail_size=context.get("detail_size",18)
	details.clear();plain_details.clear()
	var attacks=gear.get("type")!="empty" and int(gear.get("atk",0))>0
	if attacks:line("通常攻撃射程："+str(int(gear.get("reach",1))))
	var modifiers={"atk":"武器ATK","hp":"HP上限","mp":"MP上限","agiBonus":"行動速度"}
	var count=0
	if gear.get("type")!="empty":
		for key in modifiers:
			if not gear.has(key):continue
			var n=int(gear[key]);var sign="+" if n>0 and key!="atk" else ""
			line(modifiers[key]+"："+sign+str(n),modifiers[key]+"："+signed_value(n,key!="atk"));count+=1
	if count==0:line("補正値：なし")
	var has_skill=false
	for field in ["skill","effect"]:
		if gear.get(field)==null:continue
		has_skill=true;var id=str(gear[field]);var definition=context.get("definitions",{}).get(id,{})
		var passive=definition.get("classification","passive" if field=="effect" else "active")=="passive"
		var name=str(context.get("names",{}).get(id,id))
		if id=="scout":name+="Lv%d" % int(gear.get("skillLevel",1))
		line("付与スキル："+name,"[color="+SKILL+"]付与スキル："+escaped(name)+"[/color]")
		var effective=int(context.get("effective_levels",{}).get(id,gear.get("skillLevel",1)))
		if id=="scout" and effective!=int(gear.get("skillLevel",1)):
			line("装備中の有効Lv：%d（同スキル最高Lv）" % effective,"[color="+SKILL+"]装備中の有効Lv：%d（同スキル最高Lv）[/color]" % effective)
		var range_=skill_range(id,gear,definition,passive)
		line("スキル射程："+range_,"[color="+SKILL+"]スキル射程："+escaped(range_)+"[/color]")
		var description=str(context.get("descriptions",{}).get(id,""))
		if description.is_empty():description=str(gear.get("note","効果の説明なし"))
		line(description,"[color="+SKILL+"]"+colored_effect(description)+"[/color]")
		if not passive:
			var cost=int(definition.get("cost",0 if id=="returnHome" else 1))
			line("消費MP："+str(cost),"[color="+SKILL+"]消費MP："+signed_value(-cost)+"[/color]")
	if not has_skill:line("付与スキル：なし")
	if context.get("occupied",false):line("両手装備で使用中（独立した追加装備ではありません）")
	if context.get("job")=="porter" and attacks:line("この人物は通常攻撃不可（ポーター）")
	tooltip_text=heading+"\n"+"\n".join(plain_details)
func configure_entry(entry: Dictionary,campaign: Dictionary):
	var gear: Dictionary=entry.get("definition",{})
	if entry.get("kind")=="equipment":
		configure(str(entry.name),gear,{"names":campaign.get("skillNames",{}),"definitions":campaign.get("skillDefinitions",{}),"descriptions":campaign.get("skillDescriptions",{})})
	else:
		heading=str(entry.name);details.clear();plain_details.clear()
		if gear.has("resource"):line(preload("res://item_menu.gd").effect(gear))
		if gear.has("battleRole"):line("戦闘での使用条件："+str(gear.battleRole))
		line(str(gear.get("note",gear.get("description","依頼に関わる所持品" if entry.get("kind")=="quest" else "使用時に1個消費"))))
		tooltip_text=heading+"\n"+"\n".join(plain_details)
func _make_custom_tooltip(_for_text: String) -> Object:
	var box=VBoxContainer.new();box.name="EquipmentTooltip";box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Native tooltip windows measure this tree before its first container layout.
	# Seed the wrapping width and final heading font before that measurement.
	var width=mini(520,maxi(240,int(get_viewport_rect().size.x)-32));box.custom_minimum_size.x=width;box.size.x=width
	var title=Label.new();title.name="EquipmentTooltipName";title.size.x=width;title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_override("font",get_theme_font("font"));title.add_theme_font_size_override("font_size",title_size)
	title.text=heading;title.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(title)
	var body=RichTextLabel.new();body.name="EquipmentTooltipDetails";body.bbcode_enabled=true;body.fit_content=true;body.scroll_active=false
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.custom_minimum_size.x=width;body.size.x=width;body.add_theme_font_size_override("normal_font_size",detail_size)
	body.add_theme_font_override("normal_font",get_theme_font("font"));body.text="\n".join(details);body.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(body)
	return box
