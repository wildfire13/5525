extends RefCounted
## Native and Godot share one ordered catalog of people and explicit asset keys.
static func read_character_catalog() -> Array:
	var native_root=ProjectSettings.globalize_path("res://../native/assets").get_base_dir()
	var path=native_root.path_join("data/character-identities.json")
	if not FileAccess.file_exists(path):
		push_error("Character identity catalog is missing: "+path);return []
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK or not parser.data is Array:
		push_error("Character identity catalog must be a JSON array: "+path);return []
	return parser.data
static func catalog_by_id(rows: Array) -> Dictionary:
	var result={}
	for person in rows:
		if not person is Dictionary:
			push_error("Character identity catalog contains a non-object entry");return {}
		for field in ["id","portraitKey","voiceKey"]:
			if not person.get(field) is String or str(person[field]).is_empty():
				push_error("Character identity catalog requires a nonempty "+field);return {}
		if result.has(person.id):
			push_error("Character identity catalog contains a duplicate ID: "+str(person.id));return {}
		result[person.id]=person
	return result
var characters: Dictionary=catalog_by_id(read_character_catalog())
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
	# Personal overrides stay first, and physical filenames stay unchanged.
	if u.get("side","ally") != "enemy":
		if not str(u.get("portraitKey","")).is_empty():
			file = "characters/" + str(u.portraitKey) + ".png"
		elif characters.has(u.get("id","")):
			file = "characters/" + str(characters[u.id].portraitKey) + ".png"
	var path = ProjectSettings.globalize_path("res://../native/assets/").path_join(file)
	if not FileAccess.file_exists(path): return null
	return Image.load_from_file(path)
func texture(u: Dictionary, face := false) -> Texture2D:
	var key = str(u.get("side","ally")) + ":" + str(u.get("id",u.get("image","")))
	if u.get("side","ally") == "enemy": key = "enemy:" + str(u.get("image",""))
	var cache = faces if face else textures
	if cache.has(key): return cache[key]
	var img = image_for(u)
	if img == null or img.is_empty(): return null
	var entry: Dictionary=metadata.characters.get(str(u.get("id","")),{})
	if u.get("side","ally")!="enemy" and entry.has("framing"):
		img=framed_image(img,entry.framing)
	if face and not overrides.has(u.get("id","")):
		var used = img.get_used_rect()
		var edge = maxi(1,mini(used.size.x,int(used.size.y * 0.56)))
		img = img.get_region(Rect2i(used.position.x + (used.size.x-edge)/2,used.position.y,edge,edge))
	img.generate_mipmaps()
	var tex = ImageTexture.create_from_image(img)
	cache[key] = tex
	return tex
static func framed_image(image: Image, framing: Dictionary) -> Image:
	return image.get_region(framing_rect(image,framing))
static func framing_rect(image: Image, framing: Dictionary) -> Rect2i:
	var zoom=clampf(float(framing.get("zoom",1.0)),1.0,4.0)
	var extent=Vector2i(image.get_size()/zoom)
	extent=extent.max(Vector2i.ONE)
	var remaining=image.get_size()-extent
	var position=Vector2i(Vector2(remaining)*Vector2((float(framing.get("x",0))+1)*0.5,(float(framing.get("y",0))+1)*0.5))
	return Rect2i(position,extent)
