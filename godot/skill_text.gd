extends RefCounted
## Read-only presentation of existing descriptions. No legality or damage rules.
const LEVELLED=["skill_ambush","skill_snipe","skill_item_use","skill_leg_sweep","skill_secret_pouch","skill_hole_pouch"]
static func legacy(name_: String,stage:=1) -> String:
 return {
  "かばう":"かばう: 隣接する自分以外の味方を、次の本人の番まで肩代わり。MP1",
  "ヒール":"ヒール: 射程2の傷ついた味方/自分のHPを60回復（最大HPまで）。MP1",
  "スナイプ":"スナイプ: その一撃だけ各武器の射程+1、届くATK合算。MP1",
  "スタンプ":"スタンプ: 右隣と、その上下の計3マスを指定。次の本人の行動で指定マスの敵へ通常威力。対象を追尾せず、構え開始時にMP1を消費し、中断しても戻らない。使用後は次の本人の行動1回再使用不可。",
  "奇襲":"奇襲Lv%d: " % stage+("前方のみ（味方は右、敵は左）" if stage==1 else "同じ横列の左右" if stage==2 else "上下左右の直線")+"。遮るキャラなしで手前に着地+距離1の通常攻撃。MP1",
  "陣形強化":"陣形強化: 味方全員が対象（陣形の3マス外も含む）。護送陣が成立している間だけ、通常の攻撃×1.5／被ダメージ×0.75を、攻撃×1.75／被ダメージ×0.65に置き換えます。効果は使用者の次の番まで。陣形が崩れている間は適用されず、重ねても倍率は加算されません。MP1・1行動。",
  "侵入":"敵陣侵入を許可。ポーターは侵入不可。"
 }.get(name_,"")
static func description(id: String,level: int,campaign: Dictionary) -> String:
 if id=="skill_snipe":return "スナイプLv%d：その一撃だけ各武器の射程+%s。届く武器のATKを合算して通常威力。MP%d。" % [level,str([1,1.5,2][clampi(level-1,0,2)]),2 if level>=3 else 1]
 if id=="skill_ambush":return legacy("奇襲",level).replace("MP1","MP2" if level>=3 else "MP1")
 if id in ["skill_secret_pouch","skill_hole_pouch"]:return "異なる種類の品物を持てるインベントリ枠を%d%s。" % [[1,3,5][clampi(level-1,0,2)],"減らす" if id=="skill_hole_pouch" else "増やす"]
 if id=="skill_invasion":return "敵陣へ移動できる。ポーターは対象外。"
 if id=="skill_item_use":return "バトル中にもアイテムを使用できる。拳Lv%d：%s。本人の所持品1個・MP0・1行動。" % [level,["自分のみ","自分と縦横隣接の味方","距離制限なしの味方"][clampi(level-1,0,2)]]
 if id=="skill_leg_sweep":return "足払いLv%d：周囲8マスの敵にそれぞれ%d%%で次の1手番をスキップ（重複なし）。ダメージ0・MP1。" % [level,[50,75,100][clampi(level-1,0,2)]]
 var definition=campaign.get("skillDefinitions",{}).get(id,{})
 return str(definition.description) if definition.has("description") else legacy(str(campaign.get("skillNames",{}).get(id,id)),level)
static func classification(id: String,definition: Dictionary) -> String:
 if definition.has("classification"):return str(definition.classification)
 if id=="skill_invasion":return "passive"
 return "active" if id in ["skill_cover","skill_heal","skill_snipe","skill_stamp","skill_ambush","skill_formation_boost"] else ""
static func range_text(id: String,gear: Dictionary,definition: Dictionary,passive: bool,level:=1) -> String:
 if passive:return "該当なし（パッシブ）"
 if id=="skill_leg_sweep":return "周囲8マス（斜めを含む）"
 if id=="skill_item_use":return ["自分のみ","自分と縦横隣接の味方","距離制限なしの味方"][clampi(level-1,0,2)]
 if id=="skill_ambush":return ["前方（味方は右、敵は左）・距離制限なし","同じ横列の左右・距離制限なし","上下左右の直線・距離制限なし"][clampi(level-1,0,2)]
 if id=="skill_return_home":return "距離制限なし（自陣の空きマス）"
 # 射程の概念がないため偽の射程を表示しない（対象は陣形の内外を問わず味方全員）。
 if id=="skill_formation_boost":return ""
 if definition.get("reach")!=null:return str(definition.reach)
 if id=="skill_snipe":return "各攻撃武器の通常射程+%s" % str([1,1.5,2][clampi(level-1,0,2)])
 return {"skill_cover":"1","skill_heal":"2","skill_stamp":"右側3マス"}.get(id,"")
static func target_text(id: String,definition: Dictionary,level: int) -> String:
 if id=="skill_item_use":return range_text(id,{},definition,false,level)
 return {"skill_cover":"隣接する自分以外の味方1人","skill_snipe":"射程内の敵1人","skill_heal":"傷ついた生存味方1人（自身を含む）","skill_ambush":"敵1人","skill_stamp":"右隣と、その上下の計3マスにいる敵（空マスでも指定可）","skill_formation_boost":"味方全員","skill_return_home":"自陣の空きマス","skill_retreat_slash":"射程内の敵1人","skill_knockback":"射程内の敵1人","skill_pincer":"射程内の敵1人","skill_healing_cross":"生存味方を中心に十字範囲の生存味方","skill_mana_gift":"別の生存味方1人","skill_grapple":"右2マス先の敵または味方","skill_leg_sweep":"使用者自身（中心指定） / 効果対象は周囲8マスの敵"}.get(id,{"pair":"異なる敵2人","upToTwo":"縦横隣接の味方1～2人","cell":"指定マス","self":"自身","unit":"射程・条件を満たす人物"}.get(definition.get("target"),""))
static func document(id: String,title: String,level: int,campaign: Dictionary,gear: Dictionary={},source: String="") -> Dictionary:
 var definition=campaign.get("skillDefinitions",{}).get(id,{})
 var kind=classification(id,definition);var original=description(id,level,campaign) if source.is_empty() else source
 var cost=definition.get("cost")
 if kind=="active" and cost==null:
  var regex=RegEx.new();regex.compile("MP([0-9]+)");var match_=regex.search(original)
  if match_!=null:cost=int(match_.get_string(1))
 var effect=[];var conditions=[];var limits=[]
 var text=original.trim_prefix(title+":").strip_edges()
 for part in text.split("。",false):
  var sentence=part.strip_edges()
  if sentence.is_empty():continue
  if sentence in ["MP0","MP1","MP2","MP0・1行動","MP1・1行動"] and cost!=null:
   if sentence.contains("1行動"):limits.append("1行動")
   continue
  if effect.is_empty():effect.append(sentence);continue
  if sentence.contains("それ以外"):
   for branch in sentence.split("、",false):conditions.append(branch)
  elif ["次の","1戦1回","重複","上限","最初","1行動"].any(func(word):return sentence.contains(word)):limits.append(sentence)
  elif ["場合","なら","いれば","のみ","不可","条件","成立","占有","遮る","塞が","盤外"].any(func(word):return sentence.contains(word)):conditions.append(sentence)
  else:effect.append(sentence)
 if id=="skill_ambush":
  effect=["敵の手前のマスへ移動し、距離1の通常攻撃を行う。"]
  conditions=["敵との間に他のキャラクターがいない場合に使用できる。"]
 return {"title":title+("Lv%d" % level if LEVELLED.has(id) and not title.contains("Lv") else ""),"classification":kind,"cost":cost,"target":target_text(id,definition,level),"range":range_text(id,gear,definition,kind=="passive",level),"effect":effect,"conditions":conditions,"limits":limits,"original":original}
static func summary(doc: Dictionary) -> String:
 var lines=[]
 if not doc.classification.is_empty():lines.append("種別: "+("パッシブ" if doc.classification=="passive" else "アクティブ"))
 if doc.cost!=null and doc.classification!="passive":lines.append("消費MP: %d" % doc.cost)
 return "\n".join(lines)
static func body(doc: Dictionary) -> String:
 var blocks=["スキル効果:\n"+("\n".join(doc.effect) if not doc.effect.is_empty() else "説明は登録されていません。")]
 var scope=[]
 if not doc.target.is_empty():scope.append("対象: "+doc.target)
 if not doc.range.is_empty():scope.append("射程・範囲: "+doc.range)
 if not scope.is_empty():blocks.push_front("\n".join(scope))
 if not doc.conditions.is_empty():blocks.append("条件・付随効果:\n"+"\n".join(doc.conditions))
 if not doc.limits.is_empty():blocks.append("持続・回数・上限:\n"+"\n".join(doc.limits))
 return "\n\n".join(blocks)
static func plain(doc: Dictionary) -> String:return "["+doc.title+"]\n"+summary(doc)+"\n"+body(doc)
