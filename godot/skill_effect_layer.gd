extends Control
## Painted graphics in the actual 3D world; result text stays below the HP UI.
## Transient emitters never call the engine, save settings, or use gameplay RNG.
const ART="res://assets/vfx_production/"
var board_ref: WeakRef
var _event: Dictionary={}
var _elapsed:=0.0
var _duration:=0.0
var legacy: Control
var stage: Node3D
var textures={}
var emitters: Array=[]
var captions: Array=[]
var reactions: Array=[]
var serial:=0
var _last_action=""
const PAINT=preload("res://shaders/vfx_painted.gdshader")
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_mode=Control.FOCUS_NONE
 legacy=preload("res://legacy_skill_effect_layer.gd").new();legacy.board_ref=board_ref;add_child(legacy);legacy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 stage=Node3D.new();stage.name="PaintedSkillVfx";board_ref.get_ref().world.add_child(stage)
 for key in ["sweep_arc","sweep_dust","sweep_shard","heal_veil","heal_shard","heal_core","guard_plate","guard_reflection","guard_shard","pose_crouch","pose_sweep","impact_contact","attack_blade","attack_projectile","stamp_fall","stamp_impact","stamp_rubble","pose_stamp_lift","pose_stamp_slam"]:
  var path=ART+key+".png"
  if ResourceLoader.exists(path):textures[key]=load(path)
 set_process(false)
 _warm_material.call_deferred()
func _warm_material():
 # Compile the shared material during the existing loading frames, never on hit.
 var mesh=MeshInstance3D.new();mesh.name="VfxMaterialWarmup";var quad=QuadMesh.new();quad.size=Vector2(.01,.01);mesh.mesh=quad
 var mat=ShaderMaterial.new();mat.shader=PAINT;mat.set_shader_parameter("art",textures.sweep_arc);mat.set_shader_parameter("opacity",0.0);mesh.material_override=mat
 mesh.position=board().point(24)+Vector3(0,.1,0);stage.add_child(mesh)
 await get_tree().process_frame
 await get_tree().process_frame
 if is_instance_valid(mesh):mesh.queue_free()
func board():return board_ref.get_ref() if board_ref!=null else null
func _shield_outline(cell: int) -> PackedVector2Array:
 return legacy._shield_outline(cell) # Kind-less legacy packets keep their original geometry.
func _valid_cell(cell: int) -> bool:return cell>=0 and cell<50
func phase_duration(event: Dictionary) -> float:
 var skill=event.get("skill_id","");var phase=event.get("phase","")
 if skill=="legSweep" and phase=="action":return .76
 if skill=="mage":return .36 if phase=="action" else .58
 if skill=="guard" and phase=="action" and event.get("kind")=="guard":return .58
 if skill=="stamp":return .34 if phase=="action" else .24
 if skill=="attack" and phase=="action":return .30
 if phase=="hurt" and (event.get("guarding",false) or event.get("redirected",false)):return .3
 if phase=="hurt" and skill=="impact":return .20
 return .3 if phase=="heal" else .42
func is_painted(event: Dictionary) -> bool:
 return event.get("skill_id") in ["legSweep","mage","stamp","attack","impact"] or (event.get("skill_id")=="guard" and event.get("kind")=="guard")
func snapshot() -> Dictionary:
 return {"active":not _event.is_empty(),"event":_event.duplicate(true),"elapsed":_elapsed,"duration":_duration,"progress":clampf(_elapsed/_duration,0,1) if _duration>0 else 0.0,"emitter_count":emitters.size(),"caption_count":captions.size(),"texture_count":textures.size()}
func end_phase():
 _event={};_elapsed=0;_duration=0
 if is_instance_valid(legacy):legacy.clear()
func clear():
 end_phase()
 for row in emitters:
  if is_instance_valid(row.node):row.node.queue_free()
 emitters.clear();captions.clear()
 for row in reactions:_restore_actor(row)
 reactions.clear();_last_action="";set_process(false);queue_redraw()
func _exit_tree():
 if is_instance_valid(stage):stage.queue_free()
func play(event: Dictionary,duration: float):
 end_phase()
 if not is_finite(duration) or duration<=0:return
 var skill=str(event.get("skill_id",""));var phase=str(event.get("phase",""))
 if not ((phase=="action" and skill in ["legSweep","mage","stamp","attack","guard"]) or (phase=="heal" and skill=="mage") or (phase=="hurt" and skill in ["stamp","impact"])):return
 if not _valid_cell(int(event.get("origin",-1)) if phase=="action" else int(event.get("recipient",-1))):return
 _event=event.duplicate(true);_event.cells=[]
 for value in event.get("cells",[]):
  if (value is int or value is float) and _valid_cell(int(value)) and not (skill=="legSweep" and int(value)==int(event.origin)) and not _event.cells.has(int(value)):_event.cells.append(int(value))
 event=_event
 _elapsed=0;_duration=duration;serial+=1
 if not is_painted(event):legacy.play(event,duration)
 else:
  if phase=="action":
   if skill=="legSweep":_sweep(event)
   elif skill=="mage":_heal_cast(event)
   elif skill=="guard":_guard(event,false)
   elif skill=="attack":_attack(event)
   elif skill=="stamp":_stamp_cast(event)
  elif phase=="heal":_heal_result(event)
  elif phase=="hurt":
   if skill=="stamp":_stamp_result(event)
   elif event.get("guarding",false) or event.get("redirected",false):_guard(event,true)
   else:_impact(event)
 set_process(true);_process(0.0);queue_redraw()
func _envelope(t: float) -> float:return smoothstep(0,.17,t)*(1-smoothstep(.52,1,t))
func _quad(key: String,cell: int,offset: Vector3,dims: Vector2,life: float,delay:=0.0,ground:=false,tag:="") -> Dictionary:
 if not textures.has(key) or not _valid_cell(cell):return {}
 if emitters.size()>=64:return {}
 var node=MeshInstance3D.new();node.name="Vfx_"+key
 var mesh=QuadMesh.new();mesh.size=dims;mesh.subdivide_width=8;mesh.subdivide_depth=8;node.mesh=mesh
 var mat=ShaderMaterial.new();mat.shader=PAINT;mat.set_shader_parameter("art",textures[key]);node.material_override=mat
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;stage.add_child(node)
 var row={"node":node,"material":mat,"key":key,"cell":cell,"offset":offset,"dims":dims,"life":life,"age":-delay,"ground":ground,"tag":tag,"opacity":1.0,"angle":0.0,"travel":Vector3.ZERO,"scale_from":Vector2.ONE,"scale_to":Vector2.ONE,"fast":false,"action_id":_event.get("action_id","")}
 node.visible=false;emitters.append(row);return row
func _mask(row: Dictionary,cells: Array):
 if row.is_empty():return
 var allowed=PackedFloat32Array();allowed.resize(50)
 for cell in cells:
  if _valid_cell(int(cell)):allowed[int(cell)]=1
 row.material.set_shader_parameter("ground_masked",true);row.material.set_shader_parameter("allowed_cells",allowed)
func _caption(cell: int,text: String,color: Color,delay: float,life: float):
 if captions.size()>=16:return
 captions.append({"cell":cell,"text":text,"color":color,"age":-delay,"life":life})
func _sweep(event: Dictionary):
 var cell=int(event.origin);var cells=event.get("cells",[])
 var arc=_quad("sweep_arc",cell,Vector3(0,.065,0),Vector2(4.1,4.1),.48,.13,true,"sweep")
 if not arc.is_empty():arc.opacity=.82;arc.angle=-1.4;_mask(arc,cells)
 var caster_dust=_quad("sweep_dust",cell,Vector3(0,.07,0),Vector2(.95,.7),.28,0,true)
 if not caster_dust.is_empty():caster_dust.opacity=.28
 for i in range(cells.size()):
  var c=int(cells[i]);var direction=(board().point(c)-board().point(cell)).normalized()
  var dust=_quad("sweep_dust",c,Vector3(0,.045,0),Vector2(.85,.7),.43,.24+float(i%3)*.02,true)
  if not dust.is_empty():dust.opacity=.34;dust.travel=direction*.28;dust.angle=float(i)*1.71;_mask(dust,[c])
 for status in event.get("resolved_status",[]):
  if not status.get("success",false):continue
  var c=int(status.get("cell",-1))
  if not cells.has(c):continue
  var contact=_quad("sweep_shard",c,Vector3(0,.11,0),Vector2(.64,.44),.18,.28,true)
  if not contact.is_empty():contact.fast=true;contact.opacity=.74;_mask(contact,[c])
  _caption(c,"手番スキップ",Color("#f3dfb1"),.3,.43)
  _react(str(status.unit_id),"stumble",.29,.21,(board().point(c)-board().point(cell)).normalized())
 _react(str(event.get("actor_id","")),"sweep_pose",0,.76)
func _heal_cast(event: Dictionary):
 var caster=_quad("heal_core",int(event.origin),Vector3(.22,1.0,0),Vector2(.48,.48),.25,0,false,"caster")
 if not caster.is_empty():caster.opacity=.75
 var cell=int(event.get("recipient",-1))
 if not _valid_cell(cell):return
 var veil=_quad("heal_veil",cell,Vector3.ZERO,Vector2(1.3,1.9),.91,.12,false,"veil")
 if not veil.is_empty():veil.opacity=.64;veil.travel=Vector3(0,.14,0);veil.sprite_anchor=true
 for side in [-1.0,1.0]:
  var front=_quad("heal_veil",cell,Vector3(side*.5,0,0),Vector2(.58,1.68),.72,.20 if side<0 else .24,false,"veil_front")
  if not front.is_empty():
   front.opacity=.44;front.travel=Vector3(-side*.07,.13,0);front.sprite_anchor=true
   front.material.set_shader_parameter("uv_rect",Vector4(0 if side<0 else .5,0,.5,1))
func _heal_result(event: Dictionary):
 var cell=int(event.recipient)
 var core=_quad("heal_core",cell,Vector3(0,.8,0),Vector2(.85,1.0),.3,0,false,"heal_peak")
 if not core.is_empty():core.fast=true;core.opacity=.67
 if not emitters.any(func(row):return row.tag=="veil" and row.action_id==event.get("action_id")):
  var veil=_quad("heal_veil",cell,Vector3.ZERO,Vector2(1.3,1.9),.55,0,false,"veil")
  if not veil.is_empty():veil.opacity=.64;veil.travel=Vector3(0,.14,0);veil.sprite_anchor=true
 for i in range(6):
  var a=float(i)*2.399;var leaf=_quad("heal_shard",cell,Vector3(cos(a)*.35,.25+float(i%3)*.12,sin(a)*.12),Vector2(.18,.28),.55,float(i)*.018,false,"leaf")
  if not leaf.is_empty():leaf.travel=Vector3(sin(a)*.18,.95+float(i%2)*.2,0);leaf.angle=float(i)*.63;leaf.opacity=.85
 var amount=int(event.get("amount",0))
 if amount>0:_caption(cell,"+%d" % amount,Color("#c9ffdc"),0,.58)
func _attack(event: Dictionary):
 var cell=int(event.origin);var target=int(event.get("recipient",-1));var style=str(event.get("attack_style","abstract"))
 _react(str(event.get("actor_id","")),"strike",0,.30,(board().point(target)-board().point(cell)).normalized() if _valid_cell(target) else Vector3.ZERO)
 if not _valid_cell(target):return
 var from=board().point(cell)+Vector3(0,.83,0);var to=board().point(target)+Vector3(0,.83,0)
 var screen=board().project(to)-board().project(from)
 if style in ["sword","dagger","greatsword"]:
  var blade=_quad("attack_blade",target,Vector3(0,.92,0),Vector2(1.06,.76),.19,.09,false,"blade")
  if not blade.is_empty():blade.angle=screen.angle()+.55;blade.opacity=.83
 elif style in ["bow","staff","spear"]:
  var projectile=_quad("attack_projectile",cell,Vector3(0,.83,0),Vector2(.84,.33),.20,.06,false,"projectile")
  if not projectile.is_empty():
   projectile.travel=to-from;projectile.angle=screen.angle();projectile.pivot=Vector2(.838,.505);projectile.opacity=.84
 else:
  # Unknown/enemy weapon packets have no invented slash or successful impact.
  var prep=_quad("heal_core",cell,Vector3(0,.85,0),Vector2(.22,.22),.13,.05,false,"neutral_prepare")
  if not prep.is_empty():prep.opacity=.35
func _impact(event: Dictionary):
 var cell=int(event.recipient)
 var contact=_quad("impact_contact",cell,Vector3(0,.88,0),Vector2(.72,.65),.17,0,false,"contact")
 if not contact.is_empty():contact.pivot=Vector2(.5,.573);contact.fast=true;contact.opacity=.93
 var away=Vector3.ZERO
 if _valid_cell(int(event.get("origin",-1))):away=(board().point(cell)-board().point(int(event.origin))).normalized()
 _react(str(event.get("recipient_id","")),"stumble",0,.17,away)
 var amount=int(event.get("amount",0))
 if amount<0:_caption(cell,str(amount),Color("#ffebd7"),0,.34)
func _stamp_cast(event: Dictionary):
 var center=int(event.get("recipient",-1))
 _react(str(event.get("actor_id","")),"stamp_pose",0,.58,(board().point(center)-board().point(int(event.origin))).normalized() if _valid_cell(center) else Vector3.ZERO)
 if not _valid_cell(center):return
 var fall=_quad("stamp_fall",center,Vector3(0,.72,0),Vector2(.72,1.38),.19,.12,false,"stamp_fall")
 if not fall.is_empty():fall.pivot=Vector2(.5,.882);fall.travel=Vector3(0,-.58,0);fall.opacity=.9;fall.depth_bias=.42
 # Floor matter starts at contact, never during the raised-hammer phase.
 for cell in event.get("cells",[]):
  var ground=_quad("stamp_impact",int(cell),Vector3(0,.15,0),Vector2(1.45,1.45),.42,.31,true,"stamp_ground")
  if not ground.is_empty():ground.opacity=.90;ground.fast=true;ground.depth_bias=.22;ground.angle=float(int(cell)%3)*.67;_mask(ground,[int(cell)])
 for i in range(4):
  var a=float(i)*2.399;var chip=_quad("stamp_rubble",center,Vector3(cos(a)*.10,.12,sin(a)*.10),Vector2(.13,.13),.32,.33+float(i)*.012,false,"rubble")
  if not chip.is_empty():chip.opacity=.75;chip.travel=Vector3(cos(a)*.37,.23+float(i%2)*.12,sin(a)*.37);chip.angle=a
func _stamp_result(event: Dictionary):
 # Exact hurt recipient can differ from the impact centre because of cover.
 _impact(event)
 var contact=_quad("stamp_impact",int(event.recipient),Vector3(0,.35,0),Vector2(.92,.92),.24,0,false,"stamp_contact")
 if not contact.is_empty():contact.fast=true;contact.opacity=.85;contact.depth_bias=.32
 for i in range(3):
  var fragment=_quad("stamp_rubble",int(event.recipient),Vector3((float(i)-1)*.13,.26,0),Vector2(.13,.13),.28,float(i)*.015,false,"rubble")
  if not fragment.is_empty():fragment.travel=Vector3((float(i)-1)*.28,.28+float(i%2)*.14,.1);fragment.angle=float(i)*1.7;fragment.opacity=.85;fragment.depth_bias=.22
 if event.get("guarding",false) or event.get("redirected",false):
  var plate=_quad("guard_plate",int(event.recipient),Vector3(0,1.05,.06),Vector2(.78,1.38),.24,0,false,"guard_hit")
  if not plate.is_empty():plate.opacity=.56;plate.fast=true;plate.guard_side=_guard_side(event,int(event.recipient),true)
func _guard(event: Dictionary,hit: bool):
 var cell=int(event.recipient) if hit else int(event.origin)
 var plate=_quad("guard_plate",cell,Vector3(0,1.05,.06),Vector2(.78,1.38),.3 if hit else .58,0,false,"guard_hit" if hit else "guard_raise")
 if not plate.is_empty():
  plate.opacity=.68 if hit else .6;plate.fast=hit;plate.guard_side=_guard_side(event,cell,hit)
 if not hit:_react(str(event.get("actor_id","")),"brace",0,.58);return
 var direction=Vector3.RIGHT
 if _valid_cell(int(event.get("origin",-1))):direction=(board().point(int(event.origin))-board().point(cell)).normalized()
 var spark=_quad("guard_reflection",cell,Vector3(0,1.07,.12),Vector2(.575,.65),.19,0,false,"reflection")
 if not spark.is_empty():
  spark.fast=true;spark.opacity=.9;spark.angle=0.0;spark.pivot=Vector2(.18,.73);spark.guard_side=_guard_side(event,cell,hit);spark.flip=spark.guard_side<0
 for i in range(4):
  var shard=_quad("guard_shard",cell,Vector3(0,1.05,.1),Vector2(.10,.19),.24,float(i)*.012,false,"guard_chip")
  if not shard.is_empty():shard.travel=Vector3(direction.x*.28+(float(i)-1.5)*.14,.15+float(i%2)*.2,direction.z*.2);shard.angle=float(i)*1.2;shard.opacity=.85;shard.guard_side=_guard_side(event,cell,hit)
 _react(str(event.get("recipient_id","")),"stumble",0,.18,-direction)
 var amount=int(event.get("amount",0))
 if amount<0:_caption(cell,str(amount),Color("#fff1cf"),0,.43)
func _guard_side(event: Dictionary,cell: int,hit: bool) -> float:
 var b=board();var incoming=Vector3.RIGHT
 if hit and _valid_cell(int(event.get("origin",-1))):incoming=b.point(int(event.origin))-b.point(cell)
 else:
  for unit in b.data.get("state",{}).get("units",[]):
   if unit.id==event.get("actor_id"):incoming=Vector3.RIGHT if unit.side=="ally" else Vector3.LEFT;break
 var projected=b.project(b.point(cell)+incoming)-b.project_cell(cell)
 return 1.0 if projected.x>=0 else -1.0
func _react(id: String,kind: String,delay: float,life: float,direction:=Vector3.ZERO):
 if id.is_empty() or not board().actors.has(id):return
 if reactions.size()>=16:return
 var sprite=board().actors[id].sprite
 reactions.append({"id":id,"kind":kind,"age":-delay,"life":life,"texture":sprite.texture,"position":board().sprite_origin(sprite),"scale":sprite.scale,"modulate":sprite.modulate,"pixel_size":sprite.pixel_size,"flip_h":sprite.flip_h,"direction":direction})
func _restore_actor(row: Dictionary):
 var b=board()
 if b==null or not b.actors.has(row.id):return
 var sprite=b.actors[row.id].sprite;sprite.texture=row.texture;sprite.scale=row.scale;sprite.modulate=row.modulate;sprite.flip_h=row.flip_h;sprite.pixel_size=b.texture_pixel_size(sprite.texture);sprite.position=b.sprite_origin(sprite)
func _update_reaction(row: Dictionary):
 var b=board()
 if not b.actors.has(row.id):return
 var sprite=b.actors[row.id].sprite;var t=clampf(row.age/row.life,0,1);var pulse=sin(PI*t)
 sprite.position=b.sprite_origin(sprite)
 if row.kind=="stumble":sprite.position+=row.direction*(.07*sin(PI*t));return
 if row.kind=="strike":sprite.position+=row.direction*(.10*sin(PI*t))*smoothstep(0,.25,t);return
 if row.kind=="stamp_pose":
  if _default_pose_allowed(row.id) and _wood_hammer(row.id):
   sprite.texture=textures.pose_stamp_lift if t<.48 else textures.pose_stamp_slam
   sprite.pixel_size=b.texture_pixel_size(sprite.texture);sprite.position=b.sprite_origin(sprite)
   sprite.flip_h=(b.project(b.point(24)+row.direction)-b.project_cell(24)).x<0 if row.direction.length_squared()>0 else row.flip_h
  else:sprite.position+=Vector3(0,.05*sin(TAU*t),0)
  return
 if row.kind=="brace":sprite.position+=Vector3(0,-.035*pulse,0);sprite.modulate=Color(1,1,1);return
 if row.kind=="sweep_pose":
  if _default_pose_allowed(row.id):
   sprite.texture=textures.pose_crouch if t<.20 or t>.75 else textures.pose_sweep
   sprite.pixel_size=b.texture_pixel_size(sprite.texture)
   sprite.position=b.sprite_origin(sprite)
  sprite.position+=Vector3(0,-.06*pulse,0)+b.world.camera.global_basis.x*(.07*sin(TAU*t)*pulse)
func _default_pose_allowed(id: String) -> bool:
 for unit in board().data.get("state",{}).get("units",[]):
  if unit.id==id:return unit.get("side")=="ally" and unit.get("image")=="knight.png" and not board().portraits.overrides.has(id)
 return false
func _wood_hammer(id: String) -> bool:
 for member in board().data.get("campaign",{}).get("roster",[]):
  if member.id!=id:continue
  for detail in member.get("equipmentDetails",{}).values():
   if detail is Dictionary and str(detail.get("id","")).begins_with("hammer-wood"):return true
 return false
func _process(delta: float):
 var b=board()
 if b==null or not is_instance_valid(b):clear();return
 if not _event.is_empty():
  _elapsed+=maxf(delta,0)
  if _elapsed>=_duration:end_phase()
 for row in emitters.duplicate():
  row.age+=maxf(delta,0)
  if row.age>=row.life:
   if is_instance_valid(row.node):row.node.queue_free()
   emitters.erase(row);continue
  row.node.visible=row.age>=0
  if row.age<0:continue
  var t=clampf(row.age/row.life,0,1);var eased=smoothstep(0,1,t) if row.tag=="projectile" else 1-pow(1-t,3)
  var n=row.node;var mat=row.material
  n.position=b.point(row.cell)+row.offset+row.travel*eased
  if row.get("sprite_anchor",false):
   for unit in b.data.get("state",{}).get("units",[]):
    if int(unit.pos)==int(row.cell) and b.actors.has(unit.id):
     var anchor=b.actors[unit.id].root.position+b.actors[unit.id].sprite.position
     n.position=anchor+b.world.camera.global_basis.x*(row.offset.x+row.travel.x*eased)+b.world.camera.global_basis.y*(row.offset.y+row.travel.y*eased)+b.world.camera.global_basis.z*row.offset.z
     break
  if row.ground:
   n.rotation=Vector3(-PI/2,row.angle+(eased*2.35 if row.tag=="sweep" else 0.0),0)
  else:
   n.basis=b.world.camera.global_basis
   n.rotate_object_local(Vector3.FORWARD,row.angle+(t*.5 if row.tag in ["leaf","guard_chip"] else 0.0))
   if row.tag in ["guard_raise","guard_hit","reflection","guard_chip"]:n.position+=b.world.camera.global_basis.x*(.70*row.get("guard_side",1.0))
   if row.has("pivot"):
    var local=Vector2((.5-row.pivot.x)*row.dims.x*(-1 if row.get("flip",false) else 1),(row.pivot.y-.5)*row.dims.y).rotated(-row.angle)
    n.position+=b.world.camera.global_basis.x*local.x+b.world.camera.global_basis.y*local.y
   if row.tag=="veil":n.position-=b.world.camera.global_basis.z*.09
   else:n.position+=b.world.camera.global_basis.z*.08
  n.position+=b.world.camera.global_basis.z*float(row.get("depth_bias",0.0))
  var size_factor=.72+eased*.28 if row.tag=="sweep" else 1.0
  n.scale=Vector3(size_factor*(-1 if row.get("flip",false) else 1),size_factor,size_factor)
  var envelope=pow(1-t,1.7) if row.fast else _envelope(t)
  mat.set_shader_parameter("opacity",row.opacity*envelope);mat.set_shader_parameter("progress",t)
  mat.set_shader_parameter("scan",clampf(t*4.2,0,1) if row.tag=="guard_raise" else 1.0)
  mat.set_shader_parameter("wave",(1-t)*.8 if row.tag=="guard_hit" else 0.0)
  mat.set_shader_parameter("flow",-1.0 if row.tag=="veil_front" else 1.0 if row.tag=="veil" else 0.0)
  mat.set_shader_parameter("dissolve",smoothstep(.6,1,t)*.85 if row.tag in ["sweep","veil","veil_front","guard_raise"] else 0.0)
 for row in captions.duplicate():
  row.age+=delta
  if row.age>=row.life:captions.erase(row)
 for row in reactions.duplicate():
  row.age+=delta
  if row.age>=row.life:_restore_actor(row);reactions.erase(row)
  elif row.age>=0:_update_reaction(row)
 if _event.is_empty() and emitters.is_empty() and captions.is_empty() and reactions.is_empty():set_process(false)
 queue_redraw()
func _draw():
 var b=board()
 if b==null:return
 for row in captions:
  if row.age<0:continue
  var t=clampf(row.age/row.life,0,1);var at=b.project(b.point(row.cell)+Vector3(0,1.55+t*.32,0));var color=Color(row.color,1-smoothstep(.65,1,t));var font=ThemeDB.fallback_font;var font_size=17 if row.text=="手番スキップ" else 26
  var width=font.get_string_size(row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
  at.x=clampf(at.x,width*.5+3,maxf(width*.5+3,size.x-width*.5-3));at.y=clampf(at.y,font_size+3,maxf(font_size+3,size.y-3));at.x-=width*.5
  draw_string_outline(font,at,row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,5,Color(.06,.08,.10,color.a))
  draw_string(font,at,row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
