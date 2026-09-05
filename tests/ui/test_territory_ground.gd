extends GutTest
## THE TERRITORY BACKGROUND — `docs/duel-todo.md` §6.4, the art half.
##
## `@DIALOG_DUELOPTIONS` (`UIStrings.txt:598`) offers nine choices, which
## `Duel.hlp`, topic **Dueling Options**, explains are two lists: *"The
## list on the left simply allows you to pick the predominant color of
## your background. The list on the right includes the different types of
## background art available for each color. Select one option from each."*
##
## What is pinned here is that all fifteen combinations RESOLVE — with the
## 1997 skin and without it — that the three styles are drawn as the three
## different things they are, and that the setting is one value however
## many controls set it.

const COLORS := ["white", "blue", "black", "red", "green"]

var _saved: Dictionary = {}


func after_each() -> void:
	# The player's own value goes back — and a key they never had is
	# cleared, not written (test_duel_options.gd, the same rule).
	for key in _saved:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	_saved = {}


## Call BEFORE writing [param key]: snapshots the player's own value.
func _touch(key: String) -> void:
	if _saved.has(key):
		return
	_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null


# ------------------------------------------- the ground always exists --

func test_every_one_of_the_fifteen_grounds_is_painted_without_the_skin() -> void:
	# Provenance.md: the game must be complete and playable with NO
	# imported asset. A chooser whose choices had nothing to show would
	# not be a chooser, so all fifteen are drawn here.
	for color in COLORS:
		for row in DuelOptions.TERRITORY_TYPES:
			var tex := TerritoryGround.derived(color, String(row["label"]))
			assert_not_null(tex, "%s %s" % [color, row["label"]])
			assert_gt(tex.get_width(), 0, "%s %s" % [color, row["label"]])
			assert_gt(tex.get_height(), 0, "%s %s" % [color, row["label"]])


func test_the_fifteen_painted_grounds_are_all_different() -> void:
	# Five colours times three styles, and no two alike — otherwise the
	# player without the 1997 art is choosing between identical things.
	var seen: Dictionary = {}
	for color in COLORS:
		for row in DuelOptions.TERRITORY_TYPES:
			var img := TerritoryGround.derived(
				color, String(row["label"])).get_image()
			var digest := img.get_data().hex_encode().sha256_text()
			assert_false(seen.has(digest),
				"%s %s is a repeat of %s" % [color, row["label"],
					seen.get(digest, "")])
			seen[digest] = "%s %s" % [color, row["label"]]
	assert_eq(seen.size(), 15)


func test_a_wallpaper_is_a_tile_and_a_line_drawing_is_a_picture() -> void:
	# The distinction game/duel/opening_window.gd draws for
	# Winbk_Startduel: a picture's middle stretches rather than repeats.
	# The painted set keeps it — the two wallpapers are small squares to
	# be repeated, the line drawing is one wide picture.
	for label in ["Pattern", "Mana symbols"]:
		var tile := TerritoryGround.derived("red", label)
		assert_eq(tile.get_width(), tile.get_height(), "%s is square" % label)
		assert_eq(tile.get_width(), TerritoryGround.TILE)
	var picture := TerritoryGround.derived("red", "Line drawing")
	assert_gt(picture.get_width(), picture.get_height(),
		"a line drawing is a picture, not a tile")


func test_a_ground_node_is_always_produced() -> void:
	for color in COLORS:
		for row in DuelOptions.TERRITORY_TYPES:
			var node := TerritoryGround.node(color, String(row["label"]))
			assert_not_null(node, "%s %s" % [color, row["label"]])
			add_child_autofree(node)
			assert_true(node.visible)
			# It fills whatever it is put in, or it is not a ground.
			assert_eq(node.anchor_right, 1.0)
			assert_eq(node.anchor_bottom, 1.0)


func test_a_wallpaper_repeats_and_a_picture_keeps_its_shape() -> void:
	var pattern := TerritoryGround.node("green", "Pattern")
	add_child_autofree(pattern)
	# `Pattern` is the framed one: with the 1997 art it is a nine-patch
	# whose border stays put and whose field tiles; painted here it is a
	# plain repeating tile. Either way it REPEATS.
	if pattern is NinePatchRect:
		assert_eq(pattern.axis_stretch_horizontal,
			NinePatchRect.AXIS_STRETCH_MODE_TILE)
		assert_eq(pattern.axis_stretch_vertical,
			NinePatchRect.AXIS_STRETCH_MODE_TILE)
		assert_gt(pattern.patch_margin_left, 0,
			"the file's own decorative border is kept at native size")
	else:
		assert_eq((pattern as TextureRect).stretch_mode,
			TextureRect.STRETCH_TILE)
	var mana := TerritoryGround.node("green", "Mana symbols")
	add_child_autofree(mana)
	assert_eq((mana as TextureRect).stretch_mode, TextureRect.STRETCH_TILE,
		"the mana wallpaper has no border of its own — it just tiles")
	var picture := TerritoryGround.node("green", "Line drawing")
	add_child_autofree(picture)
	assert_eq((picture as TextureRect).stretch_mode,
		TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"a picture is never squashed to fit a differently shaped half")


# ------------------------------------------- the imported 1997 art --

func test_all_fifteen_original_files_are_imported() -> void:
	if not GameSkin.is_present():
		pass_test("no original skin on this machine — the painted "
			+ "grounds above are what was tested")
		return
	for color in COLORS:
		for row in DuelOptions.TERRITORY_TYPES:
			var label := String(row["label"])
			var tex := TerritoryGround.art(color, label)
			assert_not_null(tex, "Terr_%s%s.pic -> %s" % [color,
				row["suffix"], DuelOptions.ground_key(color, label)])
			if tex != null:
				# Every one of the fifteen is 381 tall (measured on the
				# s30 conversions, 2026-09-02); widths are 721 or 888.
				assert_eq(tex.get_height(), 381, "%s %s" % [color, label])
				assert_true(tex.get_width() == 721 or tex.get_width() == 888,
					"%s %s is %d wide" % [color, label, tex.get_width()])


# ------------------------------------------------- one setting, two views --

func test_the_setting_round_trips_through_settings() -> void:
	_touch("PlayerTerritoryColor")
	_touch("PlayerTerritoryType")
	DuelOptions.set_territory_color("Black")
	DuelOptions.set_territory_type("Mana symbols")
	assert_eq(DuelOptions.territory_color(), "Black")
	assert_eq(DuelOptions.territory_type(), "Mana symbols")
	# ...and it went to the FILE, under the original's own registry names,
	# not to a member of whichever screen set it.
	assert_eq(String(Settings.get_value("PlayerTerritoryColor", "")), "Black")
	assert_eq(String(Settings.get_value("PlayerTerritoryType", "")),
		"Mana symbols")


func test_the_two_controls_are_two_views_of_one_value() -> void:
	# The 1997 home is the Duel Options panel; the battle-setup screen
	# carries the same pair as a [QoL] addition. They must never be two
	# settings that can disagree.
	_touch("PlayerTerritoryColor")
	_touch("PlayerTerritoryType")
	DuelOptions.set_territory_color("Red")
	DuelOptions.set_territory_type("Line drawing")
	var setup: Control = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(setup)
	await get_tree().process_frame
	assert_eq(setup._territory_color.get_item_text(
		setup._territory_color.selected), "Red",
		"the setup screen opens on what the panel last set")
	assert_eq(setup._territory_type.get_item_text(
		setup._territory_type.selected), "Line drawing")
	# Now drive it from the SETUP screen and read it back from the panel's
	# own accessors — the value, not the widget, is the shared thing.
	setup._territory_color.select(
		DuelOptions.TERRITORY_COLORS.find("Green"))
	setup._territory_color.item_selected.emit(
		DuelOptions.TERRITORY_COLORS.find("Green"))
	setup._territory_type.select(2)
	setup._territory_type.item_selected.emit(2)
	assert_eq(DuelOptions.territory_color(), "Green")
	assert_eq(DuelOptions.territory_type(), "Mana symbols")
	# The preview replaced its ground twice; let the queue_free land so
	# the suite's orphan count stays honest.
	await get_tree().process_frame


func test_the_setup_screen_previews_the_chosen_ground() -> void:
	_touch("PlayerTerritoryColor")
	_touch("PlayerTerritoryType")
	DuelOptions.set_territory_color("Blue")
	DuelOptions.set_territory_type("Pattern")
	var setup: Control = load("res://game/setup_screen.tscn").instantiate()
	add_child_autofree(setup)
	await get_tree().process_frame
	assert_eq(setup._territory_preview.get_child_count(), 1,
		"the preview shows exactly one ground")
	# ...and it repaints when the style changes.
	var before: Node = setup._territory_preview.get_child(0)
	setup._territory_type.item_selected.emit(0)   # Line drawing
	await get_tree().process_frame
	assert_ne(setup._territory_preview.get_child(0), before,
		"a different style is a different node")


# -------------------------------------------------- whose half is whose --

func test_only_your_own_half_answers_to_the_setting() -> void:
	# `Duel.hlp`, **Dueling Options**: "You cannot do anything to change
	# the background in your opponent's territory; it matches the
	# predominant color in her deck." The original stores ONE pair of
	# values and both are named `Player...`.
	_touch("PlayerTerritoryColor")
	DuelOptions.set_territory_color("White")
	assert_eq(DuelOptions.ground_color_for(0, 0, "green"), "white")
	assert_eq(DuelOptions.ground_color_for(1, 0, "green"), "green")
	# ...and from the other seat's point of view it is the mirror image.
	assert_eq(DuelOptions.ground_color_for(1, 1, "black"), "white")
	assert_eq(DuelOptions.ground_color_for(0, 1, "black"), "black")


func test_the_duel_dresses_both_halves_and_redresses_on_a_change() -> void:
	_touch("PlayerTerritoryType")
	DuelOptions.set_territory_type("Pattern")
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var grounds: Array = []
	for pid in 2:
		var holder: Control = screen._half_rows[pid].get_parent()
		var found: Control = null
		for child in holder.get_children():
			if child != screen._half_rows[pid]:
				found = child
		assert_not_null(found, "seat %d has a ground" % pid)
		grounds.append(found)
	DuelOptions.set_territory_type("Line drawing")
	screen._redress_territory(0)
	var holder0: Control = screen._half_rows[0].get_parent()
	var after: Control = null
	for child in holder0.get_children():
		if child != screen._half_rows[0]:
			after = child
	assert_not_null(after)
	assert_ne(after, grounds[0], "the player's half took the new style")
	assert_eq(holder0.get_child(0), after,
		"and the ground is still UNDER the cards, not over them")
	await get_tree().process_frame   # the replaced ground's queue_free
