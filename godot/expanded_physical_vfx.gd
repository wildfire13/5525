extends RefCounted
## Presentation-only physical skills. Move packets alone create movement trails;
## hurt packets alone create contacts and damage captions. No gameplay writes/RNG.
const SKILLS=["archer","scout","grapple","poleVault","retreatSlash","knockback","splitShot","pincer","returnHome"]
const ASSETS=["phys_arrow","phys_afterimage","phys_hook","phys_rise","phys_dust","phys_curl","phys_wedge","phys_fork_upper","phys_fork_lower","phys_gate"]
var fx
func _init(layer):
 fx=layer
 for key in ASSETS:
  var path="res://assets/vfx_expansion/"+key+".png"
  if ResourceLoader.exists(path):fx.textures[key]=load(path)
func supports(event: Dictionary) -> bool:
 return str(event.get("skill_id","")) in SKILLS and str(event.get("phase","")) in ["action","move","hurt"]
func duration(event: Dictionary) -> float:
 if event.get("phase")=="move":return .30
 if event.get("phase")=="hurt":return .24
 return .40 if event.get("skill_id") in ["splitShot","grapple"] else .32
func _valid(cell: int) -> bool:return cell>=0 and cell<50
func _point(cell: int) -> Vector3:return fx.board().point(cell)
func _direction(a: int,b: int) -> Vector3:
 return (_point(b)-_point(a)).normalized() if _valid(a) and _valid(b) else Vector3.ZERO
func _angle(a: int,b: int) -> float:
 if not _valid(a) or not _valid(b):return 0.0
 return (fx.board().project(_point(b))-fx.board().project(_point(a))).angle()
func _quad(key: String,cell: int,height: float,dims: Vector2,life: float,delay:=0.0,ground:=false,tag:="") -> Dictionary:
 return fx._quad(key,cell,Vector3(0,height,0),dims,life,delay,ground,tag)
func _dust(cell: int,direction: Vector3,delay:=0.0):
 var row=_quad("phys_dust",cell,.07,Vector2(.85,.38),.24,delay,true,"physical_dust")
 if row.is_empty():return
 row.opacity=.43;row.travel=direction*.18;row.angle=atan2(direction.x,direction.z);fx._mask(row,[cell])
func _launch(key: String,origin: int,target: int,delay: float,intrinsic:=0.0):
 if not _valid(origin) or not _valid(target):return
 var row=_quad(key,origin,.80,Vector2(.95,.29),.24,delay,false,"projectile")
 if row.is_empty():return
 row.travel=_point(target)-_point(origin);row.angle=_angle(origin,target)-intrinsic;row.opacity=.92
func _blade(cell: int,angle: float,delay:=0.0,flip:=false) -> Dictionary:
 var row=_quad("phys_curl",cell,.72,Vector2(.73,.86),.23,delay,false,"physical_blade")
 if not row.is_empty():row.angle=angle;row.flip=flip;row.opacity=.83
 return row
func _afterimage(cell: int,id: String,angle: float,delay:=0.0):
 var row=_quad("phys_afterimage",cell,.55,Vector2(.61,.85),.27,delay,false,"physical_afterimage")
 if row.is_empty():return
 row.opacity=.34;row.angle=angle;row.follow_id=id
 row.offset+=fx.board().world.camera.global_basis.x*-.16
func _targets(event: Dictionary) -> Array:
 var result=[]
 var resolved=event.get("resolved",{})
 if resolved is Dictionary:
  for row in resolved.get("targets",[]):
   var cell=int(row.get("cell",row.get("target_cell",-1))) if row is Dictionary else int(row)
   if _valid(cell) and not result.has(cell):result.append(cell)
 if result.is_empty():
  for cell in event.get("cells",[]):
   if _valid(int(cell)) and not result.has(int(cell)):result.append(int(cell))
 if result.is_empty() and _valid(int(event.get("recipient",-1))):result.append(int(event.recipient))
 return result
func play(event: Dictionary):
 if not supports(event):return
 var phase=str(event.get("phase",""))
 if phase=="hurt":_hurt(event)
 elif phase=="move":_move(event)
 else:_action(event)
func _action(event: Dictionary):
 var skill=str(event.skill_id);var origin=int(event.get("origin",-1));var target=int(event.get("recipient",-1))
 if not _valid(origin):return
 var angle=_angle(origin,target)
 match skill:
  "archer":
   _launch("phys_arrow",origin,target,.035)
   var glint=_quad("phys_wedge",origin,.83,Vector2(.22,.14),.12,0,false,"snipe_release")
   if not glint.is_empty():glint.opacity=.48;glint.angle=angle
  "splitShot":
   var targets=_targets(event)
   for i in range(mini(2,targets.size())):
    _launch("phys_fork_upper" if i==0 else "phys_fork_lower",origin,int(targets[i]),float(i)*.11,-.40 if i==0 else .36)
  "grapple":
   if not _valid(target):return
   var delta=_point(target)-_point(origin)
   var rope=_quad("phys_hook",origin,.63,Vector2(delta.length()*1.18,.31),.34,.025,false,"grapple_tension")
   if not rope.is_empty():rope.offset+=delta*.5;rope.angle=angle+PI;rope.opacity=.85
  "scout":
   # Activation folds remain at the caster; only the real move phase follows them.
   var fold=_quad("phys_afterimage",origin,.54,Vector2(.54,.78),.23,0,false,"ambush_prepare")
   if not fold.is_empty():fold.opacity=.38;fold.angle=angle*.10
  "poleVault":
   var rise=_quad("phys_rise",origin,.66,Vector2(.46,1.0),.27,0,false,"vault_prepare")
   if not rise.is_empty():rise.opacity=.72;rise.flip=cos(angle)<0
  "retreatSlash":_blade(target if _valid(target) else origin,angle+.40)
  "knockback":
   var wedge=_quad("phys_wedge",origin,.66,Vector2(.27,.25),.17,0,false,"push_prepare")
   if not wedge.is_empty():wedge.angle=angle;wedge.opacity=.47
  "pincer":
   # A single initiating blade does not imply a successful cooperative strike.
   _blade(target if _valid(target) else origin,angle-.45,0,false)
  "returnHome":
   var gate=_quad("phys_gate",origin,.62,Vector2(.65,1.18),.26,0,false,"home_departure")
   if not gate.is_empty():gate.opacity=.61
func _hurt(event: Dictionary):
 if int(event.get("amount",0))>=0:return
 var cell=int(event.get("recipient",-1));var origin=int(event.get("origin",-1))
 if not _valid(cell):return
 var skill=str(event.skill_id);var angle=_angle(origin,cell)
 var contact=_quad("phys_wedge",cell,.79,Vector2(.44,.29) if skill=="archer" else Vector2(.57,.44),.17,0,false,"physical_contact")
 if not contact.is_empty():contact.angle=angle;contact.fast=true;contact.opacity=.92
 if skill=="scout":
  # Short blade behind the actual hurt recipient, independent of activation.
  var tip=_quad("phys_arrow",cell,.69,Vector2(.43,.16),.15,0,false,"ambush_tip")
  if not tip.is_empty():tip.angle=angle;tip.opacity=.84;tip.offset-=_direction(origin,cell)*.15
 elif skill=="pincer":
  var resolved=event.get("resolved",{})
  if resolved is Dictionary and resolved.get("pincer_success",false):
   var second_angle=angle+PI
   for helper in resolved.get("pincer_helpers",[]):
    if helper is Dictionary and _valid(int(helper.get("cell",-1))):
     second_angle=_angle(int(helper.cell),cell);break
   _blade(cell,second_angle+.45,.015,true)
 fx._react(str(event.get("recipient_id","")),"stumble",0,.17,_direction(origin,cell))
 fx._caption(cell,str(int(event.amount)),Color("#ffebd7"),0,.34)
func _move(event: Dictionary):
 # Canonical from/to are supplied only after the engine has committed a move.
 var origin=int(event.get("move_from",event.get("origin",-1)))
 var target=int(event.get("move_to",event.get("recipient",-1)))
 if not _valid(origin) or not _valid(target) or origin==target:return
 var skill=str(event.skill_id);var id=str(event.get("recipient_id",event.get("actor_id","")))
 var direction=_direction(origin,target);var angle=_angle(origin,target)
 match skill:
  "scout":
   _afterimage(origin,id,angle*.08)
   _dust(origin,-direction)
  "grapple":
   _dust(origin,-direction)
   var tension=_quad("phys_hook",target,.51,Vector2(.56,.23),.17,0,false,"grapple_reel")
   if not tension.is_empty():tension.angle=angle+PI;tension.opacity=.61;tension.follow_id=id
  "poleVault":
   var rise=_quad("phys_rise",origin,.51,Vector2(.43,.95),.25,0,false,"vault_lift")
   if not rise.is_empty():rise.opacity=.60;rise.follow_id=id;rise.flip=cos(angle)<0
   _dust(target,direction,.20)
  "retreatSlash":
   _dust(origin,-direction)
   var curl=_blade(origin,angle,.04,true)
   if not curl.is_empty():curl.offset.y=.24;curl.opacity=.38;curl.follow_id=id
  "knockback":
   var push=_quad("phys_wedge",origin,.29,Vector2(.46,.30),.23,0,false,"push_trail")
   if not push.is_empty():push.angle=angle;push.opacity=.48;push.follow_id=id
   _dust(target,direction,.20)
  "returnHome":
   for cell in [origin,target]:
    var gate=_quad("phys_gate",cell,.59,Vector2(.66,1.12),.25,.0 if cell==origin else .17,false,"home_fold")
    if not gate.is_empty():gate.opacity=.55;gate.flip=cell==origin
   _dust(target,-direction,.22)
