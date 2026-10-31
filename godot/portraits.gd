extends RefCounted
var overrides: Dictionary = {}
var textures: Dictionary = {}
var faces: Dictionary = {}
var metadata: Dictionary = {"version":1,"characters":{}}
func activate(meta: Dictionary) -> void:
	metadata = meta.duplicate(true)
	overrides.clear(); textures.clear(); faces.clear()
	for uid in meta.get("characters",{}):
		var bytes = Marshalls.base64_to_raw(meta.characters[uid].png)
		var image = Image.new()
		if image.load_png_from_buffer(bytes) == OK: overrides[uid] = image
func assign(uid: String, entry: Dictionary) -> void:
	var next = metadata.duplicate(true)
	next.characters[uid] = entry
	activate(next)
func clear_member(uid: String) -> void:
	var next = metadata.duplicate(true)
	next.characters.erase(uid)
	activate(next)
func image_for(u: Dictionary) -> Image:
	if u.get("side","ally") != "enemy" and overrides.has(u.get("id","")):
		return overrides[u.id]
	var file = str(u.get("image","knight.png"))
	# Saved journey/battle snapshots can still contain the old generic image.
	# Only supplied recruit portraits are remapped; personal overrides stay first.
	if u.get("side","ally") != "enemy":
		for job in ["scout","porter","guard","mage"]:
			for race in ["human","elf","dwarf"]:
				for sex in ["male","female"]:
					if job == "mage" and race == "elf" and sex == "male":continue
					if str(u.get("id","")) == "recruit-" + job + "-" + race + "-" + sex:
						file = "characters/" + job + "-" + race + "-" + sex + "-01.png"
	if u.get("side","ally") == "enemy": file = "enemy/enemy_" + file
	var path = ProjectSettings.globalize_path("res://../native/assets/").path_join(file)
	if not FileAccess.file_exists(path): return null
	return Image.load_from_file(path)
func texture(u: Dictionary, face := false) -> Texture2D:
	var key = str(u.get("side","ally")) + ":" + str(u.get("id",u.get("image","")))
	var cache = faces if face else textures
	if cache.has(key): return cache[key]
	var img = image_for(u)
	if img == null or img.is_empty(): return null
	if face and not overrides.has(u.get("id","")):
		var used = img.get_used_rect()
		var edge = maxi(1,mini(used.size.x,int(used.size.y * 0.56)))
		img = img.get_region(Rect2i(used.position.x + (used.size.x-edge)/2,used.position.y,edge,edge))
	img.generate_mipmaps()
	var tex = ImageTexture.create_from_image(img)
	cache[key] = tex
	return tex
