extends RefCounted
## Read-only presentation of existing descriptions. No legality or damage rules.
const LEVELLED=["scout","archer","itemUse","legSweep","secretPouch","holePouch"]
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
 if id=="archer":return "スナイプLv%d：その一撃だけ各武器の射程+%s。届く武器のATKを合算して通常威力。MP%d。" % [level,str([1,1.5,2][clampi(level-1,0,2)]),2 if level>=3 else 1]
 if id=="scout":return legacy("奇襲",level).replace("MP1","MP2" if level>=3 else "MP1")
 if id in ["secretPouch","holePouch"]:return "異なる種類の品物を持てるインベントリ枠を%d%s。" % [[1,3,5][clampi(level-1,0,2)],"減らす" if id=="holePouch" else "増やす"]
 if id=="invasion":return "敵陣へ移動できる。ポーターは対象外。"
 if id=="itemUse":return "バトル中にもアイテムを使用できる。拳Lv%d：%s。本人の所持品1個・MP0・1行動。" % [level,["自分のみ","自分と縦横隣接の味方","距離制限なしの味方"][clampi(level-1,0,2)]]
 if id=="legSweep":return "足払いLv%d：周囲8マスの敵にそれぞれ%d%%で次の1手番をスキップ（重複なし）。ダメージ0・MP1。" % [level,[50,75,100][clampi(level-1,0,2)]]
 var definition=campaign.get("skillDefinitions",{}).get(id,{})
 return str(definition.description) if definition.has("description") else legacy(str(campaign.get("skillNames",{}).get(id,id)),level)
static func classification(id: String,definition: Dictionary) -> String:
 if definition.has("classification"):return str(definition.classification)
 if id=="invasion":return "passive"
 return "active" if id in ["guard","mage","archer","stamp","scout","porter"] else ""
static func range_text(id: String,gear: Dictionary,definition: Dictionary,passive: bool,level:=1) -> String:
 if passive:return "該当なし（パッシブ）"
 if id=="legSweep":return "周囲8マス（斜めを含む）"
 if id=="itemUse":return ["自分のみ","自分と縦横隣接の味方","距離制限なしの味方"][clampi(level-1,0,2)]
 if id=="scout":return "距離制限なし（装備Lvの方向・経路条件あり）"
 if id=="returnHome":return "距離制限なし（自陣の空きマス）"
 if id=="porter":return "成立中の陣形・味方全員"
 if definition.get("reach")!=null:return str(definition.reach)
 if id=="archer":return "各攻撃武器の通常射程+%s" % str([1,1.5,2][clampi(level-1,0,2)])
 return {"guard":"1","mage":"2","stamp":"右側3マス"}.get(id,"")
static func target_text(id: String,definition: Dictionary,level: int) -> String:
 if id=="itemUse":return range_text(id,{},definition,false,level)
 return {"guard":"隣接する自分以外の味方1人","archer":"射程内の敵1人","mage":"傷ついた生存味方1人（自身を含む）","scout":"方向・経路条件を満たす敵1人","stamp":"右隣と、その上下の計3マスにいる敵（空マスでも指定可）","porter":"使用者自身を指定・陣形中の味方全員","returnHome":"自陣の空きマス","retreatSlash":"射程内の敵1人","knockback":"射程内の敵1人","pincer":"射程内の敵1人","healingCross":"生存味方を中心に十字範囲の生存味方","manaGift":"別の生存味方1人","grapple":"右2マス先の敵または味方","legSweep":"使用者自身（中心指定） / 効果対象は周囲8マスの敵"}.get(id,{"pair":"異なる敵2人","upToTwo":"縦横隣接の味方1～2人","cell":"指定マス","self":"自身","unit":"射程・条件を満たす人物"}.get(definition.get("target"),""))
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
 return {"title":title+("Lv%d" % level if LEVELLED.has(id) and not title.contains("Lv") else ""),"classification":kind,"cost":cost,"target":target_text(id,definition,level),"range":range_text(id,gear,definition,kind=="passive",level),"effect":effect,"conditions":conditions,"limits":limits,"original":original}
static func summary(doc: Dictionary) -> String:
 var lines=[]
 if not doc.classification.is_empty():lines.append("種別: "+("パッシブ" if doc.classification=="passive" else "アクティブ"))
 if doc.cost!=null and doc.classification!="passive":lines.append("消費MP: %d" % doc.cost)
 if not doc.target.is_empty():lines.append("対象: "+doc.target)
 if not doc.range.is_empty():lines.append("射程・範囲: "+doc.range)
 return "\n".join(lines)
static func body(doc: Dictionary) -> String:
 var blocks=["スキル効果:\n"+("\n".join(doc.effect) if not doc.effect.is_empty() else "説明は登録されていません。")]
 if not doc.conditions.is_empty():blocks.append("条件・付随効果:\n"+"\n".join(doc.conditions))
 if not doc.limits.is_empty():blocks.append("持続・回数・上限:\n"+"\n".join(doc.limits))
 return "\n\n".join(blocks)
static func plain(doc: Dictionary) -> String:return "["+doc.title+"]\n"+summary(doc)+"\n"+body(doc)
static func glossary() -> String:
 return "対象と効果範囲\n対象は指定する人物や中心マスです。実際に効果を受ける範囲は、各スキルの説明と盤面の予告を確認してください。\n\n次の本人の番まで\nかばう・防衛線・陣形強化は、使用者の次の手番が来た時点で解除されます。足払いでその手番をスキップする場合も解除されます。\n\n消費MPと移譲\n魔力譲渡の消費MPは0ですが、渡したMPは使用者の残量から減ります。渡す量は相手の空き分までで、総量は増えません。\n\n拳とアイテム\n拳は空いた手にある仮想装備です。片手でも拳ならバトル中にもアイテムを使用できます。バトル外では両手が塞がっていても使用でき、本人の所持品を1個使います。"
