extends "res://tests/skill_effect_regression.gd"
## Material semantics, canonical packets, portrait ownership and lifecycle.
## Pixel quality is assessed separately in real rendered frame sequences.
func run():
 if evidence.is_empty() or not OS.get_user_data_dir().begins_with(evidence+"/"):quit(2);return
 var output=[];var code=OS.execute(OS.get_environment("NATIVE5525_NODE"),[ProjectSettings.globalize_path("res://tests/skill_effect_fixtures.cjs")],output,true,false)
 check(code==0,"canonical rule/save/RNG parity fixtures")
 var cases=JSON.parse_string("".join(output)).cases
 game=load("res://main.tscn").instantiate();root.add_child(game)
 while game.data.is_empty():await process_frame
 game.checks_fast=true;game.audio.fast_mode=true
 board=load("res://battle_board.gd").new();board.portraits=game.portraits;board.size=Vector2(1180,812);root.add_child(board)
 for i in range(5):await process_frame
 var fx=board.skill_effects;fx.set_process(false)
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx_production/manifest.json"))
 check(manifest.images.size()==19 and fx.textures.size()==19,"19 original separated artwork layers loaded")
 for entry in manifest.images:
  var path="res://assets/vfx_production/"+entry.file
  var im=Image.new();im.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
  check(FileAccess.get_sha256(path)==entry.sha256,"reviewed texture immutable "+entry.name)
  check(im.get_format()==Image.FORMAT_RGBA8 and im.get_size()==Vector2i(entry.size[0],entry.size[1]),"RGBA and declared pixel dimensions "+entry.name)
  check(im.get_pixel(0,0).a==0 and im.get_pixel(im.get_width()-1,im.get_height()-1).a==0,"transparent outer pixels "+entry.name)
 var saved_before=(await game.engine.request({"op":"campaign_save"})).data
 for key in cases:
  var c=cases[key]
  await game.update({"op":"campaign_load","data":c.save})
  for i in range(3):await process_frame
  var native_before=(await game.engine.request({"op":"campaign_save"})).data
  for repeat in range(3):
   board.reset_animation();board.effect_action.clear();board.last_animated_phase=""
   for index in range(c.frames.size()):
    var f=c.frames[index];load_frame(c,f,index);var data_before=board.data.duplicate(true)
    board.animate(f.presentation);fx.set_process(false)
    var e=fx.snapshot().event
    if not e.is_empty():
     check(not fx.legacy.snapshot().active,key+" painted action never duplicates legacy "+str(index))
     if e.skill_id=="legSweep":
      var successes=e.get("resolved_status",[]).filter(func(s):return s.get("success",false)).size()
      check(fx.captions.size()==successes,key+" only confirmed sweep successes have status labels")
      check(fx.captions.all(func(row):return row.text=="手番スキップ"),key+" sweep never invents damage")
      for row in fx.emitters:
       if row.material.get_shader_parameter("ground_masked"):
        var allowed=row.material.get_shader_parameter("allowed_cells")
        check(allowed.size()==50 and range(50).all(func(cell):return allowed[cell]==0 or e.cells.has(cell)),key+" ground paint limited to canonical cells")
     if e.skill_id=="stamp" and e.phase=="action":
      check(fx.emitters.filter(func(row):return row.tag in ["stamp_ground","rubble"]).all(func(row):return row.age<=-.31),key+" no floor debris before contact")
      check(fx.emitters.filter(func(row):return row.tag=="stamp_fall").size()==1,key+" dedicated vertical fall, no sweep brush")
     if e.phase in ["hurt","heal"]:
      check(e.amount==int(f.presentation.to)-int(f.presentation.from),key+" exact committed HP delta")
     if e.skill_id=="attack":
      check(fx.emitters.all(func(row):return row.tag not in ["contact","stamp_ground","guard_hit"]),key+" attack preparation cannot claim hit")
      var expected_style="bow" if key=="attackRanged" else "sword" if key=="attackMelee" else ""
      if not expected_style.is_empty():check(e.attack_style==expected_style,key+" actual contributing weapon style")
    fx._process(.15)
    check(board.data==data_before,key+" render processing never changes state "+str(index))
   fx.clear()
   for i in range(3):await process_frame
   check(fx.emitters.is_empty() and fx.captions.is_empty() and fx.reactions.is_empty() and fx.stage.get_child_count()==0,key+" repeat "+str(repeat)+" clears every effect node")
  check((await game.engine.request({"op":"campaign_save"})).data==native_before,key+" render-only replay has exact native save parity")
 # Pose ownership: only the supplied default knight and wood hammer receive wood art.
 var c=cases.stamp;await game.update({"op":"campaign_load","data":c.save});load_frame(c,c.frames[0],0)
 var actor=str(c.frames[0].presentation.actor_id);var original=board.actors[actor].sprite.texture
 board.animate(c.frames[0].presentation);fx.set_process(false);fx._process(.2)
 check(board.actors[actor].sprite.texture==fx.textures.pose_stamp_lift,"default wood hammer has genuine raised pose")
 fx.clear();check(board.actors[actor].sprite.texture==original,"pose returns exact source texture")
 board.portraits.overrides[actor]="qa-custom-placeholder";board.last_animated_phase="";board.animate(c.frames[0].presentation);fx.set_process(false);fx._process(.2)
 check(board.actors[actor].sprite.texture==original,"custom portrait is never replaced by generated knight")
 fx.clear();board.portraits.overrides.erase(actor)
 # Restore must use the current compact geometry, never stale start dimensions.
 board.last_animated_phase="";board.animate(c.frames[0].presentation);fx.set_process(false);fx._process(.2)
 board.size=Vector2(960,200);board.update_camera();fx._process(.05)
 check(is_equal_approx(board.actors[actor].sprite.pixel_size,board.texture_pixel_size(board.actors[actor].sprite.texture)),"in-flight pose follows compact sizing")
 fx.clear()
 check(board.actors[actor].sprite.texture==original and is_equal_approx(board.actors[actor].sprite.pixel_size,board.texture_pixel_size(original)),"compact cleanup preserves current scale and original artwork")
 check(board.actors[actor].sprite.position.is_equal_approx(board.sprite_origin(board.actors[actor].sprite)),"compact cleanup restores current camera-aware foot anchor")
 board.size=Vector2(1180,812)
 for yaw in [-.45,0.0,.45]:
  board.camera_yaw=yaw;board.update_camera()
  var from=board.point(23)+Vector3(0,.83,0);var to=board.point(25)+Vector3(0,.83,0);var direction=(board.project(to)-board.project(from)).normalized()
  fx.play({"skill_id":"attack","phase":"action","origin":23,"recipient":25,"attack_style":"bow","cells":[]},.30);fx.set_process(false);fx._process(.14)
  var row=fx.emitters.filter(func(item):return item.tag=="projectile")[0]
  var at=row.node.global_position;var right=(board.project(at+row.node.global_basis.x)-board.project(at)).normalized()
  check(right.dot(direction)>.999,"projectile head points along travel at camera yaw "+str(yaw))
  fx.clear()
 check(game.audio.muted.values().all(func(v):return v),"all QA audio OFF")
 var file=FileAccess.open(evidence.path_join("painted-vfx-checks.json"),FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
 board.queue_free();game.closing=true;await game.audio.finish_audio();game.engine.close_engine();game.queue_free()
 for i in range(4):await process_frame
 print("Painted VFX "+str(checks.filter(func(row):return row.passed).size())+"/"+str(checks.size()));quit(0 if checks.all(func(row):return row.passed) else 1)
