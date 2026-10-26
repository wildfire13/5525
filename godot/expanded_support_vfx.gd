extends RefCounted
## Paints committed support/passive outcomes only; never reads or writes game rules.
const ART="res://assets/vfx_expansion/"
const KEYS=["sup_wing","sup_bastion","sup_banner","sup_bloom","sup_ribbon","sup_vessel","sup_fang","sup_stride","sup_breath"]
var fx
func _init(layer):
 fx=layer
 for key in KEYS:
  var path=ART+key+".png"
  if ResourceLoader.exists(path):fx.textures[key]=load(path)
func supports(event: Dictionary) -> bool:
 var skill=str(event.get("skill_id",""));var phase=str(event.get("phase",""))
 if skill=="guard":return event.get("kind","")!="guard" and phase=="action"
 if skill in ["defenseLine","porter","healingCross","manaGift"]:return phase in ["action","heal","resource"]
 if skill in ["item","ether"]:return phase in ["heal","resource"]
 return skill in ["loneWolf","firstStride","victoryBreath"] and (phase=="passive" or (skill=="victoryBreath" and phase=="resource"))
func duration(event: Dictionary) -> float:
 return (.26 if event.get("phase")=="action" else .46) if event.get("skill_id")=="manaGift" else .38 if event.get("phase")=="passive" else .52
func _valid(cell: int) -> bool:return cell>=0 and cell<50
func _rows(event: Dictionary) -> Array:
 var rows=[];var seen=[]
 for row in event.get("resolved_support",[]):
  var cell=int(row.get("cell",-1))
  if row.get("success",false) and _valid(cell) and not seen.has(cell):rows.append(row);seen.append(cell)
 return rows
func _art(key: String,cell: int,offset: Vector3,size: Vector2,life: float,delay:=0.0,ground:=false,tag:="") -> Dictionary:
 var row=fx._quad(key,cell,offset,size,life,delay,ground,tag)
 if not row.is_empty():row.opacity=.76
 return row
func _link(key: String,origin: int,target: int,height: float,width: float,delay:=0.0):
 if not _valid(origin) or not _valid(target) or origin==target:return
 var from=fx.board().point(origin)+Vector3(0,height,0);var to=fx.board().point(target)+Vector3(0,height,0)
 var screen=fx.board().project(to)-fx.board().project(from)
 # Orient in the same camera plane used by the host's billboard processor.
 var delta=to-from;var camera=fx.board().world.camera
 var span=Vector2(delta.dot(camera.global_basis.x),delta.dot(camera.global_basis.y)).length()
 var row=_art(key,origin,Vector3(0,height,0)+delta*.5,Vector2(span,width),.36,delay,false,"support_link")
 if not row.is_empty():row.angle=screen.angle();row.opacity=.40
func _petals(cell: int,key: String,count: int,height:=.36,delay:=0.0):
 for i in range(count):
  var a=float(i)*2.399
  var row=_art(key,cell,Vector3(cos(a)*.18,height+float(i%2)*.11,sin(a)*.09),Vector2(.12,.13),.36,delay+float(i)*.025,false,"support_particle")
  if not row.is_empty():row.travel=Vector3(cos(a)*.15,.30+float(i%2)*.12,sin(a)*.12);row.angle=a;row.opacity=.63
func play(event: Dictionary):
 if not supports(event):return
 var skill=str(event.get("skill_id",""));var phase=str(event.get("phase",""));var origin=int(event.get("origin",-1));var cell=int(event.get("recipient",-1))
 if skill=="guard":
  for result in _rows(event).filter(func(row):return row.get("status","")=="cover").slice(0,1):
   var target=int(result.cell)
   var wing=_art("sup_wing",target,Vector3(.36,.88,.06),Vector2(1.00,1.15),.48,0,false,"support_wing")
   if not wing.is_empty():wing.travel=Vector3(-.10,.10,0)
   _link("sup_ribbon",origin,target,.46,.065,.06)
   _petals(target,"sup_bastion",2,.36,.08)
 elif skill=="defenseLine":
  var previous=origin
  for result in _rows(event).filter(func(row):return row.get("status","")=="covers").slice(0,2):
   var target=int(result.cell)
   var pillar=_art("sup_bastion",target,Vector3(0,.64,.04),Vector2(.82,1.10),.46,.03,false,"support_bastion")
   if not pillar.is_empty():pillar.travel=Vector3(0,.13,0)
   _link("sup_bastion",previous,target,.16,.10,.08);previous=target
 elif skill=="porter":
  var boosts=_rows(event).filter(func(row):return row.get("status","")=="boost")
  if boosts.is_empty():return
  for value in event.get("cells",[]).slice(0,6):
   var target=int(value)
   if not _valid(target):continue
   var banner=_art("sup_banner",target,Vector3(.48,.48 if target==origin else .08,0),Vector2(.86,.55) if target==origin else Vector2(.50,.32),.46,.04,false,"support_formation")
   if not banner.is_empty():banner.sprite_anchor=true;banner.opacity=.76 if target==origin else .58
   _petals(target,"sup_banner",1,.32,.10)
 elif skill=="healingCross":
  if phase=="action":
   # Canonical affected cells are supplied by the presentation; no radius inference.
   for target in event.get("cells",[]).slice(0,5):
    if not _valid(int(target)):continue
    var flower=_art("sup_bloom",int(target),Vector3(0,.085,0),Vector2(.85,.85),.44,.04,true,"support_cross_cast")
    if not flower.is_empty():flower.opacity=.35;fx._mask(flower,[int(target)])
  elif phase=="heal" and int(event.get("amount",0))>0:_heal(cell,int(event.amount),false)
 elif skill=="manaGift":
  if phase=="action" and _valid(origin):
   var gathered=_art("sup_ribbon",origin,Vector3(.22,.66,0),Vector2(.40,.18),.24,0,false,"mana_prepare")
   if not gathered.is_empty():gathered.opacity=.56;gathered.travel=Vector3(0,.08,0)
   _petals(origin,"sup_breath",2,.66,.02)
  elif phase=="resource" and event.get("resource")=="mp" and _valid(cell) and _valid(origin) and int(event.get("amount",0))>0:
   var delta=fx.board().point(cell)-fx.board().point(origin)
   var ribbon=_art("sup_ribbon",origin,Vector3(0,.68,0),Vector2(.64,.19),.38,0,false,"projectile")
   if not ribbon.is_empty():ribbon.travel=delta;ribbon.angle=(fx.board().project_cell(cell)-fx.board().project_cell(origin)).angle();ribbon.opacity=.88
   _petals(cell,"sup_ribbon",3,.64,.20)
   fx._caption(cell,"+%d MP" % int(event.amount),Color("#e5d5ff"),.19,.42)
   var spent=int(event.get("donor_amount",0))
   if spent<0:
    var donor_name=""
    for unit in fx.board().data.get("state",{}).get("units",[]):
     if str(unit.id)==str(event.get("actor_id","")):donor_name=str(unit.get("name",""));break
    fx._caption(origin,donor_name+" %d MP" % spent,Color("#c9bce9"),0,.38,{"height":-.10,"drift":-.04,"font_size":17})
 elif skill in ["item","ether"]:
  if phase in ["heal","resource"] and int(event.get("amount",0))>0:_heal(cell,int(event.amount),phase=="resource",true)
 elif skill=="victoryBreath" and phase=="resource":
  if event.get("resource")=="mp" and _valid(cell) and int(event.get("amount",0))>0:
   _breath(cell)
   fx._caption(cell,"+%d MP" % int(event.amount),Color("#e5d5ff"),.06,.43)
 elif phase=="passive" and event.has("sequence"):
  if skill=="loneWolf" and _valid(origin):
   var fang=_art("sup_fang",origin,Vector3(.32,.72,.06),Vector2(.66,.62),.24,0,false,"support_lone_fang")
   if not fang.is_empty():fang.fast=true;fang.travel=Vector3(.12,.08,0)
  elif skill=="firstStride" and _valid(origin):
   for i in range(2):
    var wind=_art("sup_stride",origin,Vector3(0,.07+float(i)*.015,0),Vector2(.74,.56),.34,float(i)*.07,true,"support_stride")
    if not wind.is_empty():wind.follow_id=str(event.get("actor_id",""));wind.angle=float(i)*PI;wind.opacity=.55
  elif skill=="victoryBreath" and _valid(cell):_breath(cell)
func _breath(cell: int):
 var breath=_art("sup_breath",cell,Vector3(.25,1.02,0),Vector2(.51,.39),.40,0,false,"support_breath")
 if not breath.is_empty():breath.travel=Vector3(.16,.24,0)
func _heal(cell: int,amount: int,mana: bool,item:=false):
 if not _valid(cell) or amount<=0:return
 var key="sup_ribbon" if mana else "sup_bloom"
 var art=_art(key,cell,Vector3(.24,.60,.02),Vector2(.65,.53),.42,.04,false,"support_recovery")
 if not art.is_empty():art.travel=Vector3(0,.20,0)
 if item:
  var vessel=_art("sup_vessel",cell,Vector3(-.34,.44,0),Vector2(.36,.38),.33,0,false,"support_vessel")
  if not vessel.is_empty():vessel.opacity=.65
 _petals(cell,key,3,.40,.06)
 fx._caption(cell,"+%d MP" % amount if mana else "+%d" % amount,Color("#e5d5ff") if mana else Color("#d7f9cc"),.04,.48)
