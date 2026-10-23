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
## The first two are not searched while a skin zip is worn: one skin
## dresses the game ([method search_dirs]). In each place the skin's own
## `catalogue.txt` may say which of its files stands in which place, and
## a picture may come at up to four times its 1997 size (THE CATALOGUE,
## THE 2x PICTURES below).
## Every accessor returns null when the asset is absent, and callers fall
## back to the clean built-in skin — so the game is complete without any
## original files, and dresses up automatically when they exist.
##
## AND THERE IS WHAT IS OURS ([method our_art], [method our_font],
## 2026-09-09): `game/art/`, a handful of pictures this project DREW — the
## six set glyphs and the damage dagger — plus the BODY FACE it ships, all
## of it travelling inside the game's own pack. Until 2026-10-15 they were
## a floor under the skin; since then they are what EVERY player sees, and
## a skin's file under those names is not read ([method set_icon],
## `MiniCard.ALWAYS_OURS`, [method font]; the owner: *"we build our own
## damage dagger just to be independent"*, *"Spectral, with the dialog
## spacing tightened for everyone!!"*). Every other key is still the
## skin's when it has one, the 1997 title lettering among them.
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
## On Android the executable is the system's, so the `skin/` folder sits
## in the app's shared-storage corner instead, beside the card folder
## ([method GamePaths.android_files_dir]) — the play copy's layout.
static func portable_dir() -> String:
	if OS.has_feature("editor") or OS.has_feature("web"):
		return ""
	return portable_dir_for(GamePaths.android_files_dir())


## [method portable_dir] with the Android corner given: `skin/` under
## [param files_dir] when there is one, beside the executable otherwise.
static func portable_dir_for(files_dir: String) -> String:
	if files_dir != "":
		return files_dir.trim_suffix("/").path_join("skin")
	return GamePaths.executable_dir(OS.get_executable_path(),
		OS.has_feature("macos")).path_join("skin")


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

## Whether one of those zips is a SKIN (not only card art) — then that
## zip is the skin worn. Set by [SkinPack] alone, beside [member
## pack_mounted].
static var zip_worn := false


## [constant SEARCH_DIRS] with the portable copy and the mounted pack
## spliced in, in order of precedence.
##
## ONE SKIN IS WORN (2026-10-17; the owner: *"A skin is a skin"*). With a
## skin zip worn the loose folders — the skin folder and the `skin/`
## beside the executable — are not searched: until then they were
## searched FIRST, file by file, so a player who had imported the 1997
## pictures into the skin folder and then chose another skin zip (the 2x
## one) kept seeing the folder's 1997 pictures in every place both had. A
## folder dresses the game when no skin zip is worn, or when the player
## leaves the zip closed for it (`use_skin_folder`, [SkinPack]). The
## checkout's own `assets/original` stays last, for development.
##
## [param every]: all of them whatever is worn — for the CARD ART, which is
## no part of a skin and travels apart (a loose `cardart/` folder beside
## the game is read with any skin, [method card_art]).
static func search_dirs(every := false) -> Array:
	var out := []
	if every or not zip_worn:
		out.append(GamePaths.skin_folder())
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
	_original_cache.clear()
	_catalogue_cache.clear()

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


## THE SEASONS' CARD BACKS: two pictures of this project's own
## (`game/art/`) that every card back in the game wears for a while each
## year, over the skin's back or the plain one alike — not over a picture
## of the player's own ([CardBack]), and not at all with the Options
## switch off ([method seasons_on]).
const SEASON_BACKS := {"halloween": "card_back_moon", "christmas": "card_back_holly"}
## The date [method season] reads, as `{"month": m, "day": d}`; empty
## means the player's own calendar, today. The test runner pins it
## (`tests/support/pin_calendar.gd`) so the suite answers the same on any
## day of the year.
static var season_date: Dictionary = {}


## Which season [param month]/[param day] falls in, or "": the week up to
## Halloween, and the two weeks over Christmas and the New Year.
static func season_for(month: int, day: int) -> String:
	if month == 10 and day >= 25:
		return "halloween"
	if (month == 12 and day >= 21) or (month == 1 and day <= 3):
		return "christmas"
	return ""


static func season() -> String:
	var date := season_date if not season_date.is_empty() \
		else Time.get_date_dict_from_system()
	return season_for(int(date.get("month", 0)), int(date.get("day", 0)))


## Options → Card back → `Seasonal card backs`. The owner, 2026-10-19:
## *"for seasonal card backs lets implement an on/off in options (as some
## users may not like this)"*. On unless the player switched it off; the
## key is written only then.
const KEY_SEASONS := "seasonal_card_backs"


static func seasons_on() -> bool:
	return bool(Settings.get_value(KEY_SEASONS, true))


## The season's back when today is in one and the switch is on, else null.
static func season_back() -> Texture2D:
	var seasonal := season()
	if seasonal == "" or not seasons_on():
		return null
	return our_art(String(SEASON_BACKS[seasonal]))


## THE CATALOGUE (2026-10-17). A skin may carry `catalogue.txt` at its
## top, beside its pictures, saying which of its files the game wears in
## each place. The owner: *"game should just pickup images according to
## some catalogue in the skin where every image is assigned to a specific
## location game looks for (not looking for specific image file names) -
## maybe the key should be original lile names but modders can then put
## any image to these names"*. One line per place:
##
##     title_background.png = title_background@2x.png
##
## The left side is the SLOT, named by the file the game looks for (the
## 1997 names, `docs/skin-catalogue.txt`); the right side is any file of
## the same skin. A `#` line is a comment and the first `=` splits; a file
## that would leave the skin (a leading `/`, a `..` part, a backslash) is
## not read, and a slot named twice takes its last line
## ([method parse_catalogue]). A slot the catalogue does not name — every
## slot of every skin made before it — is looked for under its own name,
## and so is one whose line names a file that is not there. Each place
## ([method search_dirs]) reads its own: a loose folder's catalogue
## speaks for that folder, the worn zip's for the zip.
const CATALOGUE := "catalogue.txt"

static var _catalogue_cache: Dictionary = {}


## [param text] as `{slot: file}` — the rules above, and nothing else
## (`tools/skin_catalogue.py` reads a catalogue the same way for --check).
static func parse_catalogue(text: String) -> Dictionary:
	var out := {}
	for raw in text.trim_prefix("\ufeff").split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var at := line.find("=")
		if at < 0:
			continue
		var slot := line.substr(0, at).strip_edges()
		var file := line.substr(at + 1).strip_edges()
		if slot == "" or file == "" or file.begins_with("/") \
				or file.contains("\\") or ".." in file.split("/"):
			continue
		out[slot] = file
	return out


## The catalogue of the place [param dir] ([method search_dirs]), `{}`
## when it has none.
static func catalogue_at(dir: String) -> Dictionary:
	if not _catalogue_cache.has(dir):
		var path := locate(dir + "/" + CATALOGUE)
		_catalogue_cache[dir] = parse_catalogue(FileAccess.get_file_as_string(path)) \
			if FileAccess.file_exists(path) else {}
	return _catalogue_cache[dir]


## THE @2x NAME, STILL READ. 0.50.28's tool wrote each big picture as
## `<key>@2x.png` beside `<key>.png`, and 0.50.29 wore it from there; the
## owner, the same evening: *"I allready have built 2x skin so we will
## reuse it also so keep the previous skin filenames also valid for skin
## reader ;)"*. So a picture slot the catalogue does not name wears its
## `@2x` file when the place has one — an unwritten line `x.png =
## x@2x.png` — and a written `x.png = x.png` picks the 1x file over it.
## The hi-res skin tools/upscale_skin.py writes since 0.50.31 needs
## neither: its pictures are under their own names, at twice the size.
const SCALED_SUFFIX := "@2x"


## The `@2x` name of a picture's file: `title_background.png` ->
## `title_background@2x.png`.
static func scaled_path(path: String) -> String:
	return path.get_basename() + SCALED_SUFFIX + "." + path.get_extension()


## Whether [param file] is a `@2x` picture rather than a slot of its own —
## the portrait chooser folds one into the face it doubles.
static func is_scaled_name(file: String) -> bool:
	return file.get_basename().ends_with(SCALED_SUFFIX)


## What the place [param dir] wears for [param slot], `{path, own}`, the
## path empty when the place has nothing for it: the file its catalogue
## names, else the slot's `@2x` picture, else the slot's own file. `own`
## is the slot's own file in the same place when the path is another one
## ("" otherwise) — the 1x pixels [method original] reads.
static func _in_place(dir: String, slot: String) -> Dictionary:
	var own := locate(dir + "/" + slot)
	var own_there := FileAccess.file_exists(own)
	var listed := String(catalogue_at(dir).get(slot, ""))
	if listed != "":
		var path := locate(dir + "/" + listed)
		if FileAccess.file_exists(path):
			return {"path": path, "own": own if own_there and path != own else ""}
	if slot.get_extension() == "png" and not is_scaled_name(slot):
		var twice := locate(dir + "/" + scaled_path(slot))
		if FileAccess.file_exists(twice):
			return {"path": twice, "own": own if own_there else ""}
	return {"path": own if own_there else "", "own": ""}


## [param path], a file the portrait chooser found by listing a folder,
## as its place wears it: `{path, own}` the way [method _slot] answers.
## The place is the search folder it lies in, else its own folder.
static func worn(path: String) -> Dictionary:
	var dir := path.get_base_dir()
	for place in search_dirs():
		if path.begins_with(String(place) + "/"):
			dir = place
			break
	var found := _in_place(dir, path.trim_prefix(dir + "/"))
	return found if String(found["path"]) != "" else {"path": locate(path), "own": ""}


## THE 2x PICTURES — the sizes a skin's picture may come in (2026-10-17;
## the owner: *"Lets just document what kind of resoutions are supported
## ao croppers n game Know what to do"*).
##
## The game is laid out for 1280x800 around the 1997 pictures and drawn
## at the screen's real resolution, so on a big screen a 1997 picture is
## stretched. A skin may therefore give any picture at 1x, 2x, 3x or 4x
## ITS SLOT'S SIZE — [constant SIZES], the 1997 file's, or, failing that,
## the size of the 1x file the same place holds under the slot's own name
## (a portrait beside its 2x copy) — and the game wears it at the slot's
## size with all its pixels ([method picture]). Any other size is worn at
## its own size, as every picture was before: right for what is stretched
## (backdrops, panels), wrong for a SHEET, whose cells are cut at fixed
## coordinates. `docs/skin-catalogue.txt` (SIZES AND SCALES) says so to
## the people who draw them.
##
## A big picture is an ImageTexture of the big image whose SIZE is
## overridden to the slot's ([method texture_of]). Everything that DRAWS
## it therefore keeps working in 1997 coordinates — measured under Xvfb
## on 2026-10-17: AtlasTexture regions, NinePatchRect and StyleBoxTexture
## margins, `region_rect`, tiling and `draw_texture_rect_region` all read
## the overridden size — and only code that reads the PIXELS
## (`get_image()`) sees the big picture. That code asks [method scale_of],
## cuts with [method cut], wraps what it made in [method texture_of], and
## decides colour keys on [method original]'s pixels at the slot's size,
## which [method lift_alpha] carries up to the big ones.
##
## Until 2026-10-17 the big pictures were COPIES, `<key>@2x.png` beside
## the 1997 file, out of a zip of their own mounted beside the skin and
## worn under a switch (`skin_2x`, Options > Skin > "Wear the 2x
## pictures"). The owner: *"Users are confused and also when they turn
## off the wear 2d pictures the game still Uses them! ... A skin is a
## skin and gets applied after game reset. No switches."* — and *"hires
## skin zip is hires, low res skin zip is low res oroginal - simple"*.
## The switch was read as each picture first loaded, so turning it off
## changed nothing on screen until a restart. Now a big picture is simply
## what the worn skin holds. The hi-res skin `tools/upscale_skin.py`
## writes is the 1997 skin's own files, the same names and the same
## count, with its pictures at twice the size (the owner: *"Each skin
## pack zip should contain all required assets. Just in the upscaled the
## relevant assets are upscaled!"*), chosen in Options > Skin like the
## 1997 one; mixing is a 1997 picture put back under its own name, or a
## catalogue line.

## THE 1997 SIZE OF EVERY PICTURE SLOT, by key — what a picture's size is
## measured against ([method scale_for]). The sizes `docs/skin-catalogue.csv`
## lists, measured off a 1997 skin by `tools/skin_catalogue.py`;
## `tools/test_skin_catalogue.py` holds this table to that file. The
## coin-toss sheets are not here (their `.json` describes their own
## pixels) and neither are the portraits (fitted to their frame, any size).
const SIZES := {
	"title_background": Vector2i(640, 480),
	"menu_background": Vector2i(640, 480),
	"character_select_background": Vector2i(640, 480),
	"adventure_hero_background": Vector2i(640, 480),
	"world_landtile": Vector2i(768, 64),
	"world_cstline1": Vector2i(448, 384),
	"world_land": Vector2i(640, 913),
	"world_land2": Vector2i(640, 913),
	"world_sland": Vector2i(640, 913),
	"world_sland2": Vector2i(640, 913),
	"world_roads": Vector2i(768, 128),
	"world_locatn01": Vector2i(768, 512),
	"world_locatn02": Vector2i(1152, 384),
	"world_locatn03": Vector2i(768, 512),
	"world_locatn04": Vector2i(1152, 384),
	"world_locatn05": Vector2i(768, 512),
	"world_locatn06": Vector2i(1152, 384),
	"world_locatn07": Vector2i(768, 512),
	"world_castles1": Vector2i(1152, 384),
	"world_castles2": Vector2i(1152, 384),
	"world_ego_m": Vector2i(770, 864),
	"world_ego_f": Vector2i(770, 864),
	"world_sego_f": Vector2i(770, 864),
	"world_magics": Vector2i(624, 270),
	"world_amulets": Vector2i(60, 17),
	"world_frame": Vector2i(1024, 768),
	"duel_pattern_white": Vector2i(721, 381),
	"duel_pattern_blue": Vector2i(721, 381),
	"duel_pattern_black": Vector2i(888, 381),
	"duel_pattern_red": Vector2i(888, 381),
	"duel_pattern_green": Vector2i(721, 381),
	"duel_picture_white": Vector2i(888, 381),
	"duel_picture_blue": Vector2i(721, 381),
	"duel_picture_black": Vector2i(888, 381),
	"duel_picture_red": Vector2i(721, 381),
	"duel_picture_green": Vector2i(888, 381),
	"duel_mana_white": Vector2i(721, 381),
	"duel_mana_blue": Vector2i(721, 381),
	"duel_mana_black": Vector2i(721, 381),
	"duel_mana_red": Vector2i(721, 381),
	"duel_mana_green": Vector2i(721, 381),
	"card_back": Vector2i(228, 323),
	"card_frame_white": Vector2i(228, 325),
	"card_frame_blue": Vector2i(228, 325),
	"card_frame_black": Vector2i(228, 325),
	"card_frame_red": Vector2i(228, 325),
	"card_frame_green": Vector2i(228, 325),
	"card_frame_gold": Vector2i(228, 325),
	"card_frame_artifact": Vector2i(228, 325),
	"card_frame_land_white": Vector2i(228, 325),
	"card_frame_land_blue": Vector2i(228, 325),
	"card_frame_land_black": Vector2i(228, 325),
	"card_frame_land_red": Vector2i(228, 325),
	"card_frame_land_green": Vector2i(228, 325),
	"life_panel_white": Vector2i(120, 88),
	"life_panel_blue": Vector2i(120, 88),
	"life_panel_black": Vector2i(120, 88),
	"life_panel_red": Vector2i(120, 88),
	"life_panel_green": Vector2i(120, 88),
	"duelist_face_white": Vector2i(120, 88),
	"duelist_face_blue": Vector2i(120, 88),
	"duelist_face_black": Vector2i(120, 88),
	"duelist_face_red": Vector2i(120, 88),
	"duelist_face_green": Vector2i(120, 88),
	"panel_stone": Vector2i(400, 350),
	"versus_background": Vector2i(659, 394),
	"versus_splash": Vector2i(500, 400),
	"panel_dark_stone": Vector2i(289, 274),
	"panel_knot": Vector2i(481, 323),
	"panel_end_duel": Vector2i(272, 422),
	"attack_panel": Vector2i(888, 316),
	"mana_pool_panel": Vector2i(128, 188),
	"spell_chain_panel": Vector2i(139, 200),
	"message_panel": Vector2i(600, 35),
	"big_card_panel": Vector2i(552, 402),
	"button_normal": Vector2i(131, 36),
	"button_pressed": Vector2i(131, 36),
	"button_disabled": Vector2i(131, 36),
	"stat_buttons": Vector2i(768, 48),
	"begin_menu": Vector2i(265, 432),
	"phase_bar": Vector2i(82, 760),
	"combat_bar": Vector2i(164, 760),
	"attack_min": Vector2i(39, 70),
	"attack_sword": Vector2i(56, 132),
	"attack_shield": Vector2i(44, 128),
	"attack_bones": Vector2i(777, 70),
	"hand_panel_white": Vector2i(145, 51),
	"hand_panel_blue": Vector2i(145, 51),
	"hand_panel_black": Vector2i(145, 51),
	"hand_panel_red": Vector2i(145, 51),
	"hand_panel_green": Vector2i(145, 51),
	"grave_panel_white": Vector2i(61, 91),
	"grave_panel_blue": Vector2i(61, 91),
	"grave_panel_black": Vector2i(61, 91),
	"grave_panel_red": Vector2i(61, 91),
	"grave_panel_green": Vector2i(61, 91),
	"mana_stripes": Vector2i(54, 126),
	"summon_sick": Vector2i(194, 97),
	"state_dying": Vector2i(194, 97),
	"state_cant_target": Vector2i(130, 65),
	"state_will_untap": Vector2i(110, 59),
	"ability_icons": Vector2i(22, 396),
	"damage_marker": Vector2i(94, 20),
	"card_counters": Vector2i(24, 750),
	"target_cursor": Vector2i(122, 61),
	"set_icon_atq": Vector2i(40, 40),
	"set_icon_arn": Vector2i(40, 40),
	"set_icon_past": Vector2i(40, 40),
	"set_icon_drk": Vector2i(40, 40),
	"set_icon_4ed": Vector2i(40, 40),
	"set_icon_leg": Vector2i(40, 40),
	"card_set_symbols": Vector2i(330, 15),
	"mana_symbols": Vector2i(342, 18),
	"filter_icons": Vector2i(360, 120),
	"filter_icons_hover": Vector2i(360, 120),
	"filter_icons_pressed": Vector2i(360, 120),
	"deck_slot_plaques": Vector2i(585, 200),
	"deck_title_slab": Vector2i(291, 73),
	"deck_bar_ground": Vector2i(1006, 198),
	"deck_tile_olive": Vector2i(32, 32),
	"deck_tile_slate": Vector2i(32, 32),
}

## Up to how many times its slot's size a picture is worn as a big one.
const MAX_SCALE := 4
## Where a big texture keeps its scale, and the slot's own 1x file.
const SCALE_META := &"skin_scale"
const ORIGINAL_META := &"skin_original"


## How many times [param slot] a picture of [param size] is: 2, 3 or 4
## for an exact multiple, 1 for anything else (and for no slot size).
static func scale_for(size: Vector2i, slot: Vector2i) -> int:
	if slot.x <= 0 or slot.y <= 0:
		return 1
	for scale in range(2, MAX_SCALE + 1):
		if size == slot * scale:
			return scale
	return 1


## A skin picture's texture: the file at [param path], worn at its slot's
## size when it is a whole multiple of it. [param key] names the slot
## ([constant SIZES]); [param own] is the slot's own 1x file in the same
## place when the catalogue wears another one, "" when there is none.
## Null when unreadable.
static func picture(path: String, key := "", own := "") -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null:
		return null
	if own == path:
		own = ""
	var slot: Vector2i = SIZES.get(key, Vector2i.ZERO)
	var scale := scale_for(img.get_size(), slot)
	if scale == 1 and own != "":
		# No 1997 size it fits: the slot's own file says what 1x is here.
		var one := Image.load_from_file(own)
		if one != null:
			slot = one.get_size()
			scale = scale_for(img.get_size(), slot)
	if scale == 1:
		return ImageTexture.create_from_image(img)
	var tex := texture_of(img, slot)
	if own != "":
		# Only the path: [method original] reads the 1x pixels for the few
		# cutters that key or measure, and keeping every 1x image beside
		# its big texture would hold the skin twice.
		tex.set_meta(ORIGINAL_META, own)
	return tex


## How many image pixels [param tex] holds per drawn pixel: 2 for a 2x
## picture (and for what [method texture_of] made from one), 1 otherwise.
static func scale_of(tex: Texture2D) -> int:
	if tex == null:
		return 1
	return int(tex.get_meta(SCALE_META, 1))


## A texture of [param img] that is drawn at [param logical] — the size
## its slot has. Same size: a plain texture.
static func texture_of(img: Image, logical: Vector2i) -> ImageTexture:
	var tex := ImageTexture.create_from_image(img)
	if logical.x > 0 and img.get_size() != logical:
		tex.set_size_override(logical)
		tex.set_meta(SCALE_META, img.get_width() / logical.x)
	return tex


## [param rect], in drawn (1997) pixels, as [param tex]'s image pixels.
static func image_rect(tex: Texture2D, rect: Rect2i) -> Rect2i:
	var scale := scale_of(tex)
	return Rect2i(rect.position * scale, rect.size * scale)


## [param rect] (1997 pixels) cut out of [param tex] at its own
## resolution — twice the size from a 2x picture.
static func cut(tex: Texture2D, rect: Rect2i) -> Image:
	return tex.get_image().get_region(image_rect(tex, rect))


## [param tex]'s pixels at its drawn size, for code that MEASURES a
## picture or keys a colour out of it. A 1x texture's own image. A big
## one's: the slot's own 1x file when the place holds one at that size
## (a 1997 picture beside its `@2x` one), so an exact key (pure black,
## near white) answers on the 1997 palette, never on an upscaler's blend
## of it — else the big picture shrunk back ([method shrunk]), whose every
## pixel is the average of the block it stands for. The hi-res skin keeps
## no 1x files, so tools/upscale_skin.py makes the pictures whose keys or
## measures an upscaler's blend would move (the mana stripes, the set
## symbol strip, the target cursor, the grave plates, the territories'
## edge) average back to their 1997 pixels exactly, block by block.
static var _original_cache: Dictionary = {}

static func original(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var scale := scale_of(tex)
	if scale == 1:
		return tex.get_image()
	var drawn := Vector2i(tex.get_size())
	if tex.has_meta(ORIGINAL_META):
		var path := String(tex.get_meta(ORIGINAL_META))
		if not _original_cache.has(path):
			_original_cache[path] = Image.load_from_file(path)
		var img: Image = _original_cache[path]
		if img != null and img.get_size() == drawn:
			return img.duplicate() as Image
	return shrunk(tex.get_image(), scale)


## [param img] brought down to a [param scale]th of its size, a block's
## average per pixel: halved by halving while it can be (`shrink_x2`
## averages exactly), resampled for the rest (a 3x picture).
static func shrunk(img: Image, scale: int) -> Image:
	var out := img.duplicate() as Image
	var target := img.get_size() / scale
	var left := scale
	while left % 2 == 0:
		out.shrink_x2()
		left /= 2
	if out.get_size() != target:
		out.resize(target.x, target.y, Image.INTERPOLATE_TRILINEAR)
	return out


## [param big] with the transparency [param small] decided at the drawn
## size: smoothed up to big's size and cut at half, so an edge stays on
## or off the way the 1x key left it, without the 1997 staircase — the
## same step tools/upscale_skin.py takes for a cut-out. A [param small]
## of big's own size is used as it is. Both are RGBA8; big is changed and
## returned.
static func lift_alpha(small: Image, big: Image) -> Image:
	if small.get_size() == big.get_size():
		for y in big.get_height():
			for x in big.get_width():
				var px := big.get_pixel(x, y)
				px.a = small.get_pixel(x, y).a
				big.set_pixel(x, y, px)
		return big
	var alpha := Image.create_empty(small.get_width(), small.get_height(), false, Image.FORMAT_L8)
	for y in small.get_height():
		for x in small.get_width():
			alpha.set_pixel(x, y, Color(small.get_pixel(x, y).a, 0, 0))
	alpha.resize(big.get_width(), big.get_height(), Image.INTERPOLATE_CUBIC)
	for y in big.get_height():
		for x in big.get_width():
			var px := big.get_pixel(x, y)
			px.a = 1.0 if alpha.get_pixel(x, y).r >= 0.5 else 0.0
			big.set_pixel(x, y, px)
	return big


## Texture for a manifest key ("card_frame_red", "duel_pattern_green"...)
## or null when the skin doesn't provide it.
##
## THE CARD BACK HAS TWO PLACES ABOVE THE SKIN: the player's own picture
## ([CardBack], Options → Card back) first, whatever the day — they chose
## it — then the season's ([method season_back]); the skin's back, or
## null for the plain one, after both.
static func texture(key: String) -> Texture2D:
	if key == "card_back":
		var own := CardBack.texture()
		if own != null:
			return own
		var seasonal := season_back()
		if seasonal != null:
			return seasonal
	return skin_texture(key)


## The skin's own picture for [param key], or null — [method texture]
## without the player's card back or the season's.
static func skin_texture(key: String) -> Texture2D:
	if _texture_cache.has(key):
		return _texture_cache[key]
	var result: Texture2D = null
	var found := _slot(key + ".png")
	if String(found["path"]) != "":
		result = picture(String(found["path"]), key, String(found["own"]))
	_texture_cache[key] = result
	return result


## Font for a manifest key ("font_title", "font_body"), or null when
## neither a skin nor this project has one — the caller then gets Godot's
## own default face.
##
## A KEY WE SHIP A FACE FOR IS OURS FOR EVERY PLAYER (the owner,
## 2026-10-15: *"Spectral, with the dialog spacing tightened for
## everyone!! It is an open source font. Thats is very important."*).
## Until then ours was only a FLOOR under an imported face, and the
## imported face depended on where the skin was built: MPlantin out of a
## Manalink tree, the 1997 CD's narrow MPZurich out of the disc alone.
## So `font_body` is Spectral ([method our_font]) whatever a skin holds,
## set on [constant BODY_TRIM_TOP]/[constant BODY_TRIM_BOTTOM] tighter
## lines ([method _tightened]); a skin's `font_body.ttf` is not read.
## `font_title`, which we ship no face for, is still the skin's
## (MagicMedieval), then nothing.
static func font(key: String) -> Font:
	if _font_cache.has(key):
		return _font_cache[key]
	var result: Font = null
	if OUR_FONTS.has(key):
		result = _tightened(our_font(key))
	else:
		var path := _find(key + ".ttf")
		if path != "":
			var f := FontFile.new()
			if f.load_dynamic_font(path) == OK:
				result = f
	_font_cache[key] = result
	return result


## SPECTRAL'S LINE BOX, TRIMMED. Godot measures its own at 1.52 em
## (ascent 1.059, descent 0.463 — most of the descent air below its
## deepest accents) where MPlantin, the face it replaced, set a 1.000 em
## box, so every dialog row and every wrapped line stood half as tall
## again (measured 2026-10-15 at 13 px: 21 px a line against MPlantin's
## 14). Three pixels off the top and three off the bottom bring 13 px to
## 15 and 18 px to 23 (measured 2026-10-17: 10 px 10, 12 px 13, 16 px 19).
## Pixels and not ems because that is what [FontVariation] offers, so the
## trim weighs most on small text: at 10 px, the card's smallest rules
## step, the box keeps 2 px of the 2.4 a descender reaches, and below
## about 9 px the box would collapse (nothing sets text that small).
## The card keeps its sizes and the 808 that read whole: its rules text
## is top-aligned, so the first line sits 3 px higher than under the
## untrimmed face, and [method CardPreview._rules_leading], which sets the
## baselines from whatever box the face reports, moves the line pitch by
## a pixel at some sizes (`tests/ui/test_card_preview.gd`).
const BODY_TRIM_TOP := 3
const BODY_TRIM_BOTTOM := 3

static func _tightened(face: Font) -> Font:
	if face == null:
		return null
	var tight := FontVariation.new()
	tight.base_font = face
	tight.spacing_top = -BODY_TRIM_TOP
	tight.spacing_bottom = -BODY_TRIM_BOTTOM
	return tight


## [param face] emboldened by [param amount] — a COPY of a variation
## rather than a variation over it, because a [FontVariation] whose base
## is another one keeps none of the inner one's spacing: a bold line in
## the trimmed body face would stand as tall as the untrimmed one.
static func emboldened(face: Font, amount: float) -> Font:
	var thick: FontVariation
	if face is FontVariation:
		thick = (face as FontVariation).duplicate()
	else:
		thick = FontVariation.new()
		thick.base_font = face
	thick.variation_embolden = amount
	return thick


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
## what this project ships. [method font]'s own cache is cleared too, and
## for a key in [constant OUR_FONTS] it answers this face again: since
## 2026-10-15 a skin's `font_body.ttf` is never read.
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
	for candidate in [_find(key + ".png", true), _find(key + ".jpg", true),
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


## Short label for a set that has NO symbol to show. Every card still
## shows its set: an icon when one exists, this text otherwise. Since
## 2026-09-18 that is the promos alone on a CARD — Unlimited wears this
## project's Roman II — while the title row ([SetBadges]) and the Deck
## Builder's filter strip still letter `2ⁿᵈ` and `4ᵗʰ` by their own rules.
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
## card's type strip without a box behind it. Null for the promos, which
## no drawing ever stood for; Unlimited and Fourth Edition, blank on the
## printed card, wear the Roman II and IV this project drew for them.
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

## [QoL] On-card rarity colours, requested 2026-09-20. The original gold
## texture stays untouched for rare/unknown cards and for set-only buttons.
## White is deliberately brighter than silver; every ramp retains a dark rim.
const SET_SYMBOL_RAMPS := {
	"common": [Color(0.78, 0.79, 0.82), Color.WHITE],
	"uncommon": [Color(0.30, 0.35, 0.43), Color(0.90, 0.94, 1.0)],
	"legendary": [Color(0.38, 0.12, 0.62), Color(0.90, 0.63, 1.0)],
}
const SET_SYMBOL_INK := {
	"common": Color.WHITE,
	"uncommon": Color(0.72, 0.77, 0.85),
	"rare": Color(0.94, 0.75, 0.30),
	"legendary": Color(0.77, 0.43, 0.98),
}


static func set_symbol_tier(rarity: String, legendary := false) -> String:
	return "legendary" if legendary or rarity == "mythic" else rarity


## Letter-only sets (PR) follow the same scheme, with the existing white
## fallback where rarity is unknown. Legendary overrides printed rarity.
static func set_symbol_ink(rarity: String, legendary := false) -> Color:
	return SET_SYMBOL_INK.get(set_symbol_tier(rarity, legendary), Color.WHITE)


static func set_icon(set_code: String, rarity := "", legendary := false) -> Texture2D:
	var tier := set_symbol_tier(rarity, legendary)
	if SET_SYMBOL_RAMPS.has(tier):
		var key := "%s:%s" % [set_code, tier]
		if _set_icon_cache.has(key):
			return _set_icon_cache[key]
		var source := set_icon(set_code)
		if source == null:
			return null
		# Remap the authored gold relief, not CanvasItem.modulate: multiplying
		# yellow by white cannot make it white. Preserve alpha and the bevel,
		# and never modify the shared texture used by the medallions.
		var img: Image = source.get_image().duplicate()
		img.convert(Image.FORMAT_RGBA8)
		var ramp: Array = SET_SYMBOL_RAMPS[tier]
		var dark: Color = ramp[0]
		var lit: Color = ramp[1]
		var rim := Color(0.10, 0.09, 0.12)
		for y in img.get_height():
			for x in img.get_width():
				var pixel := img.get_pixel(x, y)
				if pixel.a == 0.0:
					continue
				# Gold's red channel measures the authored relief light; the
				# rim starts at 0.16 and the brightest highlights reach 1.0.
				var light := clampf((pixel.r - 0.16) / 0.84, 0.0, 1.0)
				var ink: Color = rim.lerp(dark, light / 0.4) if light < 0.4 \
					else dark.lerp(lit, (light - 0.4) / 0.6)
				ink.a = pixel.a
				img.set_pixel(x, y, ink)
		var tinted := ImageTexture.create_from_image(img)
		_set_icon_cache[key] = tinted
		return tinted
	if _set_icon_cache.has(set_code):
		return _set_icon_cache[set_code]
	# THE SET SYMBOL IS ALWAYS OURS, whatever the player imported (the
	# owner, 2026-09-10: *"Lets always use our own designed glyphs and
	# thats it for all players. Simplest."*). It is the ONE key that does
	# not take a skin.
	#
	# THE REASON IS INDEPENDENCE, and the owner said so in as many words:
	# *"This is basically just to be independent of the manalink install
	# that had its own set…"*. Manalink 3 restyled these six medallions,
	# and until today the game preferred that restyle — so the symbol on a
	# card came from a REIMPLEMENTATION rather than from the 1997 game or
	# from us. Drawing our own ends that: the six glyphs are this
	# project's, they are the same for everybody, and no part of the chain
	# reaches for somebody else's drawing. (`tools/import_original.py`'s
	# rows lead with the disc's own file again for the same reason, though
	# the game reads neither.)
	#
	# WHAT THE MEASUREMENT ADDED, corroboration rather than argument: the enlarged
	# card's symbol slot is 14x17 PIXELS, and the three sources read very
	# differently at that size. Manalink's restyle is a gold glyph that
	# fills it; ours is a gold glyph with a drawn bevel, filling 77% of
	# its tile; 1997's own is a BLACK glyph inside a gold ring on a
	# blue-grey stone disc, and at 14px that is a dark smudge on a pale
	# coin — cropping the ring away (measured, 2026-09-10) barely helps,
	# because the trouble is the CONTRAST and not the size. So rather than
	# show one player a legible anvil and another a smudge, every player
	# gets the same six glyphs this project drew for the purpose.
	#
	# WHAT THIS COSTS, said plainly: a player who imported their own 1997
	# disc does NOT see their disc's set symbols here. It is the only
	# place in the game where that is true, and it is a deliberate
	# exception rather than a gap — `set_icon_*` is still imported (a skin
	# is a complete thing, and `docs/skin-catalogue.txt` still lists it),
	# it is simply not what the card wears.
	#
	# THE DAY A NEW SET ARRIVES — Ice Age, Homelands, anything past the
	# 897 — ITS GLYPH MUST BE DRAWN, in `tools/draw_our_art.gd`, beside
	# the six that are there. There is no import to fall back on any more:
	# an undrawn set letters itself through `SetBadges`, which is the
	# printed truth for the promos and a MISSING PIECE for anything else
	# (Unlimited had its II drawn on 2026-09-18, the owner's order, so the
	# Deck Builder's cards all wear gold).
	var result := our_art("set_icon_%s" % set_code)
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
		result = texture_of(cut(sheet, rect), rect.size)
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


## Where the slot [param filename] is worn from: `{path, own}` from the
## first place that has anything for it ([method _in_place]). An empty
## path: no place has it.
static func _slot(filename: String, every := false) -> Dictionary:
	for dir in search_dirs(every):
		var found := _in_place(dir, filename)
		if String(found["path"]) != "":
			return found
	return {"path": "", "own": ""}


static func _find(filename: String, every := false) -> String:
	return String(_slot(filename, every)["path"])
