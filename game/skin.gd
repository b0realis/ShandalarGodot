class_name GameSkin
extends RefCounted
## Runtime loader for the ORIGINAL-GRAPHICS skin (faithful-graphics layer 3,
## docs/duel-screen-design.md §2).
##
## The game never ships original art; tools/import_original.py copies it
## from the player's own copy of the 1997 game into one of four places,
## checked in order ([method search_dirs]):
##   1. user://original_skin/          (players, exported builds — the
##                                      SKIN FOLDER, movable through the
##                                      `skin_folder` key, [GamePaths])
##   2. <executable>/skin/             (the loose portable copy)
##   3. res://skin/                    (skin/original_skin.zip, mounted
##                                      by [SkinPack] — every platform;
##                                      left closed when the player set
##                                      `use_skin_folder`)
##   4. res://assets/original/         (development — gitignored)
## Every accessor returns null when the asset is absent, and callers fall
## back to the clean built-in skin — so the game is complete without any
## original files, and dresses up automatically when they exist.
##
## BETWEEN THOSE TWO THERE IS NOW A FLOOR THAT IS OURS ([method our_art],
## [method our_font], 2026-09-09): `game/art/`, a handful of pictures this
## project DREW — the six set glyphs and the damage dagger — plus the BODY
## FACE it ships, all of it travelling inside the game's own pack. They
## are checked after every skin directory and before the code-drawn
## fallback, so a player who has imported nothing still sees a symbol on
## the card, a dagger on a wounded creature and rules text in a serif
## chosen for the job, and a player who HAS imported keeps the 1997 art
## and the 1997 lettering exactly as before. Ours is the floor, never the
## ceiling.
##
## Loading a SKIN goes through Image.load_from_file/FontFile, bypassing
## Godot's import pipeline entirely — that is what lets gitignored and
## user:// files work identically in editor, headless, and exported
## builds. What this project ships is loaded the other way round, through
## `load`, because it is inside the pack; the two accessors say so.

## Where a skin may live, in order, as built in. `user://` is the
## player's own and always wins; `res://` is a development checkout. The
## first is only the default: [method search_dirs] reads the folder the
## player named ([method GamePaths.skin_folder]).
const SEARCH_DIRS := ["user://original_skin", "res://assets/original"]

## THE PORTABLE COPY. A build handed to somebody on a USB stick has no
## `user://original_skin` on that machine and no `res://assets` in its
## pack (art is never shipped inside the .pck — see `docs/player-files.md`),
## so it would draw the clean skin and nothing else. A `skin/` folder
## BESIDE THE EXECUTABLE is therefore searched too, after the player's own
## folder and before the checkout: unzip, run, and the art is there.
##
## Empty in the editor, where `OS.get_executable_path()` is Godot itself,
## and in a browser, where there is no executable and no folder beside it.
static func portable_dir() -> String:
	if OS.has_feature("editor") or OS.has_feature("web"):
		return ""
	return OS.get_executable_path().get_base_dir().path_join("skin")


## THE SKIN PACK — the same art as ONE ZIP, `original_skin.zip`, mounted
## into the resource tree by [SkinPack] at boot (or the moment a player
## drops one on the window) and read here as `res://skin/...`. This is
## the path that exists on every platform: beside the executable on a
## desktop, fetched or dropped in a browser, where `user://` is an
## IndexedDB and nothing beside `index.html` can be opened. `[QoL]`,
## 2026-09-08. Searched after the player's own folder and the loose
## portable copy, before a development checkout.
const PACK_DIR := "res://skin"

## Whether [SkinPack] has mounted a zip at [constant PACK_DIR]. Set by it,
## read by [method search_dirs]; nothing else writes it.
static var pack_mounted := false


## [constant SEARCH_DIRS] with the portable copy and the mounted pack
## spliced in, in order of precedence.
static func search_dirs() -> Array:
	var out := [GamePaths.skin_folder()]
	var beside := portable_dir()
	if beside != "":
		out.append(beside)
	if pack_mounted:
		out.append(PACK_DIR)
	out.append(SEARCH_DIRS[1])
	return out


## Forget every loaded asset, so the next request reads the disk again.
## For the moment a skin pack arrives while the game is running — the
## title screen is rebuilt on it ([method SkinPack._arrived]); the other
## screens keep their own derived caches and are told to restart.
static func clear_caches() -> void:
	_texture_cache.clear()
	_font_cache.clear()
	_sound_cache.clear()
	_meta_cache.clear()
	_art_cache.clear()
	_art_missing.clear()
	_set_icon_cache.clear()
	_region_cache.clear()

static var _texture_cache: Dictionary = {}
static var _font_cache: Dictionary = {}

## HOW MANY CARD ARTS [method card_art] KEEPS — the bound the card-state
## catalogue left open (docs/card-states.md §5.6, docs/ROADMAP.md): the
## art cache never evicted, so a full browse of the Deck Builder's grid
## held every art it had ever shown — 909 MB across the pool's 897 crops
## once they carried mipmaps — on a game whose first-class targets
## include a Raspberry Pi. A duel needs at most its two decks' distinct
## cards (about 60), a Deck Builder page columns x rows (about 40 at
## 1280x800, more on a wide window), so 256 is several screens' worth,
## kept LEAST-RECENTLY-USED: at ~1 MB a crop with its mipmaps, about 260
## MB at the very worst, and a browse that keeps scrolling costs disk
## reads for the pictures that fell off the end rather than memory that
## never comes back. An evicted texture that is still on a card stays
## alive on that card (the cache holds one reference, the TextureRect
## another); it is only the cache's claim that goes.
const ART_CACHE_CAP := 256

## [method card_art]'s pictures, youngest LAST — a Dictionary keeps
## insertion order, so the first key is the one to drop. Separate from
## [member _texture_cache], whose sheets are few, sliced by pixel
## coordinates and wanted for the whole run.
static var _art_cache: Dictionary = {}
## The names [method card_art] looked for and found no file — kept apart
## so a missing picture costs one search and no cache slot.
static var _art_missing: Dictionary = {}


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


## Font for a manifest key ("font_title", "font_body"), or null when
## neither a skin nor this project has one — the caller then gets Godot's
## own default face.
##
## THE ORDER IS THE WHOLE POINT (2026-09-09): the player's imported skin,
## then a development checkout's `assets/original`, then OURS ([method
## our_font]), then nothing. An imported face still wins outright — the
## 1997 lettering is what a player who went and found their CD came for —
## and the face this project ships is only what stands under it.
static func font(key: String) -> FontFile:
	if _font_cache.has(key):
		return _font_cache[key]
	var result: FontFile = null
	var path := _find(key + ".ttf")
	if path != "":
		var f := FontFile.new()
		if f.load_dynamic_font(path) == OK:
			result = f
	if result == null:
		result = our_font(key)
	_font_cache[key] = result
	return result


## WHERE THE PICTURES THIS PROJECT DREW LIVE — `game/art/`, written by
## `tools/draw_our_art.gd`. Not `assets/`: that folder is gitignored AND
## excluded from every export preset, because it holds the player's own
## copy of the 1997 game. `game/` is the folder art ships in, and
## `game/icon.png` and `game/boot_splash.png` are the precedent.
const OUR_ART_DIR := "res://game/art"

## OUR OWN ART for a skin key, or null when we drew none for it.
##
## READ THROUGH `load`, NOT `Image.load_from_file`, and that is the whole
## reason this is a separate accessor rather than one more directory on
## [method search_dirs]. Everything else here is read off the FILESYSTEM,
## which is what lets a gitignored checkout folder and a `user://` folder
## behave identically — but these files travel INSIDE the exported pack,
## where there is no filesystem path to open and only the import pipeline
## can reach them.
##
## Not cleared by [method clear_caches]: a skin arriving cannot change
## what this project drew.
static var _our_art_cache: Dictionary = {}

static func our_art(key: String) -> Texture2D:
	if _our_art_cache.has(key):
		return _our_art_cache[key]
	var result: Texture2D = null
	var path := "%s/%s.png" % [OUR_ART_DIR, key]
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			result = loaded
	_our_art_cache[key] = result
	return result


## WHERE THE FACE THIS PROJECT SHIPS LIVES — `game/art/fonts/`, its
## licence beside it. A subfolder and not `game/art/` itself, because the
## two are ours in two different ways: the pictures are ours because this
## project DREW them and they carry its GPL-3.0, the face is ours to ship
## because somebody else drew it and gave it away under the SIL Open Font
## Licence. Keeping them apart is what lets `OFL.txt` sit next to the file
## it actually covers instead of looking as though it covered the glyphs
## too. See `game/art/README.md`.
const OUR_FONT_DIR := "res://game/art/fonts"

## WHICH OF OURS ANSWERS A SKIN KEY.
##
## `font_body` — the rules text, the duel log, every dialog — is
## **Spectral Regular 2.005** (Production Type, OFL 1.1), chosen from a
## survey of twenty-two free serifs on 2026-09-09 because it is the one
## that matches the face the original sets rules text in: x-height 0.450
## of the em against MPlantin's 0.450, and a text width within 1.2%. That
## comparison, and the sizing bug that had to be fixed before it could be
## read (`docs/ROADMAP.md`, "A cell is not a letter"), are the whole of
## why this row says Spectral and not something else.
##
## `font_title` has NO row and is meant not to. The original's display
## face is a blackletter-ish MagicMedieval, nothing free is close to it,
## and a serif standing in for it would be a worse lie than Godot's own
## default — which is what a title still gets here without a skin.
const OUR_FONTS := {"font_body": "Spectral-Regular.ttf"}

## OUR OWN FACE for a skin key, or null when we ship none for it.
##
## READ THROUGH `load`, NOT `FontFile.load_dynamic_font`, for exactly the
## reason [method our_art] reads through `load` and not
## `Image.load_from_file`: a skin is read off the FILESYSTEM, which is
## what lets a gitignored checkout folder and a `user://` folder behave
## alike, but this file travels INSIDE the exported pack, where there is
## no filesystem path to open and only the import pipeline can reach it.
## `game/art/fonts/Spectral-Regular.ttf` imports as a [FontFile]; the
## exported game loads that, on desktop and in a browser alike.
##
## Not cleared by [method clear_caches]: a skin arriving cannot change
## what this project ships. [method font]'s own cache is cleared, so the
## skin's face takes over there the moment it lands.
static var _our_font_cache: Dictionary = {}

static func our_font(key: String) -> FontFile:
	if not OUR_FONTS.has(key):
		return null
	if _our_font_cache.has(key):
		return _our_font_cache[key]
	var result: FontFile = null
	var path := "%s/%s" % [OUR_FONT_DIR, OUR_FONTS[key]]
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is FontFile:
			result = loaded
	_our_font_cache[key] = result
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
	if _art_cache.has(key):
		# Asked for again: re-insert so it is the youngest, and the browse's
		# leftmost column is not what falls off the end.
		var hit: Texture2D = _art_cache[key]
		_art_cache.erase(key)
		_art_cache[key] = hit
		return hit
	if _art_missing.has(key):
		return null
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
	if result == null:
		_art_missing[key] = true
		return null
	_art_cache[key] = result
	while _art_cache.size() > ART_CACHE_CAP:
		for oldest in _art_cache:
			_art_cache.erase(oldest)
			break
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


## HOW COLOURLESS A PIXEL HAS TO BE to count as backdrop — the key
## [method _key_flat_backdrop] applies, and the question [method
## _backdrop_is_flat] asks of the four corners. Tuned to the restyle's
## grey bevel and left exactly where it was.
const BACKDROP_KEY := 0.09

## THE MEDALLION'S RADIUS, as a fraction of the tile's short side.
## MEASURED across all six 1997 files (2026-09-09): the gold ring's
## pixels lie between 14.51 and 17.73 from the centre of a 40px tile —
## 0.363 to 0.443 of the side — and everything past them is stone and
## bevel. 0.45 is the value that keeps the whole ring and none of the
## stone: at it, no gold pixel is lost and 13 of a ring's 181 take the
## feather; at 0.44 the ring starts to thin (36 feathered, one gone),
## and at 0.46 forty stone pixels come back with it.
const MEDALLION_RADIUS := 0.45

## The ORIGINAL's set symbol for a set code (DBArt icons imported as
## set_icon_*), with its backdrop taken away so the symbol sits on a
## card's type strip without a box behind it. Null for sets the original
## gave no symbol (Unlimited, the promos) — as the printed cards have none.
##
## TWO SKINS HAND OVER TWO DIFFERENT DRAWINGS, and the file says which.
## `[1997]`, 2026-09-09: now that the importer decodes every skin key out
## of a genuine install, `Program/DBArt/Antiquit.pic` and its five fellows
## arrive as what 1997 drew — a 40x40 blue-grey STONE TILE with a gold
## ring on it and a black glyph inside the ring. Manalink's restyle, which
## this loader was written against, is 35x36: a gold glyph on a flat grey
## ground, no tile at all. [method cut_set_icon] does the right thing to
## either.
static var _set_icon_cache: Dictionary = {}

static func set_icon(set_code: String) -> Texture2D:
	if _set_icon_cache.has(set_code):
		return _set_icon_cache[set_code]
	var result: Texture2D = null
	var path := _find("set_icon_%s.png" % set_code)
	if path != "":
		var img := Image.load_from_file(path)
		if img != null:
			cut_set_icon(img)
			result = ImageTexture.create_from_image(img)
	else:
		# NEITHER SKIN HAS ONE, so ours does: a gold glyph on nothing,
		# drawn by `tools/draw_our_art.gd` at 48x48 with its ground
		# already transparent — there is no tile and no bevel to cut off,
		# which is why [method cut_set_icon] is not called on it.
		result = our_art("set_icon_%s" % set_code)
	_set_icon_cache[set_code] = result
	return result


## THE CUT, made in place on `img` — what takes a set symbol off whatever
## ground its own skin drew it on. Public because the SHAPE of the cut is
## the thing worth pinning, and a test that would have to import a 1997
## install first pins nothing (`tests/ui/test_skin.gd`).
##
## THE FOUR CORNERS DECIDE, and they decide cleanly. Both skins fill the
## corners of the file with backdrop and nothing else, so the only
## question is what KIND of backdrop it is:
##
##   * Manalink's restyle, 35x36 — every corner is a pure grey, from
##     (126,126,126) down to (45,45,45), hi-lo exactly 0.0 on all six
##     files. The ground is a flat GREY BEVEL and the symbols are
##     strongly coloured, so keying every ACHROMATIC pixel takes the
##     ground and leaves the gold. That cut is unchanged. A geometric one
##     would be WRONG here: the Legends pillar reaches 19.47px from the
##     centre of a 35x36 file and any inscribed circle would saw its
##     capital off.
##   * 1997's own DBArt tile, 40x40 — the corners are the stone's own
##     blue-greys, (178,237,245) and (174,180,204), hi-lo 0.263 and 0.118.
##     The achromatic key cannot see them: it clears 13-14% of the file
##     and leaves the SQUARE TILE standing behind the symbol. But that
##     tile carries a COIN — a gold ring with the glyph inside it — so
##     the cut is GEOMETRIC, the same inscribed-circle cut [method
##     MiniCard.badge_from_slot] makes of the ability sheet: everything
##     past [constant MEDALLION_RADIUS] goes, the last pixel of the rim
##     feathered so the edge does not alias, and what is left is the
##     medallion the 1997 Deck Builder drew on its own toggles.
##
## Which cut a file gets is therefore read OFF THE FILE, never off its
## size: a corner that survives the key is a backdrop the key cannot take.
static func cut_set_icon(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	if _backdrop_is_flat(img):
		_key_flat_backdrop(img)
	else:
		_cut_medallion(img)


## Has this file the flat, colourless ground [method _key_flat_backdrop]
## was written for? Asked of the four corners, which is the one place
## every skin puts backdrop and nothing else.
static func _backdrop_is_flat(img: Image) -> bool:
	var last := Vector2i(img.get_width() - 1, img.get_height() - 1)
	for corner in [Vector2i.ZERO, Vector2i(last.x, 0),
			Vector2i(0, last.y), last]:
		var px := img.get_pixelv(corner)
		var hi: float = maxf(px.r, maxf(px.g, px.b))
		var lo: float = minf(px.r, minf(px.g, px.b))
		if hi - lo >= BACKDROP_KEY:
			return false
	return true


## Take away every ACHROMATIC pixel — the restyle's grey bevel, which is
## light at the top corners and dark at the bottom, so a single flat
## colour key left a black square behind and this does not.
static func _key_flat_backdrop(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			var hi: float = maxf(px.r, maxf(px.g, px.b))
			var lo: float = minf(px.r, minf(px.g, px.b))
			if hi - lo < BACKDROP_KEY:
				px.a = 0.0
				img.set_pixel(x, y, px)


## Take the 1997 stone tile away and leave the coin drawn on it: an
## inscribed circle at [constant MEDALLION_RADIUS], the outermost pixel
## of the rim feathered. Multiplies the alpha rather than setting it, so
## a file that came in with a mask keeps it.
static func _cut_medallion(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var centre := Vector2((w - 1) / 2.0, (h - 1) / 2.0)
	var radius := mini(w, h) * MEDALLION_RADIUS
	for y in h:
		for x in w:
			var dist := (Vector2(x, y) - centre).length()
			if dist <= radius - 1.0:
				continue
			var px := img.get_pixel(x, y)
			px.a *= maxf(0.0, radius - dist) if dist < radius else 0.0
			img.set_pixel(x, y, px)


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
		if DirAccess.dir_exists_absolute(locate(dir)):
			return true
	return false


## A search directory (or a file in one) as the filesystem sees it. The
## mounted pack stays a `res://` path — its files live inside a zip the
## engine reads through `res://`, and globalizing it would name a folder
## beside the binary that does not exist. Everything else becomes an
## absolute path, which is what makes `user://` and a gitignored checkout
## folder read the same way in the editor, headless and exported.
##
## Public because [PortraitLibrary] loads its pictures the same way and
## must make the same distinction: a portrait listed out of the pack is
## read at its `res://skin/portraits/` name, not at a globalized one
## (2026-09-08 — the pack's portraits were listed in the chooser but
## drew nothing, in the package and the browser alike).
static func locate(path: String) -> String:
	if path.begins_with(PACK_DIR):
		return path
	return ProjectSettings.globalize_path(path)


static func _find(filename: String) -> String:
	for dir in search_dirs():
		var path := locate(dir + "/" + filename)
		if FileAccess.file_exists(path):
			return path
	return ""
