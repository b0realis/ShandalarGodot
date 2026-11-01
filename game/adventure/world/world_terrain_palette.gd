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

static func for_world(world: ShandalarWorld) -> String:
	if world == null: return SHANDALAR
	var fallback: String = AdventureExpansions.definition(AdventureRegions.id(world)).get("palette", SHANDALAR)
	return String(world.expansion.get("appearance", {}).get("preset", fallback))

## Resolved style: tile overrides terrain, which overrides the world preset.
## Returned dictionaries are independent of both saved data and built-ins.
static func resolve(world: ShandalarWorld, tile: Vector2i) -> Dictionary:
	var style := {"preset": for_world(world)}
	if world == null: return style
	var appearance: Dictionary = world.expansion.get("appearance", {})
	if appearance.is_empty() and not PROFILES.get(style["preset"], {}).has("tints"):
		return style
	var terrain: Dictionary = appearance.get("terrains", {}).get(str(world.terrain(tile.x, tile.y)), {})
	var local: Dictionary = appearance.get("tiles", {}).get(tile_key(tile), {})
	style["preset"] = local.get("preset", terrain.get("preset", style["preset"]))
	var defaults: Dictionary = PROFILES.get(style["preset"], {}).get("tints", {})
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
	var profile: Dictionary = PROFILES.get(style["preset"], {})
	var color: Color = profile.get("plain", {}).get(terrain, original)
	if terrain in [0, 1, 8]: color = shift(color, style["preset"], "water")
	return color * modulate(style, "ground")

static func set_preset(world: ShandalarWorld, preset: String) -> bool:
	if world == null or not PROFILES.has(preset): return false
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
	if value.has("preset") and not PROFILES.has(value["preset"]): return false
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
			if not PROFILES.has(style[key]): return false
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
func texture(key: String, source: Texture2D, profile: String) -> Texture2D:
	if source == null or not _remaps(profile) or not supports(key):
		return source
	var memo := "%s:%s:%d" % [profile, key, source.get_instance_id()]
	if not _textures.has(memo):
		var pixels := recolor(source.get_image(), key, profile, GameSkin.scale_of(source))
		_textures[memo] = [source, GameSkin.texture_of(pixels, Vector2i(source.get_size()))]
	return _textures[memo][1]

static func supports(key: String) -> bool:
	return key in ["world_landtile", "world_cstline1", "world_land", "world_land2",
		"world_sland", "world_sland2", "world_map_tiles"]

static func _remaps(profile: String) -> bool:
	var definition: Dictionary = PROFILES.get(profile, {})
	return definition.has("grass") or definition.has("foliage") or definition.has("water")

## Process full-resolution pixels, including a 2x skin's detail. Only
## vegetation and water in their own atlas regions are shifted. Gray stone,
## brown earth, map icons and every alpha byte retain their source values.
static func recolor(source: Image, key: String, profile: String, scale := 1) -> Image:
	var result := source.duplicate() as Image
	if not _remaps(profile) or not supports(key):
		return result
	result.convert(Image.FORMAT_RGBA8)
	var bytes := result.get_data()
	var width := result.get_width()
	var height := result.get_height()
	bytes.resize(width * height * 4)
	var colors := {}
	for y in height:
		for x in width:
			var at := (y * width + x) * 4
			if bytes[at + 3] == 0:
				continue
			# Limit each recipe to its own atlas cells. Coast pieces contain
			# both vegetation and water; choose the recipe by the source hue.
			var style := "grass"
			match key:
				"world_landtile":
					var column := x / (128 * scale)
					if column == 1: style = "water"
					elif column != 0: continue
				"world_cstline1":
					if y < 128 * scale: style = "coast"
				"world_map_tiles":
					if y >= 60 * scale: continue
					var terrain := (x / (13 * scale)) % 16
					if terrain in [0, 1, 8]: style = "water"
					elif not terrain in [2, 6, 10, 15]: continue
					elif terrain == 2: style = "foliage"
				"world_land", "world_land2", "world_sland", "world_sland2":
					var object_column := (x / (128 * scale)) % 5
					if object_column != 4: style = "foliage"
					# Island palms and marsh trees carry water in their own
					# sprites too, including the separately drawn ground half.
					if object_column == (0 if key.ends_with("2") else 1): style = "wet_foliage"
			var rgb := (int(bytes[at]) << 16) | (int(bytes[at + 1]) << 8) | int(bytes[at + 2])
			var kind := 0
			match style:
				"foliage": kind = 1
				"water": kind = 2
				"coast": kind = 3
				"wet_foliage": kind = 4
			var memo := rgb | (kind << 24)
			if not colors.has(memo):
				var original := Color8(bytes[at], bytes[at + 1], bytes[at + 2])
				var recipe := style
				if style == "coast": recipe = "water" if original.h >= 0.42 else "grass"
				elif style == "wet_foliage": recipe = "water" if original.h >= 0.42 else "foliage"
				var changed := shift(original, profile, recipe)
				colors[memo] = (changed.r8 << 16) | (changed.g8 << 8) | changed.b8
			var changed: int = colors[memo]
			bytes[at] = (changed >> 16) & 255
			bytes[at + 1] = (changed >> 8) & 255
			bytes[at + 2] = changed & 255
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes)
	if source.has_mipmaps(): image.generate_mipmaps()
	return image

static func shift(color: Color, profile: String, style := "grass") -> Color:
	if not PROFILES.get(profile, {}).has(style): return color
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
	var recipe: Vector4 = PROFILES[profile][style]
	weight *= recipe.w
	return Color.from_hsv(lerpf(hue, recipe.x, weight),
		lerpf(color.s, color.s * recipe.y, weight),
		minf(1.0, color.v * lerpf(1.0, recipe.z, weight)), color.a)
