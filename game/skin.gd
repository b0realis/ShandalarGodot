class_name GameSkin
extends RefCounted
## Runtime loader for the ORIGINAL-GRAPHICS skin (faithful-graphics layer 3,
## docs/duel-screen-design.md §2).
##
## The game never ships original art; tools/import_original.py copies it
## from the player's own copy of the 1997 game into one of two places,
## checked in order:
##   1. user://original_skin/          (players, exported builds)
##   2. res://assets/original/         (development — gitignored)
## Every accessor returns null when the asset is absent, and callers fall
## back to the clean built-in skin — so the game is complete without any
## original files, and dresses up automatically when they exist.
##
## Loading goes through Image.load_from_file/FontFile, bypassing Godot's
## import pipeline entirely — that is what lets gitignored and user://
## files work identically in editor, headless, and exported builds.

## Where a skin may live, in order. `user://` is the player's own and
## always wins; `res://` is a development checkout.
const SEARCH_DIRS := ["user://original_skin", "res://assets/original"]

## THE PORTABLE COPY. A build handed to somebody on a USB stick has no
## `user://original_skin` on that machine and no `res://assets` in its
## pack (art is never shipped inside the .pck — see `docs/player-files.md`),
## so it would draw the clean skin and nothing else. A `skin/` folder
## BESIDE THE EXECUTABLE is therefore searched too, after the player's own
## folder and before the checkout: unzip, run, and the art is there.
##
## Empty in the editor, where `OS.get_executable_path()` is Godot itself.
static func portable_dir() -> String:
	if OS.has_feature("editor"):
		return ""
	return OS.get_executable_path().get_base_dir().path_join("skin")


## [constant SEARCH_DIRS] with the portable copy spliced in.
static func search_dirs() -> Array:
	var beside := portable_dir()
	if beside == "":
		return SEARCH_DIRS
	return [SEARCH_DIRS[0], beside, SEARCH_DIRS[1]]

static var _texture_cache: Dictionary = {}
static var _font_cache: Dictionary = {}


## Texture for a manifest key ("card_frame_red", "duel_pattern_green"...)
## or null when the skin doesn't provide it.
static func texture(key: String) -> Texture2D:
	if _texture_cache.has(key):
		return _texture_cache[key]
	var result: Texture2D = null
	var path := _find(key + ".png")
	if path != "":
		var img := Image.load_from_file(path)
		if img != null:
			result = ImageTexture.create_from_image(img)
	_texture_cache[key] = result
	return result


## Font for a manifest key ("font_title", "font_body") or null.
static func font(key: String) -> FontFile:
	if _font_cache.has(key):
		return _font_cache[key]
	var result: FontFile = null
	var path := _find(key + ".ttf")
	if path != "":
		var f := FontFile.new()
		if f.load_dynamic_font(path) == OK:
			result = f
	_font_cache[key] = result
	return result


static var _sound_cache: Dictionary = {}


## Sound for a manifest key ("sfx_toss", "sfx_cast_red", "music_duel") or
## null. WAV loading uses AudioStreamWAV.load_from_file (Godot 4.4+),
## which — like the texture path — bypasses the import pipeline so
## user:// and gitignored files work everywhere.
static func sound(key: String) -> AudioStream:
	if _sound_cache.has(key):
		return _sound_cache[key]
	var result: AudioStream = null
	var path := _find(key + ".wav")
	if path != "":
		result = AudioStreamWAV.load_from_file(path)
	_sound_cache[key] = result
	return result


## SIDECAR METADATA for a skin key — `<key>.json` beside `<key>.png`, in
## the same search order as everything else here. `{}` when there is none,
## when it does not parse, or when it is not an object; every caller wants
## the same "there is nothing here" from all three.
##
## Almost every sheet this project slices has a grid the CODE knows
## ([ManaIcons]'s 19 cells, [MiniCard]'s badge slots, [SetBadges]'s rows)
## because the original's file is a fixed shape. The transcoded coin-toss
## movies are the first that are not: their frame size, frame count and
## frame rate come off whatever AVI the player owns, so the importer has
## to write them down. See `tools/import_original.py`'s VIDEOS block and
## [CoinToss].
static var _meta_cache: Dictionary = {}

static func metadata(key: String) -> Dictionary:
	if _meta_cache.has(key):
		return _meta_cache[key]
	var result: Dictionary = {}
	var path := _find(key + ".json")
	if path != "":
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			result = parsed
	_meta_cache[key] = result
	return result


## Per-card art for the enlarged card preview: cardart/<snake_name>.png in
## any skin dir (or res://assets/cardart/ for community art packs). The
## Manalink-era snapshot packs card art inside CardArtLib.dll, so no
## importer path exists yet — drop PNGs in and they appear automatically;
## null (a graceful placeholder) otherwise.
static func card_art(card_name: String) -> Texture2D:
	var key := "cardart/" + _snake(card_name)
	if _texture_cache.has(key):
		return _texture_cache[key]
	var result: Texture2D = null
	var path := ""
	# tools/fetch_card_art.py downloads Scryfall art_crop JPGs (the s30
	# approach, pre-fetched) into assets/cardart/; skin dirs may override
	# with PNGs (community art packs).
	for candidate in [_find(key + ".png"), _find(key + ".jpg"),
			ProjectSettings.globalize_path("res://assets/cardart/%s.jpg" % _snake(card_name)),
			ProjectSettings.globalize_path("res://assets/cardart/%s.png" % _snake(card_name))]:
		if candidate != "" and FileAccess.file_exists(candidate):
			path = candidate
			break
	if path != "":
		var img := Image.load_from_file(path)
		if img != null:
			# MIPMAPS, and only on the CARD ART. A Scryfall art crop is
			# ~582x467 and the small card draws it at ~110px wide, so
			# every card on the table is a 5:1 MINIFICATION — and a
			# minification with no mipmap chain samples one source pixel
			# per screen pixel and lays a regular diamond lattice over any
			# finely detailed region (`docs/card-states.md` §5.6: the
			# moire on the lion's fur, reproduced exactly by a
			# nearest-neighbour downscale in PIL). One `generate_mipmaps`
			# here plus `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` on the small
			# card's art rect (`MiniCard._build_face`) is the whole fix.
			#
			# It costs a THIRD more texture memory for each art actually
			# drawn (~0.36 MB on a 582x467 RGBA8 crop) and nothing at all
			# for one that is never asked for, because this cache is lazy.
			# `GameSkin.texture` deliberately does NOT do this: the 1997
			# sheets are sliced by pixel coordinates and several of them
			# (the ability sheet, the mana stripes) are drawn at or near
			# their native size.
			img.generate_mipmaps()
			result = ImageTexture.create_from_image(img)
	_texture_cache[key] = result
	return result


## Short label for a set the original gave NO symbol (Unlimited and the
## promos never printed one). Every card still shows its set: an icon
## when one exists, this text otherwise.
## Split into [stem, SUPERSCRIPT suffix] so an edition renders the way it
## is written — 2 with a raised "nd", 4 with a raised "th" — rather than
## as flat text.
const SET_LABELS := {
	"2ed": ["2", "nd"],
	"4ed": ["4", "th"],
	"phpr": ["PR", ""],
}

## The stem of a set's short label ("2", "PR", or the code in capitals).
static func set_label(set_code: String) -> String:
	if SET_LABELS.has(set_code):
		return SET_LABELS[set_code][0]
	return set_code.to_upper()


## The raised suffix of a set's short label ("nd", "th", or nothing).
static func set_label_suffix(set_code: String) -> String:
	if SET_LABELS.has(set_code):
		return SET_LABELS[set_code][1]
	return ""


## The ORIGINAL's set symbol for a set code (DBArt icons imported as
## set_icon_*), with its flat backdrop keyed out so the symbol sits on a
## card's type strip without a box behind it. Null for sets the original
## gave no symbol (Unlimited, the promos) — as the printed cards have none.
static var _set_icon_cache: Dictionary = {}

static func set_icon(set_code: String) -> Texture2D:
	if _set_icon_cache.has(set_code):
		return _set_icon_cache[set_code]
	var result: Texture2D = null
	var path := _find("set_icon_%s.png" % set_code)
	if path != "":
		var img := Image.load_from_file(path)
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
			# The backdrop is a GREY BEVEL (measured: light grey at the top
			# corners, dark at the bottom), so a single flat-colour key
			# left a black square behind. The symbols themselves are
			# strongly coloured, so key every ACHROMATIC pixel instead.
			for y in img.get_height():
				for x in img.get_width():
					var px := img.get_pixel(x, y)
					var hi: float = maxf(px.r, maxf(px.g, px.b))
					var lo: float = minf(px.r, minf(px.g, px.b))
					if hi - lo < 0.09:
						px.a = 0.0
						img.set_pixel(x, y, px)
			result = ImageTexture.create_from_image(img)
	_set_icon_cache[set_code] = result
	return result


## One SUB-RECTANGLE of a skin sheet, as its own texture — cached.
##
## Most sheets already have a decoder that knows their grid
## ([method ManaIcons.symbol], [method MiniCard.badge_from_slot],
## [method FilterBar.sheet_cell]…). This is the generic cutter for the
## sheets that have none: the ones read through a published Rect2 rather
## than a cell index (the Phase Bar's and Combat Bar's own
## `active_region`), and the frame strips like `Target.pic`. The HELP
## SCREEN needs them, and it must not reach into another screen's private
## art code to get them.
##
## Returns null without the skin, or when the rectangle falls outside the
## sheet — the caller falls back exactly as it does for a missing texture.
static var _region_cache: Dictionary = {}

static func region(key: String, rect: Rect2i) -> Texture2D:
	var cache_key := "%s|%s" % [key, rect]
	if _region_cache.has(cache_key):
		return _region_cache[cache_key]
	var result: Texture2D = null
	var sheet := texture(key)
	if sheet != null and rect.size.x > 0 and rect.size.y > 0 \
			and rect.position.x >= 0 and rect.position.y >= 0 \
			and rect.end.x <= sheet.get_width() \
			and rect.end.y <= sheet.get_height():
		result = ImageTexture.create_from_image(sheet.get_image().get_region(rect))
	_region_cache[cache_key] = result
	return result


## The REAL full-card scan (Scryfall border_crop, fetched by
## tools/fetch_card_art.py as <name>_card.jpg) — piles show it as their
## fully-visible bottom card, exactly like the original. Null when absent.
static func card_scan(card_name: String) -> Texture2D:
	return card_art(card_name + " card")   # _snake maps it to <name>_card


## Card name → filename stem, matching the card-file convention
## ("Mishra's Factory" → "mishra_s_factory").
static func _snake(card_name: String) -> String:
	var out := ""
	for ch in card_name.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_suffix("_").trim_prefix("_")


## True when any original skin directory exists (UI may mention it).
static func is_present() -> bool:
	for dir in search_dirs():
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir)):
			return true
	return false


static func _find(filename: String) -> String:
	for dir in search_dirs():
		var global := ProjectSettings.globalize_path(dir + "/" + filename)
		if FileAccess.file_exists(global):
			return global
	return ""
