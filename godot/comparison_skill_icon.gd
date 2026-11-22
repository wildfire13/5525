extends "res://compact_hover_button.gd"
const Copy=preload("res://skill_text.gd")

static func bind_hover(button: Button,id: String,title: String,level: int,campaign: Dictionary,gear: Dictionary={}):
	button.set_script(load("res://comparison_skill_icon.gd"))
	button.configure_skill(Copy.document(id,title,level,campaign,gear))

func configure_skill(doc: Dictionary):
	connect_hover();close_hover()
	heading=doc.title
	tooltip_text=Copy.plain(doc)
	var points: Array[String]=[]
	if not doc.effect.is_empty():
		var original: String=doc.original
		var prose=original.trim_prefix(heading+":").trim_prefix(heading+"：").strip_edges()
		if doc.cost!=null:
			var mp="MP%d" % doc.cost
			prose=prose.trim_suffix("。").trim_suffix(mp+"・1行動").trim_suffix(mp)
		if not prose.is_empty():points.append(prose if prose.ends_with("。") else prose+"。")
	if doc.cost!=null and doc.classification!="passive":points.append("消費MP %d" % doc.cost)
	hover_body="\n".join(points)
