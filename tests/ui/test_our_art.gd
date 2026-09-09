extends GutTest
## THE LOOK THIS PROJECT SHIPS AS ITS OWN — `game/art/`: the pictures
## `tools/draw_our_art.gd` draws, and since 2026-09-09 the BODY FACE in
## `game/art/fonts/`. Both are listed with their hashes in
## `game/art/README.md` and promised by name in `README.md` § Legal.
##
## The face is ours in a different way from the pictures and the tests
## have to say so: the pictures are ours because this project drew them,
## the face is ours to ship because Production Type gave Spectral away
## under the SIL Open Font Licence. What that licence asks in return is
## that it travel with the font, so `fonts/OFL.txt` is not a courtesy
## file — [method test_the_licence_ships_wherever_the_face_ships] is the
## one test here that guards a promise made to somebody outside this
## project.
##
## The promise those paragraphs make is unusually specific — *these* files
## and no others, every one of them ours to hand on — so it needs tests
## that can actually fail. Four things have to stay true:
##
##   1. THE LIST IS THE FOLDER. Every file the README names is there and
##      is not empty, and every picture and every font file in the folder
##      is named by the README. A file that arrived from somewhere else —
##      a paste, a copy out of somebody's install, a second weight nobody
##      asked for — fails here rather than reaching a release with
##      nothing said about it.
##   2. THE BYTES ARE THE ONES WE WROTE DOWN. Each file's SHA-256 is the
##      one in the README's table, so the table cannot rot and a file
##      cannot be swapped underneath it.
##   3. THE EXPORT CANNOT SILENTLY DROP THEM. `game/art/` is inside the
##      pack only because no rule in `export_presets.cfg.example` excludes
##      it; that is a filter in a config file, not a law, so it is
##      asserted rather than assumed. The alternative — art under
##      `assets/`, which every preset excludes on purpose — would leave a
##      built game with no set symbols and no dagger and no error
##      anywhere.
##   4. THE FACE IS REACHABLE AND ITS LICENCE IS WITH IT. `game/art/fonts/`
##      is read through `GameSkin.our_font`, and `OFL.txt` reaches the pack
##      by a DIFFERENT road from everything else here: it is not a
##      resource, so `export_filter="all_resources"` does not carry it and
##      only an `include_filter` pattern does.
##
## AND THE INVENTORY IS NOT THE FOLDER. One shipped asset lives outside
## `game/art/` — `game/deck_builder/stone_grind.wav`, the Deck Builder's
## filter cue, which sits beside the screen that plays it — and its row is
## in `game/art/README.md` all the same, because a promise kept in two
## documents is a promise that drifts. A row whose name begins `game/` is
## read as a path from the project root ([method _path_of]); that is the
## only concession made to it.

const ART_DIR := "res://game/art"
const README := "res://game/art/README.md"
const PRESETS := "res://export_presets.cfg.example"


## Every extension the README's tables may name. A row is a promise about
## a file, and the three kinds of promise are a picture, a face and the
## licence that face travels under.
const SHIPPED_EXTENSIONS := [".png", ".ttf", ".txt", ".wav"]

## A row may name a file that ships from somewhere ELSE in the tree — the
## Deck Builder's grind, which sits beside the screen that plays it and is
## named by path in `DeckAudio.GRIND`. Such a row is written as a path
## from the project root and begins with this; every other row is a file
## in [constant ART_DIR].
const FROM_PROJECT_ROOT := "game/"


## Where a row's file actually is.
func _path_of(name: String) -> String:
	if name.begins_with(FROM_PROJECT_ROOT):
		return "res://%s" % name
	return "%s/%s" % [ART_DIR, name]


## The same, as the export presets' filters see it — no `res://`.
func _packed_path(name: String) -> String:
	return _path_of(name).trim_prefix("res://")

## BOTH of the README's tables as `{filename: sha256}` — the one list this
## file reads, so a row added to either is tested without touching this
## file. A name may carry a folder (`fonts/OFL.txt`); it is always
## relative to [constant ART_DIR].
func _named_files() -> Dictionary:
	var out: Dictionary = {}
	var text := FileAccess.get_file_as_string(README)
	for line in text.split("\n"):
		if not line.begins_with("| `"):
			continue
		var cells := line.split("|")
		if cells.size() < 6:
			continue
		var name := _bare(cells[1])
		var hash_cell := _bare(cells[5])
		for ext in SHIPPED_EXTENSIONS:
			if name.ends_with(ext):
				out[name] = hash_cell
				break
	return out


## Only the rows that name a picture — the tests that load a texture and
## sweep the folder want those and not the face.
func _named_pictures() -> Dictionary:
	var out: Dictionary = {}
	var named := _named_files()
	for name in named:
		if String(name).ends_with(".png"):
			out[name] = named[name]
	return out


## One table cell, without its spaces and its backticks.
func _bare(cell: String) -> String:
	return cell.strip_edges().trim_prefix("`").trim_suffix("`")


## The patterns of one `exclude_filter="a, b, c"` line.
func _patterns(line: String) -> Array:
	var quoted := line.split("=", true, 1)
	if quoted.size() < 2:
		return []
	var body := String(quoted[1]).strip_edges().trim_prefix("\"") \
		.trim_suffix("\"")
	var out: Array = []
	for piece in body.split(","):
		var pattern := String(piece).strip_edges()
		if pattern != "":
			out.append(pattern)
	return out


func _pictures_on_disk() -> Array:
	var out: Array = []
	var dir := DirAccess.open(ART_DIR)
	if dir == null:
		return out
	for name in dir.get_files():
		if String(name).ends_with(".png"):
			out.append(String(name))
	out.sort()
	return out


# ------------------------------------------------- 1. the list is the folder --

func test_the_readme_names_at_least_the_seven_we_promised() -> void:
	# Named one by one rather than counted, because `README.md` promises
	# them one by one.
	var named := _named_files()
	for name in ["set_icon_arn.png", "set_icon_atq.png", "set_icon_leg.png",
			"set_icon_drk.png", "set_icon_4ed.png", "set_icon_past.png",
			"damage_marker.png"]:
		assert_true(named.has(name), "game/art/README.md names %s" % name)


func test_every_file_the_readme_names_is_there_and_is_not_empty() -> void:
	var named := _named_files()
	assert_gt(named.size(), 0, "the README's table parsed")
	for name in named:
		var path := _path_of(String(name))
		assert_true(FileAccess.file_exists(path), path)
		if FileAccess.file_exists(path):
			assert_gt(FileAccess.get_file_as_bytes(path).size(), 0,
				"%s is not empty" % name)


func test_no_picture_lives_here_that_the_readme_does_not_name() -> void:
	var on_disk := _pictures_on_disk()
	if on_disk.is_empty():
		pass_test("the folder is not readable from here")
		return
	var named := _named_pictures()
	for name in on_disk:
		assert_true(named.has(name),
			"%s is in game/art/ but nothing in the README says what it is "
			% name + "or where it came from")


func test_every_picture_here_loads_as_a_texture_through_the_loader() -> void:
	# The way the game actually reaches them — `GameSkin.our_art`, a
	# `load`, not a filesystem read (see its own doc for why).
	for name in _named_pictures():
		var key := String(name).trim_suffix(".png")
		assert_not_null(GameSkin.our_art(key), key)


# ------------------------------------------------- 2. the bytes are ours --

func test_every_picture_carries_the_hash_the_readme_wrote_down() -> void:
	var named := _named_files()
	for name in named:
		var path := _path_of(String(name))
		if not FileAccess.file_exists(path):
			continue
		assert_eq(FileAccess.get_sha256(path), String(named[name]),
			"%s: regenerate with tools/draw_our_art.gd and update the "
			% name + "SHA-256 in game/art/README.md")


# --------------------------------------------- 3. the export keeps them --

func test_no_export_preset_excludes_the_art_we_ship() -> void:
	var text := FileAccess.get_file_as_string(PRESETS)
	assert_gt(text.length(), 0, "the committed example preset is readable")
	var filters := 0
	for line in text.split("\n"):
		var trimmed := String(line).strip_edges()
		if not trimmed.begins_with("exclude_filter="):
			continue
		filters += 1
		for pattern in _patterns(trimmed):
			for name in _named_files():
				var path := _packed_path(String(name))
				assert_false(path.match(pattern),
					"the preset's `%s` would drop %s out of the pack"
					% [pattern, path])
	assert_gt(filters, 0, "every preset has an exclude_filter to check")


func test_every_preset_packs_all_resources() -> void:
	# The other half of the same guarantee: nothing under `game/art/` is
	# REFERENCED by a scene or a script constant — `GameSkin.our_art`
	# builds its path from a key at run time — so a preset that packed
	# only what it could see referenced would leave them out.
	var text := FileAccess.get_file_as_string(PRESETS)
	var found := 0
	for line in text.split("\n"):
		if String(line).strip_edges().begins_with("export_filter="):
			found += 1
			assert_eq(String(line).strip_edges(),
				"export_filter=\"all_resources\"",
				"a preset stopped packing every resource")
	assert_gt(found, 0, "the presets declare an export_filter")


func test_nothing_in_gitignore_would_keep_them_out_of_the_repository() -> void:
	# Shipping means BOTH: in the pack, and in the checkout the pack is
	# built from. `assets/` is ignored on purpose, so a picture that
	# landed there would pass every test above and still not exist for
	# anyone but its author.
	var text := FileAccess.get_file_as_string("res://.gitignore")
	if text.is_empty():
		pass_test(".gitignore not readable from here")
		return
	for line in text.split("\n"):
		var rule := String(line).strip_edges()
		if rule.is_empty() or rule.begins_with("#") or rule.begins_with("!"):
			continue
		for name in _named_files():
			var path := _packed_path(String(name))
			# A rule with no slash is matched against the file's NAME
			# anywhere in the tree, which is how git reads it — the
			# BARE name, since a row may now carry a folder.
			var subject: String = String(name).get_file() \
				if not rule.contains("/") else path
			assert_false(String(subject).match(rule.trim_suffix("/")),
				"`%s` in .gitignore would keep %s out" % [rule, path])


# ------------------------------------------------------------- 4. the face --
# `game/art/fonts/`, since 2026-09-09 — the floor under
# `GameSkin.font("font_body")`. Spectral Regular, chosen because its
# x-height is MPlantin's to three decimals; see `game/art/README.md`
# § The face and `docs/ROADMAP.md`.

const FONT_DIR := "res://game/art/fonts"
const OUR_FACE := "fonts/Spectral-Regular.ttf"
const OUR_LICENCE := "fonts/OFL.txt"


## What is actually in `fonts/`, README or no README.
func _fonts_on_disk() -> Array:
	var out: Array = []
	var dir := DirAccess.open(FONT_DIR)
	if dir == null:
		return out
	for name in dir.get_files():
		var file := String(name)
		if file.ends_with(".import"):
			continue      # Godot's own sidecar, gitignored, regenerated
		out.append(file)
	out.sort()
	return out


func test_the_readme_names_the_face_and_the_licence_beside_it() -> void:
	var named := _named_files()
	for name in [OUR_FACE, OUR_LICENCE]:
		assert_true(named.has(name), "game/art/README.md names %s" % name)


func test_nothing_lives_in_fonts_that_the_readme_does_not_name() -> void:
	# A font family arrives as fourteen files and the game wants one of
	# them. A second weight that nobody loads is pack weight with nothing
	# said about where it came from — the same failure the pictures'
	# sweep catches, one folder down.
	var on_disk := _fonts_on_disk()
	if on_disk.is_empty():
		pass_test("the folder is not readable from here")
		return
	var named := _named_files()
	for name in on_disk:
		assert_true(named.has("fonts/%s" % name),
			"%s is in game/art/fonts/ but nothing in the README says what "
			% name + "it is or where it came from")


func test_the_face_loads_through_the_accessor_that_reaches_it() -> void:
	# `GameSkin.our_font`, a `load` — the same reason `our_art` is a
	# `load`: inside an exported pack there is no filesystem path.
	var face := GameSkin.our_font("font_body")
	assert_not_null(face, "GameSkin.our_font(\"font_body\")")
	if face != null:
		assert_eq(face.get_font_name(), "Spectral",
			"the face this project ships is the one the README names")


func test_we_ship_a_body_face_and_deliberately_no_title_face() -> void:
	# The original's display face is a blackletter-ish MagicMedieval and
	# nothing free is near it, so a title without a skin keeps Godot's own
	# default rather than wearing a serif that is not pretending well.
	assert_true(GameSkin.OUR_FONTS.has("font_body"), "font_body has a floor")
	assert_false(GameSkin.OUR_FONTS.has("font_title"),
		"font_title deliberately has none — see GameSkin.OUR_FONTS")
	assert_null(GameSkin.our_font("font_title"))
	assert_null(GameSkin.our_font("no_such_font"))


func test_the_face_is_the_one_the_card_was_measured_against() -> void:
	# The whole reason it is Spectral: x-height 0.450 of the em, which is
	# MPlantin's to three decimals — read off the outline by the same
	# measurement `CardPreview` makes when it sizes the rules text.
	var face := GameSkin.our_font("font_body")
	if face == null:
		fail_test("no face to measure")
		return
	assert_almost_eq(CardPreview._x_height(face), 0.450, 0.0005,
		"x-height, the number the choice was made on")


func test_the_licence_ships_wherever_the_face_ships() -> void:
	# THE ONE PROMISE HERE THAT IS MADE TO SOMEBODY ELSE. The OFL grants
	# redistribution and asks that the licence go with the font; `OFL.txt`
	# is how this project keeps that. It is NOT a Godot resource, so
	# `export_filter="all_resources"` does not carry it — only a preset's
	# `include_filter` does, and that is a line in a config file exactly
	# as breakable as the exclude_filter above.
	var licence := "%s/OFL.txt" % FONT_DIR
	assert_true(FileAccess.file_exists(licence), licence)
	var text := FileAccess.get_file_as_string(licence)
	assert_true(text.contains("SIL OPEN FONT LICENSE Version 1.1"),
		"OFL.txt is the licence itself, not a note about it")
	var presets := FileAccess.get_file_as_string(PRESETS)
	var checked := 0
	for line in presets.split("\n"):
		var trimmed := String(line).strip_edges()
		if not trimmed.begins_with("include_filter="):
			continue
		checked += 1
		var carried := false
		for pattern in _patterns(trimmed):
			if "game/art/fonts/OFL.txt".match(pattern):
				carried = true
		assert_true(carried,
			"no include_filter pattern carries the OFL into this pack: a "
			+ "built game would have the font and not its licence")
	assert_gt(checked, 0, "every preset declares an include_filter")


# ------------------------------------------------ 5. the one sound we ship --
# `game/deck_builder/stone_grind.wav` — the only sound in the game that
# did not come out of the 1997 install, which is why it is in the pack at
# all (`DeckAudio`, `Provenance.md` § Our own assets). It is NOT ours the
# way the pictures are: it reached this project under the Pixabay Content
# License and the freesound.org entry behind it could not be identified.
# The inventory has to name it anyway, and for the same reason as
# everything else here — `README.md` § Legal promises what ships file by
# file, and a file nobody named is the failure that promise is against.

const OUR_SOUND := "game/deck_builder/stone_grind.wav"


func test_the_readme_names_the_one_sound_that_ships() -> void:
	assert_true(_named_files().has(OUR_SOUND),
		"game/art/README.md names %s" % OUR_SOUND)


func test_the_sound_is_there_carries_its_hash_and_loads() -> void:
	# Present, non-empty and byte-for-byte what the inventory says are
	# already covered for every row; what is only true of this one is the
	# way the game reaches it — `load`, through the import pipeline, the
	# same road `GameSkin.our_art` takes and for the same reason —
	# so it is asked for the way the screen asks (`DeckAudio.stream_for`).
	var path := _path_of(OUR_SOUND)
	assert_true(FileAccess.file_exists(path), path)
	assert_eq(FileAccess.get_file_as_bytes(path).size(), 11068,
		"the trimmed quarter-second, as Provenance.md measured it")
	assert_true(ResourceLoader.exists(DeckAudio.GRIND),
		"DeckAudio.GRIND still points at a file the pipeline imported")
	assert_not_null(DeckAudio.stream_for(DeckAudio.CUE_FILTER),
		"the filter cue reaches a real stream")


func test_the_sound_is_named_where_the_game_looks_for_it() -> void:
	# The inventory row and the constant the screen plays are two
	# statements of one path, and nothing but this holds them together.
	assert_eq(DeckAudio.GRIND, "res://%s" % OUR_SOUND,
		"the row in game/art/README.md and DeckAudio.GRIND are the same "
		+ "file, or one of them is documenting something that is not there")
