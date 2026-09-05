extends GutTest
## THE SET BADGES (`game/set_badges.gd`) — the title screen's top-left row
## of "which sets is this game made of".
##
## Like `test_skin.gd`, these pass in BOTH states of the world, and for the
## same reason: the lettered row is what SHIPS (no original art ever enters
## this repository) and the symbols are dressing a player imports. So the
## fallback is tested by switching the icons off rather than by hoping the
## machine has no skin, and the symbol strip is tested against a SYNTHETIC
## sheet built here — which is also the only way to prove the slot map
## without the 1997 file.


func _row(icons: bool) -> SetBadges:
	var row := SetBadges.new()
	row.icons = icons
	add_child_autofree(row)
	await get_tree().process_frame
	return row


func _lettered(badge: Node) -> SetBadges.Lettered:
	for child in badge.get_children():
		if child is SetBadges.Lettered:
			return child
	return null


func _has_symbol(badge: Node) -> bool:
	for child in badge.get_children():
		if child is SetBadges.Glyph:
			return true
	return false


## A stand-in for a set's symbol. [method SetBadges.symbol] memoises into
## a STATIC dictionary, so seeding it is how a test says "this machine has
## the comet" (or "has not") without depending on whether the player
## running the suite has imported the 1997 art. Put back in `after_each`:
## a fake glyph must not outlive the test that asked for one.
var _cache_was: Dictionary = {}


func before_each() -> void:
	_cache_was = SetBadges._symbol_cache.duplicate()


func after_each() -> void:
	SetBadges._symbol_cache = _cache_was


func _fake_symbol() -> Texture2D:
	var image := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(image)


# ------------------------------------------------------------ every set --

func test_every_set_in_the_pool_gets_a_badge() -> void:
	var row: SetBadges = await _row(true)
	assert_eq(row.get_child_count(), CardRegistry.SET_ORDER.size(),
		"one badge per set in the pool")
	var codes: Array = []
	for badge in row.get_children():
		codes.append(String(badge.get_meta("set_code")))
		assert_gt((badge as Control).get_child_count(), 0,
			"%s's badge is not empty" % badge.name)
	assert_eq(codes, Array(CardRegistry.SET_ORDER),
		"in CardRegistry.SET_ORDER — the sets in printing order")


func test_every_badge_names_its_set_the_way_the_cue_cards_do() -> void:
	var row: SetBadges = await _row(true)
	for badge in row.get_children():
		var code := String(badge.get_meta("set_code"))
		assert_eq((badge as Control).tooltip_text,
			String(DeckFilter.SET_LABELS[code]),
			"%s's tooltip is its 1997 name" % code)


# ------------------------------------------- the shipped (lettered) row --

func test_the_shipped_row_letters_all_eight_sets() -> void:
	# No skin: the whole row must still read, with no gaps and no
	# placeholders. This is the state every player is in before importing.
	var row: SetBadges = await _row(false)
	var written: Array = []
	for badge in row.get_children():
		var letters := _lettered(badge)
		assert_not_null(letters, "%s letters itself" % badge.name)
		if letters == null:
			continue
		assert_ne(letters.stem, "", "%s's letters are not blank" % badge.name)
		written.append(letters.stem + letters.suffix)
	assert_eq(written,
		["2nd", "ARN", "ATQ", "LEG", "DRK", "4th", "Astral", "PR"],
		"the row as a skinless player reads it")


func test_no_badge_shows_a_texture_when_the_icons_are_off() -> void:
	var row: SetBadges = await _row(false)
	for badge in row.get_children():
		for child in (badge as Control).get_children():
			assert_false(child is SetBadges.Glyph,
				"%s wears no symbol without the skin" % badge.name)


func test_astral_is_named_rather_than_coded() -> void:
	# Its Scryfall code is `past`, which the general short-form rule would
	# letter `PAST`. The owner's instruction is that Astral gets named.
	assert_eq(SetBadges.badge_text("past"), "Astral")
	assert_eq(SetBadges.badge_suffix("past"), "")


func test_astral_shows_its_comet_alone_and_its_word_only_without_one() -> void:
	# The owner, 2026-09-04: "remove the Astral word as we have a star
	# icon for Astral already". The NAME is the FALLBACK — it is there so
	# that a player with no imported art reads `Astral` rather than the
	# Scryfall code `PAST` — and it yields to the symbol the moment the
	# skin supplies one. Both halves are forced through the symbol cache,
	# so this reads the same on a machine with the 1997 art and one
	# without.
	SetBadges._symbol_cache["past"] = _fake_symbol()
	var skinned: SetBadges = await _row(true)
	var comet := skinned.get_node("badge_past")
	assert_true(_has_symbol(comet), "the star trailing sparks, slot 4")
	assert_null(_lettered(comet),
		"and NOT the word beside it — the symbol already says Astral")

	SetBadges._symbol_cache["past"] = null
	var bare: SetBadges = await _row(true)
	var word := bare.get_node("badge_past")
	assert_false(_has_symbol(word), "no art imported, no comet")
	var letters := _lettered(word)
	assert_not_null(letters, "so the badge letters itself")
	if letters != null:
		assert_eq(letters.stem, "Astral", "by NAME, never `PAST`")


func test_no_badge_says_the_same_thing_twice() -> void:
	# The general form of the rule above, over whatever this machine has:
	# a badge shows its symbol OR its letters, and always exactly one of
	# the two. Never both, and never neither — the row has no gaps.
	var row: SetBadges = await _row(true)
	for badge in row.get_children():
		var code := String(badge.get_meta("set_code"))
		if _has_symbol(badge):
			assert_null(_lettered(badge),
				"%s shows its symbol alone" % code)
		else:
			assert_not_null(_lettered(badge), "%s letters itself" % code)


func test_the_short_forms_come_from_the_skin_s_own_vocabulary() -> void:
	# Not a second naming scheme: everything but Astral is whatever
	# GameSkin.set_label already letters that set with elsewhere.
	for code in CardRegistry.SET_ORDER:
		if SetBadges.NAMED.has(code):
			continue
		assert_eq(SetBadges.badge_text(code), GameSkin.set_label(code), code)
		assert_eq(SetBadges.badge_suffix(code),
			GameSkin.set_label_suffix(code), code)


# ------------------------------------------------------- the superscript --

func test_the_two_editions_take_a_raised_ordinal() -> void:
	assert_eq(SetBadges.badge_suffix("2ed"), "nd")
	assert_eq(SetBadges.badge_suffix("4ed"), "th")
	for code in ["arn", "atq", "leg", "drk", "phpr", "past"]:
		assert_eq(SetBadges.badge_suffix(code), "",
			"%s is not an edition" % code)


func test_the_raised_suffix_sits_above_the_baseline_and_does_not_clip() -> void:
	var row: SetBadges = await _row(false)
	var fourth := row.get_node_or_null("badge_4ed")
	assert_not_null(fourth)
	if fourth == null:
		return
	var letters := _lettered(fourth)
	assert_not_null(letters)
	if letters == null:
		return
	assert_eq(letters.suffix, "th")
	assert_gt(letters._raise, 0.0, "`th` is RAISED off the baseline")
	assert_lt(letters._raise, letters._baseline,
		"but not above the numeral's own cap line")
	assert_lt(letters._sub_size, letters.font_size,
		"and it is set smaller than the numeral")
	# The control is measured from the two strings it draws, so the badge
	# can never be narrower or shorter than its own letters.
	var stem_and_suffix := letters._stem_width \
		+ letters._face.get_string_size(letters.suffix,
			HORIZONTAL_ALIGNMENT_LEFT, -1, letters._sub_size).x
	assert_gte(letters.custom_minimum_size.x, stem_and_suffix,
		"wide enough for numeral + ordinal")
	assert_gte(letters.custom_minimum_size.y,
		letters._baseline + letters._face.get_descent(letters.font_size),
		"tall enough for the whole face")


# ------------------------------------------------------- the click path --

func test_nothing_inside_a_badge_can_shadow_its_own_click() -> void:
	# THE 2026-09-04 DEFECT, pinned as the invariant that was broken.
	# A badge listens on `gui_input`, and the viewport delivers that to
	# the DEEPEST control under the pointer that does not ignore the
	# mouse. `Glyph` sets MOUSE_FILTER_IGNORE; `Lettered` did not, and a
	# bare `Control` DEFAULTS to MOUSE_FILTER_STOP (measured: Control 0,
	# Container 1, Label 2) — so the letters sat on top of their own badge
	# and ate the press. `2ⁿᵈ`, `4ᵗʰ` and `PR` were dead on a skinned
	# machine and every badge was dead on an unskinned one, while the five
	# symbols answered fine.
	#
	# Pinned structurally rather than by pushing a real click because
	# headless Godot has NO GUI picking at all — under `--headless`
	# `Viewport.push_input` of a mouse event leaves
	# `gui_get_hovered_control()` null and reaches no Control (measured
	# 2026-09-04; the same probe under Xvfb routes normally). A routing
	# test could not run in this suite, which is exactly why the defect
	# reached a playtest.
	for icons in [true, false]:
		var row: SetBadges = await _row(icons)
		for badge in row.get_children():
			assert_eq((badge as Control).mouse_filter,
				Control.MOUSE_FILTER_STOP,
				"%s takes the click itself" % badge.name)
			for child in (badge as Control).get_children():
				assert_eq((child as Control).mouse_filter,
					Control.MOUSE_FILTER_IGNORE,
					"%s/%s lets the click through to the badge"
						% [badge.name, child.get_class()])


func test_the_row_does_not_take_clicks_that_are_not_its_own() -> void:
	# The badges are eight small targets on the shell's title screen, not
	# a sheet over it: everything between them, and the row itself, stays
	# transparent so the menu behind keeps its own clicks.
	var row: SetBadges = await _row(true)
	assert_ne(row.mouse_filter, Control.MOUSE_FILTER_STOP,
		"the row passes what misses a badge")


# ------------------------------------------------------ the symbol strip --

## A stand-in for `Cardsets.pic`: the real strip's geometry (five 66-wide
## slots, each a 33x15 image half and a 33x15 mask half) with a different
## flat colour in every image half, so a mis-read slot cannot pass.
func _fake_strip() -> Image:
	var sheet := Image.create(SetBadges.SHEET_SIZE.x, SetBadges.SHEET_SIZE.y,
		false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 1))          # the strip's own black backdrop
	for slot in 5:
		var tint := Color8(10 + slot * 40, 20, 30)
		for x in SetBadges.CELL.x:
			for y in SetBadges.CELL.y:
				sheet.set_pixel(slot * SetBadges.SLOT_PITCH + x, y, tint)
	return sheet


func test_the_strip_slot_map_cuts_the_right_symbol_for_each_set() -> void:
	var sheet := _fake_strip()
	for code in SetBadges.SYMBOL_SLOT:
		var slot: int = SetBadges.SYMBOL_SLOT[code]
		var art := SetBadges.symbol_from_sheet(sheet, String(code))
		assert_not_null(art, "%s has a symbol" % code)
		if art == null:
			continue
		assert_eq(Vector2i(art.get_width(), art.get_height()),
			SetBadges.CELL, "%s is cut at the cell's size" % code)
		var px := art.get_image().get_pixel(0, 0)
		assert_eq(px.r8, 10 + slot * 40,
			"%s comes from slot %d and no other" % [code, slot])


func test_the_slot_map_is_the_strip_as_measured() -> void:
	# Left to right on `Cardsets.pic`: crescent, pillar, scimitar, anvil,
	# comet — matched against the original's own NAMED DBArt glyphs.
	assert_eq(SetBadges.SYMBOL_SLOT,
		{"drk": 0, "leg": 1, "arn": 2, "atq": 3, "past": 4})
	assert_eq(SetBadges.SHEET_SIZE, Vector2i(330, 15))
	assert_eq(SetBadges.SLOT_PITCH * 5, SetBadges.SHEET_SIZE.x,
		"five slots exactly — there is no sixth")
	assert_eq(SetBadges.CELL.x * 2, SetBadges.SLOT_PITCH,
		"each slot is an image half and a mask half")


func test_the_strip_s_black_backdrop_is_keyed_out() -> void:
	var sheet := _fake_strip()
	# Blank slot 0's image half apart from one pixel: the crop must find
	# that pixel and nothing else.
	for x in SetBadges.CELL.x:
		for y in SetBadges.CELL.y:
			sheet.set_pixel(x, y, Color(0, 0, 0, 1))
	sheet.set_pixel(30, 12, Color8(200, 180, 90))
	var art := SetBadges.symbol_from_sheet(sheet, "drk")
	assert_not_null(art)
	if art != null:
		assert_eq(Vector2i(art.get_width(), art.get_height()),
			Vector2i(1, 1), "cropped to its ink, the padding keyed away")


func test_a_sheet_that_is_not_the_strip_is_refused() -> void:
	var wrong := Image.create(100, 10, false, Image.FORMAT_RGBA8)
	wrong.fill(Color.RED)
	assert_null(SetBadges.symbol_from_sheet(wrong, "drk"),
		"no guessing at a sheet of the wrong size")
	assert_null(SetBadges.symbol_from_sheet(null, "drk"))


func test_the_sets_the_original_drew_no_symbol_for_never_take_the_icon_path() -> void:
	# Unlimited, Fourth Edition and the promos. 4ed is the interesting one:
	# `Program/DBArt/Fourth.pic` (a Roman IV) exists and is imported as
	# `set_icon_4ed`, but it is a DECK BUILDER FILTER medallion — the
	# `Cardsets` strip the game stamps on cards has no slot for it, exactly
	# as a printed Fourth Edition card has no expansion symbol.
	for code in ["2ed", "4ed", "phpr"]:
		assert_false(SetBadges.SYMBOL_SLOT.has(code),
			"%s has no slot on the 1997 strip" % code)
		assert_null(SetBadges.symbol(code),
			"%s letters itself instead" % code)
		assert_null(SetBadges.symbol_from_sheet(_fake_strip(), code))


# --------------------------------------------------------- on the screen --

func test_the_main_menu_carries_the_row_in_its_top_left() -> void:
	var menu: Control = load("res://game/main.tscn").instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var row: SetBadges = null
	for node in _walk(menu):
		if node is SetBadges:
			row = node
	assert_not_null(row, "the title screen shows the set badges")
	if row == null:
		return
	assert_eq(row.get_child_count(), CardRegistry.SET_ORDER.size())
	var plaque := row.get_parent() as Control
	assert_true(plaque is PanelContainer,
		"on the shell's own stone plaque, so it reads on the title art")
	assert_lt(plaque.position.x, 200.0, "top-LEFT")
	assert_lt(plaque.position.y, 200.0, "TOP-left")
	assert_gt(plaque.size.x, 0.0, "and it has laid itself out")
	assert_gt(plaque.size.y, 0.0)


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
