extends "res://compact_hover_button.gd"
const ElementBadges=preload("res://element_badges.gd")
const POSITIVE="#8ac7ff"
const NEGATIVE="#ff9494"
const SKILL="#c7a5ff"
const NEUTRAL="#b4c4cf"
var details: Array[String]=[]
var plain_details: Array[String]=[]
static var _effect_regex: RegEx
static var _numeric_regex: RegEx
static func bind_details(button: Button,ui,entry: Dictionary):
	var item=entry.duplicate(true)
	if not item.has("definition"):
		item={"id":item.get("id",""),"name":item.get("name",""),"kind":"equipment","count":1,"definition":item}
	item.count=item.get("count",1)
	var previous_hint=button.tooltip_text
	bind_hover(button,item,ui.campaign())
	if not previous_hint.is_empty():button.tooltip_text=previous_hint
	button.pressed.connect(func():ui.show_equipment_details.call_deferred(item,str(button.name)))

static func bind_hover(control: Control,item: Dictionary,campaign: Dictionary):
	control.set_script(load("res://equipment_tooltip.gd"))
	control.configure_entry(item,campaign)

func equipment_brief(gear: Dictionary,skills: Array[String]) -> String:
	var points: Array[String]=[]
	if gear.get("type")=="empty":return ""
	points.append(weight_text(gear.get("weight",1)))
	for stat in ["atk","def"]:
		var values: Array[String]=[]
		for element in [["",""],["Fire","火"],["Water","水"],["Earth","地"]]:
			var value=int(gear.get(stat+element[0],0))
			if value!=0:values.append(element[1]+str(value))
		if not values.is_empty():points.append(("攻撃 " if stat=="atk" else "防御 ")+" / ".join(values))
	for key in ["hp","mp","agiBonus"]:
		var value=int(gear.get(key,0))
		if value!=0:points.append({"hp":"HP上限","mp":"MP上限","agiBonus":"行動速度"}[key]+" %+d" % value)
	if not skills.is_empty():points.append("付与スキル："+" / ".join(skills))
	return "\n".join(points)
func weight_text(value) -> String:
	var result=str(snappedf(float(value),0.01))
	return "Wt "+(result if result.contains(".") else result+".0")
func escaped(text: String) -> String:return text.replace("[","[lb]")
func signed_value(value,show_sign:=true) -> String:
	var n=int(value);var color=POSITIVE if n>0 else NEGATIVE if n<0 else NEUTRAL
	return "[color="+color+"]"+("+" if show_sign and n>0 else "")+str(n)+"[/color]"
func line(plain: String,rich: String=""):
	plain_details.append(plain);details.append(escaped(plain) if rich.is_empty() else rich)
func colored_effect(text: String) -> String:
	# Only explicit signs, multipliers, percentages and stated recovery amounts.
	# Range/Lv/target counts remain purple; they are not fabricated modifiers.
	if _effect_regex==null:
		_effect_regex=RegEx.new();_effect_regex.compile("[+＋−-][0-9]+(?:\\.[0-9]+)?(?:%|％)?|×[0-9]+(?:\\.[0-9]+)?|[0-9]+(?:\\.[0-9]+)?(?:%|％)|(?:HP|MP)(?:を)?(?:各)?[0-9]+(?=回復)")
		_numeric_regex=RegEx.new();_numeric_regex.compile("[0-9]+(?:\\.[0-9]+)?")
	var result="";var cursor=0
	for match_ in _effect_regex.search_all(text):
		result+=escaped(text.substr(cursor,match_.get_start()-cursor))
		var token=match_.get_string();var number=_numeric_regex.search(token);var amount=float(number.get_string())
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
	return preload("res://skill_text.gd").range_text(id,gear,definition,passive,int(gear.get("skillLevel",1)))
func configure(title: String,gear: Dictionary,context: Dictionary):
	connect_hover();close_hover()
	heading=title
	details.clear();plain_details.clear()
	line("装備の基礎能力")
	var attacks=gear.get("type")!="empty" and int(gear.get("atk",0))>0
	if gear.get("type")!="empty":
		line("Wt：%s" % str(gear.get("weight",1)))
		line("ATK 物%d / 火%d / 水%d / 地%d" % [gear.get("atk",0),gear.get("atkFire",0),gear.get("atkWater",0),gear.get("atkEarth",0)],"ATK 物%d / %s%d / %s%d / %s%d" % [gear.get("atk",0),ElementBadges.inline("fire"),gear.get("atkFire",0),ElementBadges.inline("water"),gear.get("atkWater",0),ElementBadges.inline("earth"),gear.get("atkEarth",0)])
		line("DEF 物%d / 火%d / 水%d / 地%d" % [gear.get("def",0),gear.get("defFire",0),gear.get("defWater",0),gear.get("defEarth",0)],"DEF 物%d / %s%d / %s%d / %s%d" % [gear.get("def",0),ElementBadges.inline("fire"),gear.get("defFire",0),ElementBadges.inline("water"),gear.get("defWater",0),ElementBadges.inline("earth"),gear.get("defEarth",0)])
		line("属性相性：有利×1.25 / 不利×0.75。攻撃ATK−対応DEF後に適用。物理・同属性・無属性は等倍。")
	if attacks:line("通常攻撃射程："+str(int(gear.get("reach",1))))
	var modifiers={"atk":"武器ATK","hp":"HP上限","mp":"MP上限","agiBonus":"行動速度"}
	var count=0
	if gear.get("type")!="empty":
		for key in modifiers:
			if not gear.has(key):continue
			var n=int(gear[key]);var sign="+" if n>0 and key!="atk" else ""
			line(modifiers[key]+"："+sign+str(n),modifiers[key]+"："+signed_value(n,key!="atk"));count+=1
	if count==0:line("補正値：なし")
	var requirements=[]
	for key in ["str","int","agi"]:
		if gear.get(key,0)>0:requirements.append(key.to_upper()+str(int(gear[key])))
	if not requirements.is_empty():line("装備条件："+" / ".join(requirements))
	var has_skill=false;var explained_skills: Array[String]=[]
	for grant in preload("res://equipment_grants.gd").list(gear):
		has_skill=true;var id=str(grant.id)
		var supplied=int(grant.get("level",1))
		var name_=str(context.get("names",{}).get(id,id))
		var campaign={"skillDefinitions":context.get("definitions",{}),"skillNames":context.get("names",{})}
		var copy=preload("res://skill_text.gd");var doc=copy.document(id,name_,supplied,campaign,gear)
		if not doc.effect.is_empty():explained_skills.append(doc.title)
		line("付与スキル："+name_+("Lv%d" % supplied if copy.LEVELLED.has(id) else ""),"[color="+SKILL+"]付与スキル："+escaped(name_)+("Lv%d" % supplied if copy.LEVELLED.has(id) else "")+"[/color]")
		if not doc.classification.is_empty():line("種別："+("パッシブ" if doc.classification=="passive" else "アクティブ"))
		if doc.cost!=null and doc.classification!="passive":line("消費MP：%d" % doc.cost)
		if not doc.target.is_empty():line("対象："+doc.target)
		if not doc.range.is_empty():line("スキル射程："+doc.range)
		line(copy.body(doc),"[color="+SKILL+"]"+colored_effect(copy.body(doc))+"[/color]")
	if not has_skill:line("付与スキル：なし")
	if not str(gear.get("flavor","")).is_empty():
		line("説明")
		line(str(gear.flavor))
	if gear.has("note") and not str(gear.note).is_empty():
		line("装備メモ（原文）")
		line(str(gear.note))
	if context.get("occupied",false):line("両手装備で使用中（独立した追加装備ではありません）")
	if context.get("job")=="job_porter" and attacks:line("この人物は通常攻撃不可（ポーター）")
	hover_body=equipment_brief(gear,explained_skills)
	tooltip_text=heading+"\n"+"\n".join(plain_details)
func configure_entry(entry: Dictionary,campaign: Dictionary):
	connect_hover();close_hover()
	var gear: Dictionary=entry.get("definition",{})
	if entry.get("kind")=="equipment":
		configure(str(entry.name),gear,{"names":campaign.get("skillNames",{}),"definitions":campaign.get("skillDefinitions",{}),"descriptions":campaign.get("skillDescriptions",{})})
	else:
		heading=str(entry.name);details.clear();plain_details.clear()
		if gear.has("resource"):line(preload("res://item_menu.gd").effect(gear))
		if gear.has("battleRole"):line("戦闘での使用条件："+("ポーター" if gear.battleRole=="job_porter" else str(gear.battleRole)))
		line(str(gear.get("note",gear.get("description","依頼に関わる所持品" if entry.get("kind")=="quest" else "使用時に1個消費"))))
		tooltip_text=heading+"\n"+"\n".join(plain_details)
		var points: Array[String]=[]
		if gear.has("resource"):points.append(preload("res://item_menu.gd").effect(gear))
		if gear.get("weight",entry.get("weight"))!=null:points.append(weight_text(gear.get("weight",entry.get("weight"))))
		hover_body="\n".join(points)
func detail_document(entry: Dictionary) -> Dictionary:
	var doc=preload("res://skill_text.gd").document("",str(entry.name),1,{})
	doc.window_title="所持品の説明";doc.summary_text="装備" if entry.get("kind")=="equipment" else "所持品"
	var note_index=plain_details.find("装備メモ（原文）")
	var flavor_index=plain_details.find("説明") if entry.get("kind")=="equipment" and not str(entry.get("definition",{}).get("flavor","")).is_empty() else -1
	if flavor_index>=0 and (note_index<0 or flavor_index<note_index):note_index=flavor_index
	doc.body_text="\n".join(plain_details.slice(0,note_index) if note_index>=0 else plain_details)
	return doc
