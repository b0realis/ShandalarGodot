extends GutTest
## THE ART THIS PROJECT SHIPS AS ITS OWN — `game/art/`, drawn by
## `tools/draw_our_art.gd`, listed with its hashes in `game/art/README.md`
## and promised by name in `README.md` § Legal.
##
## The promise that paragraph makes is unusually specific — *these* files
## and no others, every one of them ours — so it needs a test that can
## actually fail. Three things have to stay true, and each is one test
## below:
##
##   1. THE LIST IS THE FOLDER. Every file the README names is there and
##      is not empty, and every picture in the folder is named by the
##      README. A picture that arrived from somewhere else — a paste, a
##      copy out of somebody's install — fails here rather than reaching
##      a release with nothing said about it.
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

const ART_DIR := "res://game/art"
const README := "res://game/art/README.md"
const PRESETS := "res://export_presets.cfg.example"


## The README's table as `{filename: sha256}` — the one list this file
## reads, so a row added there is tested without touching this file.
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
		if name.ends_with(".png"):
			out[name] = hash_cell
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
		var path := "%s/%s" % [ART_DIR, name]
		assert_true(FileAccess.file_exists(path), path)
		if FileAccess.file_exists(path):
			assert_gt(FileAccess.get_file_as_bytes(path).size(), 0,
				"%s is not empty" % name)


func test_no_picture_lives_here_that_the_readme_does_not_name() -> void:
	var on_disk := _pictures_on_disk()
	if on_disk.is_empty():
		pass_test("the folder is not readable from here")
		return
	var named := _named_files()
	for name in on_disk:
		assert_true(named.has(name),
			"%s is in game/art/ but nothing in the README says what it is "
			% name + "or where it came from")


func test_every_picture_here_loads_as_a_texture_through_the_loader() -> void:
	# The way the game actually reaches them — `GameSkin.our_art`, a
	# `load`, not a filesystem read (see its own doc for why).
	for name in _named_files():
		var key := String(name).trim_suffix(".png")
		assert_not_null(GameSkin.our_art(key), key)


# ------------------------------------------------- 2. the bytes are ours --

func test_every_picture_carries_the_hash_the_readme_wrote_down() -> void:
	var named := _named_files()
	for name in named:
		var path := "%s/%s" % [ART_DIR, name]
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
				var path := "game/art/%s" % name
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
			var path := "game/art/%s" % name
			# A rule with no slash is matched against the file's NAME
			# anywhere in the tree, which is how git reads it.
			var subject: String = String(name) if not rule.contains("/") \
				else path
			assert_false(String(subject).match(rule.trim_suffix("/")),
				"`%s` in .gitignore would keep %s out" % [rule, path])
