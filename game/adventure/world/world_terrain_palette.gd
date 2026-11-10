class_name WorldTerrainPalette
extends RefCounted
## [QoL] Regional vegetation and water colors, applied to private copies of terrain
## sheets. The skin stays intact; transparency and logical sizes stay exact.
## New regions can select another profile without changing world generation.

const SHANDALAR := "shandalar"
const LAST_REFUGE := "last_refuge"
const DRY_COAST := LAST_REFUGE
const LAYERS := ["ground", "objects", "roads"]
const PROFILES := {
	SHANDALAR: {"name": "Shandalar"},
	LAST_REFUGE: {
		"name": "The Last Refuge",
		"grass": Vector4(0.125, 0.60, 1.22, 0.97),
		"foliage": Vector4(0.205, 0.72, 1.02, 0.72),
		"water": Vector4(0.60, 1.03, 0.97, 0.85),
		"plain": {2: Color("858855"), 6: Color("c6af78"),
			10: Color("a49b64"), 15: Color("96905c")},
	},
}

var _textures := {}

## PALETTES AN ADVENTURE PLUGIN BRINGS (adventure plugins, 2026-11-10): a
## plugin's `region.palette` may be an object in the profile shape (its
## JSON form: `grass`/`foliage`/`water` as four numbers, `plain` as terrain
## code to `#rrggbb`, `tints` as layer settings), registered at run time as
## `plugin:<id>` beside the built-in [constant PROFILES]. Read through
## [method profile_of]; a saved `plugin:<id>` preset whose plugin is gone
## stays a valid save and draws in the original colors.
static var _runtime := {}
const PLUGIN_PREFIX := "plugin:"


## The profile [param name] names, built-in or registered; {} for none.
static func profile_of(name: String) -> Dictionary:
	return PROFILES.get(name, _runtime.get(name, {}))


static func has_profile(name: Variant) -> bool:
	return name is String and (PROFILES.has(name) or _runtime.has(name))


## A preset a save may name: a known one, or a plugin's that may be absent.
static func _known_preset(name: Variant) -> bool:
	if has_profile(name): return true
	if not name is String or not String(name).begins_with(PLUGIN_PREFIX): return false
	var id := String(name).trim_prefix(PLUGIN_PREFIX)
	var expression := RegEx.create_from_string("^[a-z][a-z0-9_]{0,39}$")
	return expression.search(id) != null


## Why [param value] (a palette object, JSON values) is not a profile, ""
## when it is one.
static func profile_problem(value: Variant) -> String:
	if not value is Dictionary: return "a palette object is needed."
	for key in value:
		if not key in ["name", "grass", "foliage", "water", "plain", "tints"]: return "unknown field %s." % key
	if value.has("name") and (not value["name"] is String or String(value["name"]).length() > 60): return "name: up to 60 characters."
	for recipe in ["grass", "foliage", "water"]:
		if not value.has(recipe): continue
		var numbers: Variant = value[recipe]
		if not numbers is Array or numbers.size() != 4: return "%s: four numbers (hue 0-1, saturation and brightness 0-4, strength 0-1)." % recipe
		for i in 4:
			var n: Variant = numbers[i]
			if not (n is float or n is int) or not is_finite(float(n)) or n < 0 or n > (1 if i in [0, 3] else 4):
				return "%s: four numbers (hue 0-1, saturation and brightness 0-4, strength 0-1)." % recipe
	if value.has("plain"):
		if not value["plain"] is Dictionary or value["plain"].size() > 16: return "plain: terrain codes to colors."
		for key in value["plain"]:
			if not String(key).is_valid_int() or int(key) < 0 or int(key) > 15 or str(int(key)) != String(key): return "plain: %s is not a terrain code 0-15." % key
			if not _hex_color(value["plain"][key]): return "plain.%s: a color like #c6af78 is needed." % key
	if value.has("tints"):
		if not value["tints"] is Dictionary: return "tints: layer settings are needed."
		for layer in value["tints"]:
			if not layer in LAYERS or not _valid_style({layer: value["tints"][layer]}): return "tints.%s: {\"tint\": \"#rrggbb\", \"strength\": 0-1} per layer (ground, objects, roads)." % layer
	return ""


## Register [param value] (see [method profile_problem]) as [param name];
## the reason it was refused, "" when registered. Built-in names stay.
static func register_profile(name: String, value: Dictionary) -> String:
	if PROFILES.has(name): return "%s is a built-in palette." % name
	var why := profile_problem(value)
	if why != "": return why
	var profile := {"name": String(value.get("name", name))}
	for recipe in ["grass", "foliage", "water"]:
		if value.has(recipe):
			var n: Array = value[recipe]
			profile[recipe] = Vector4(float(n[0]), float(n[1]), float(n[2]), float(n[3]))
	if value.has("plain"):
		var plain := {}
		for key in value["plain"]: plain[int(key)] = Color.from_string(String(value["plain"][key]), Color.WHITE)
		profile["plain"] = plain
	if value.has("tints"): profile["tints"] = value["tints"].duplicate(true)
	if _runtime.get(name) != profile:
		_runtime[name] = profile
		_forget_all()
	return ""


static func _hex_color(value: Variant) -> bool:
	if not value is String: return false
	var digits := String(value).trim_prefix("#")
	return digits.length() == 6 and digits.is_valid_hex_number()

static func for_world(world: ShandalarWorld) -> String:
	if world == null: return SHANDALAR
	var fallback: String = AdventureExpansions.definition(AdventureRegions.id(world)).get("palette", SHANDALAR)
	var preset := String(world.expansion.get("appearance", {}).get("preset", fallback))
	_watch(world, preset)
	return preset

## A world drawn in [param preset] is told when its recolored sheets arrive
## (h1-6, [method _deliver]): every view and map asks here as it is given a
## world, and a tile's own preset asks in [method resolve].
## One comparison on the mainland: [method plain] asks for every tile drawn.
static func _watch(world: ShandalarWorld, preset: String) -> void:
	if preset == SHANDALAR or _drawn.has(world.get_instance_id()) or not _remaps(preset):
		return
	_drawn[world.get_instance_id()] = weakref(world)

## Resolved style: tile overrides terrain, which overrides the world preset.
## Returned dictionaries are independent of both saved data and built-ins.
static func resolve(world: ShandalarWorld, tile: Vector2i) -> Dictionary:
	var style := {"preset": for_world(world)}
	if world == null: return style
	var appearance: Dictionary = world.expansion.get("appearance", {})
	if appearance.is_empty() and not profile_of(style["preset"]).has("tints"):
		return style
	var terrain: Dictionary = appearance.get("terrains", {}).get(str(world.terrain(tile.x, tile.y)), {})
	var local: Dictionary = appearance.get("tiles", {}).get(tile_key(tile), {})
	style["preset"] = local.get("preset", terrain.get("preset", style["preset"]))
	_watch(world, style["preset"])
	var defaults: Dictionary = profile_of(style["preset"]).get("tints", {})
	for layer in LAYERS:
		if local.has(layer): style[layer] = local[layer].duplicate(true)
		elif terrain.has(layer): style[layer] = terrain[layer].duplicate(true)
		elif defaults.has(layer): style[layer] = defaults[layer].duplicate(true)
	return style

static func tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

static func layer_for(key: String) -> String:
	if key in ["world_landtile", "world_cstline1", "world_map_tiles"]: return "ground"
	if key in ["world_land", "world_land2", "world_sland", "world_sland2"]: return "objects"
	return "roads" if key == "world_roads" else ""

## A multiplicative tint, with alpha always 1: tuning can never make terrain
## transparent. It is passed to the draw call, not baked per map tile.
static func modulate(style: Dictionary, layer: String) -> Color:
	var setting: Dictionary = style.get(layer, {})
	if setting.is_empty(): return Color.WHITE
	var tint := Color.from_string(String(setting["tint"]), Color.WHITE)
	return Color.WHITE.lerp(Color(tint, 1.0), float(setting["strength"]))

static func plain(world: ShandalarWorld, terrain: int, original: Color,
		tile := Vector2i(-1, -1)) -> Color:
	var style := resolve(world, tile) if tile.x >= 0 else {"preset": for_world(world)}
	var colors: Dictionary = profile_of(style["preset"])
	var color: Color = colors.get("plain", {}).get(terrain, original)
	if terrain in [0, 1, 8]: color = shift(color, style["preset"], "water")
	return color * modulate(style, "ground")

static func set_preset(world: ShandalarWorld, preset: String) -> bool:
	if world == null or not has_profile(preset): return false
	var appearance: Dictionary = world.expansion.get("appearance", {}).duplicate(true)
	appearance["preset"] = preset
	_store(world, appearance)
	return true

## An empty style removes the override and restores inheritance.
static func set_terrain_style(world: ShandalarWorld, terrain: int, style: Dictionary) -> bool:
	if terrain < 0 or terrain > 15: return false
	return _set_style(world, "terrains", str(terrain), style)

static func set_tile_style(world: ShandalarWorld, tile: Vector2i, style: Dictionary) -> bool:
	if not _on_map(tile): return false
	return _set_style(world, "tiles", tile_key(tile), style)

## Convenience for a single patch; other layer choices on that tile survive.
static func tint_tile(world: ShandalarWorld, tile: Vector2i, tint: Color,
		strength := 0.25, layer := "ground") -> bool:
	if world == null or not layer in LAYERS: return false
	for component in [tint.r, tint.g, tint.b]:
		if not is_finite(component): return false
	var style: Dictionary = world.expansion.get("appearance", {}).get("tiles", {}).get(tile_key(tile), {}).duplicate(true)
	style[layer] = {"tint": "#" + tint.to_html(false), "strength": strength}
	return set_tile_style(world, tile, style)

static func _set_style(world: ShandalarWorld, group: String, key: String, style: Dictionary) -> bool:
	if world == null or not _valid_style(style): return false
	var appearance: Dictionary = world.expansion.get("appearance", {}).duplicate(true)
	var entries: Dictionary = appearance.get(group, {})
	if style.is_empty(): entries.erase(key)
	else: entries[key] = style.duplicate(true)
	if entries.is_empty(): appearance.erase(group)
	else: appearance[group] = entries
	_store(world, appearance)
	return true

static func _store(world: ShandalarWorld, appearance: Dictionary) -> void:
	if appearance == world.expansion.get("appearance", {}): return
	if appearance.is_empty(): world.expansion.erase("appearance")
	else: world.expansion["appearance"] = appearance
	world.appearance_revision += 1
	world.appearance_changed.emit()

static func _on_map(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < 64 and tile.y < 64

## The save format uses only JSON values: names, hex colors and numbers.
static func valid_appearance(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if not key in ["preset", "terrains", "tiles"]: return false
	if value.has("preset") and not _known_preset(value["preset"]): return false
	for group in ["terrains", "tiles"]:
		var entries: Variant = value.get(group, {})
		if not entries is Dictionary or entries.size() > (16 if group == "terrains" else 4096): return false
		for key in entries:
			if not key is String or not _valid_style(entries[key]): return false
			if group == "terrains":
				if not key.is_valid_int() or str(int(key)) != key or int(key) < 0 or int(key) > 15: return false
			else:
				var axes := String(key).split(",")
				if axes.size() != 2 or not axes[0].is_valid_int() or not axes[1].is_valid_int(): return false
				var tile := Vector2i(int(axes[0]), int(axes[1]))
				if not _on_map(tile) or tile_key(tile) != key: return false
	return true

static func _valid_style(style: Variant) -> bool:
	if not style is Dictionary: return false
	for key in style:
		if key == "preset":
			if not _known_preset(style[key]): return false
		elif key in LAYERS:
			var layer: Variant = style[key]
			if not layer is Dictionary or layer.size() != 2: return false
			var tint: Variant = layer.get("tint")
			var strength: Variant = layer.get("strength")
			if not tint is String or tint.length() != 7 or not tint.begins_with("#"): return false
			for digit in tint.substr(1):
				if not digit in "0123456789abcdefABCDEF": return false
			if not (strength is float or strength is int) or not is_finite(float(strength)) or strength < 0 or strength > 1: return false
		else: return false
	return true

## A sheet recolored once per profile/source; unlisted sheets are returned
## untouched. Holding the source prevents its instance ID being reused.
##
## [QoL] NOT ON THE THREAD THAT DRAWS (0.60.13 bug campaign, h1-6). The
## seven sheets took 177 ms with the 1997 skin and 1,080 ms with the 2x
## skin on the desk — a frozen frame as the ship landed and as every island
## save opened. Where a worker may run ([method SkinWarmer.runs_here]) a
## sheet is recolored on one ([method _recolor_aside]), and until it is in
## hand this answers [param source], the sheet as the skin has it; once
## every sheet asked for has arrived, the worlds drawn in a recoloring
## palette are told ([method _deliver]) and their views draw again. Headless
## and on the web the recolor is done here, as before.
func texture(key: String, source: Texture2D, profile: String) -> Texture2D:
	if source == null or not _remaps(profile) or not supports(key):
		return source
	var memo := "%s:%s:%d" % [profile, key, source.get_instance_id()]
	if not _textures.has(memo):
		# Another palette's copy (the view's and the map's) is not made twice.
		var shared: WeakRef = _shared.get(memo)
		var made: Texture2D = shared.get_ref() if shared != null else null
		if made == null:
			if SkinWarmer.runs_here():
				_recolor_aside(memo, key, source, profile)
				return source
			made = _recolored(source, null, key, profile)
			_shared[memo] = weakref(made)
		_textures[memo] = [source, made]
	return _textures[memo][1]

## [param source]'s sheet recolored: [param pixels] when a worker has done
## it, else read and recolored here. Main thread: it makes the texture.
static func _recolored(source: Texture2D, pixels: Image, key: String, profile: String) -> Texture2D:
	if pixels == null:
		pixels = recolor(source.get_image(), key, profile, GameSkin.scale_of(source))
	return GameSkin.texture_of(pixels, Vector2i(source.get_size()))

## One sheet recolored on a worker ([method WorldTerrainPalette.texture]).
## The worker writes [member pixels] (and the decoded picture into [member
## job]); the main thread reads them once the task has completed. `lock`,
## `stop` and `started` are [SkinWarmer]'s protocol for a task it tracks.
class Recolor extends RefCounted:
	var key := ""
	var profile := ""
	var scale := 1
	## Held until delivered, as [member WorldTerrainPalette._textures] holds it.
	var source: Texture2D
	## The skin's file of the sheet ([method GameSkin.picture_job]), decoded
	## by the worker — or, empty, [member image] read on the main thread.
	var job: Dictionary = {}
	var image: Image
	var pixels: Image
	## The palettes waiting for it (weakly: a view gone is not waited for).
	var askers: Array[WeakRef] = []
	var task := -1
	var lock := Mutex.new()
	var stop := false
	var started := false

	func run() -> void:
		lock.lock()
		started = true
		var stopped := stop
		lock.unlock()
		if stopped:
			return
		var picture := image
		if picture == null and not job.is_empty():
			GameSkin.decode_picture(job)
			picture = job.get("img")
		if picture != null:
			pixels = WorldTerrainPalette.recolor(picture, key, profile, scale)

## The sheets on a worker or waiting to be delivered, by memo. Main thread.
static var _working: Dictionary = {}
## Every palette's recolored sheets, by memo, weakly: kept by the palettes
## that draw them ([member _textures]) and no longer.
static var _shared: Dictionary = {}
## The worlds drawn in a recoloring palette ([method for_world]), weakly, by
## instance id: told when sheets arrive.
static var _drawn: Dictionary = {}
## A sheet has arrived since the worlds were last told.
static var _arrived := false

## [param source] as [param key] in [param profile], recolored on a worker
## for this palette, from [param memo] — one task a sheet, ahead of the
## background warm-ups: the island is on screen. The skin's own picture is
## decoded from its file there: reading it back from the graphics card
## here cost 31 ms (89 ms with the 2x skin) for the seven sheets.
func _recolor_aside(memo: String, key: String, source: Texture2D, profile: String) -> void:
	var work: Recolor = _working.get(memo)
	if work == null:
		work = Recolor.new()
		work.key = key
		work.profile = profile
		work.scale = GameSkin.scale_of(source)
		work.source = source
		if GameSkin.is_kept(key) and GameSkin.skin_texture(key) == source:
			work.job = GameSkin.picture_job(key, true)
		if work.job.is_empty():
			work.image = source.get_image()
		_working[memo] = work
		work.task = SkinWarmer.track(work, WorkerThreadPool.add_task(work.run, true, "Terrain palette"))
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			if not tree.process_frame.is_connected(_deliver):
				tree.process_frame.connect(_deliver)
			# After [method SkinWarmer._reclaim_all] (connected by track):
			# nothing static outlives the game.
			if tree.root != null and not tree.root.tree_exiting.is_connected(_forget_all):
				tree.root.tree_exiting.connect(_forget_all)
	for asker in work.askers:
		if asker.get_ref() == self:
			return
	work.askers.append(weakref(self))

## Once a frame while any sheet is out: the finished ones made into
## textures for the palettes that asked — as [SkinWarmer] keeps a picture,
## at most [constant SkinWarmer.KEEP_BUDGET_BYTES] a frame (at least one).
## When none is left out, the worlds drawn are told once, so the island's
## colors come in together.
static func _deliver() -> void:
	var bytes := 0
	for memo: String in _working.keys():
		var work: Recolor = _working[memo]
		if not WorkerThreadPool.is_task_completed(work.task):
			continue
		if bytes > 0 and work.pixels != null \
				and bytes + work.pixels.get_data_size() > SkinWarmer.KEEP_BUDGET_BYTES:
			break
		SkinWarmer.claim(work.task)
		_working.erase(memo)
		var palettes: Array[WorldTerrainPalette] = []
		for asker in work.askers:
			var palette := asker.get_ref() as WorldTerrainPalette
			if palette != null:
				palettes.append(palette)
		if palettes.is_empty():
			continue
		# A file that would not decode is read and recolored here instead.
		var made := _recolored(work.source, work.pixels, work.key, work.profile)
		_shared[memo] = weakref(made)
		for palette in palettes:
			palette._textures[memo] = [work.source, made]
		bytes += maxi(1, work.pixels.get_data_size() if work.pixels != null else 1)
		_arrived = true
	if not _working.is_empty():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.process_frame.is_connected(_deliver):
		tree.process_frame.disconnect(_deliver)
	if not _arrived:
		return
	_arrived = false
	for id: int in _drawn.keys():
		var world := (_drawn[id] as WeakRef).get_ref() as ShandalarWorld
		if world == null:
			_drawn.erase(id)
			continue
		# A presentation change, as [method _store]'s: not saved, not the
		# terrain's fingerprint; every view and map of it looks again.
		world.appearance_revision += 1
		world.appearance_changed.emit()

## How many sheets are being recolored or wait to be delivered (a test).
static func recoloring() -> int:
	return _working.size()

## As the game closes, after every task was waited for.
static func _forget_all() -> void:
	_working.clear()
	_shared.clear()
	_drawn.clear()
	_arrived = false

static func supports(key: String) -> bool:
	return key in ["world_landtile", "world_cstline1", "world_land", "world_land2",
		"world_sland", "world_sland2", "world_map_tiles"]

static func _remaps(name: String) -> bool:
	var definition: Dictionary = profile_of(name)
	return definition.has("grass") or definition.has("foliage") or definition.has("water")

## Process full-resolution pixels, including a 2x skin's detail. Only
## vegetation and water in their own atlas regions are shifted. Gray stone,
## brown earth, map icons and every alpha byte retain their source values.
##
## One 32-bit word a pixel, and each column's recipe chosen once a sheet
## rather than once a pixel (0.60.13 bug campaign, h1-6): the same pixels,
## the ground's sheets two to four times as fast; the trees' sheets, whose
## time is the color math of their many colors, about as before. For the
## worker, and for the web, where the recolor still runs on the thread
## that draws.
static func recolor(source: Image, key: String, profile: String, scale := 1) -> Image:
	var result := source.duplicate() as Image
	if not _remaps(profile) or not supports(key):
		return result
	result.convert(Image.FORMAT_RGBA8)
	var bytes := result.get_data()
	var width := result.get_width()
	var height := result.get_height()
	bytes.resize(width * height * 4)
	# RGBA8 in memory, read as little-endian words: red in the low byte,
	# alpha in the high one (every platform the game runs on).
	var words := bytes.to_int32_array()
	var colors := {}
	var columns := _recipes(key, width, scale, false)
	var coast := _recipes(key, width, scale, true) if key == "world_cstline1" else columns
	var rows := height
	if key == "world_map_tiles":
		rows = mini(height, 60 * scale)   # the map icons below keep their colors
	for y in rows:
		var recipes := coast if y < 128 * scale else columns
		var row := y * width
		for x in width:
			var kind := recipes[x]
			if kind == SKIP:
				continue
			var at := row + x
			var word := words[at]
			if (word & ALPHA) == 0:
				continue
			var memo := (word & RGB) | (kind << 24)
			var changed: int = colors.get(memo, -1)
			if changed < 0:
				changed = _shifted(word, kind, profile)
				colors[memo] = changed
			words[at] = (word & ALPHA) | changed
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, words.to_byte_array())
	if source.has_mipmaps(): image.generate_mipmaps()
	return image

## [method recolor]'s recipes, as kinds: grass, foliage, water, coast (by
## the pixel's hue: water or grass), wet foliage (water or foliage), or
## [constant SKIP] for cells left alone.
const GRASS := 0
const FOLIAGE := 1
const WATER := 2
const COAST := 3
const WET_FOLIAGE := 4
const SKIP := 255
const ALPHA := 0xFF000000
const RGB := 0xFFFFFF

## The recipe of each of [param width] columns of sheet [param key]. Limit
## each recipe to its own atlas cells. Coast pieces contain both vegetation
## and water ([param coast_rows]: the cstline sheet's top rows); the recipe
## is then chosen by the source hue.
static func _recipes(key: String, width: int, scale: int, coast_rows: bool) -> PackedByteArray:
	var kinds := PackedByteArray()
	kinds.resize(width)
	for x in width:
		var kind := GRASS
		match key:
			"world_landtile":
				var column := x / (128 * scale)
				if column == 1: kind = WATER
				elif column != 0: kind = SKIP
			"world_cstline1":
				if coast_rows: kind = COAST
			"world_map_tiles":
				var terrain := (x / (13 * scale)) % 16
				if terrain in [0, 1, 8]: kind = WATER
				elif not terrain in [2, 6, 10, 15]: kind = SKIP
				elif terrain == 2: kind = FOLIAGE
			"world_land", "world_land2", "world_sland", "world_sland2":
				var object_column := (x / (128 * scale)) % 5
				if object_column != 4: kind = FOLIAGE
				# Island palms and marsh trees carry water in their own
				# sprites too, including the separately drawn ground half.
				if object_column == (0 if key.ends_with("2") else 1): kind = WET_FOLIAGE
		kinds[x] = kind
	return kinds

## Pixel [param word]'s color by recipe [param kind], as the low three
## bytes of a word (alpha left to the caller).
static func _shifted(word: int, kind: int, profile: String) -> int:
	var original := Color8(word & 255, (word >> 8) & 255, (word >> 16) & 255)
	var recipe := "grass"
	match kind:
		FOLIAGE: recipe = "foliage"
		WATER: recipe = "water"
		COAST: recipe = "water" if original.h >= 0.42 else "grass"
		WET_FOLIAGE: recipe = "water" if original.h >= 0.42 else "foliage"
	var changed := shift(original, profile, recipe)
	return changed.r8 | (changed.g8 << 8) | (changed.b8 << 16)

static func shift(color: Color, name: String, style := "grass") -> Color:
	if not profile_of(name).has(style): return color
	var hue := color.h
	# Soft edges keep antialiased leaves and mixed grass natural. Existing
	# yellow stalks remain varied, rather than becoming a flat gold wash.
	var weight := smoothstep(0.10, 0.15, hue) * (1.0 - smoothstep(0.36, 0.47, hue))
	weight *= smoothstep(0.08, 0.24, color.s)
	weight *= smoothstep(0.85, 0.94, color.g / maxf(color.r, 0.001))
	if style == "water":
		# Preserve sandy shores, green foliage and neutral foam/highlights.
		weight = smoothstep(0.42, 0.48, hue) * (1.0 - smoothstep(0.65, 0.72, hue))
		weight *= smoothstep(0.08, 0.24, color.s)
	if weight <= 0.0: return color
	var recipe: Vector4 = profile_of(name)[style]
	weight *= recipe.w
	return Color.from_hsv(lerpf(hue, recipe.x, weight),
		lerpf(color.s, color.s * recipe.y, weight),
		minf(1.0, color.v * lerpf(1.0, recipe.z, weight)), color.a)
