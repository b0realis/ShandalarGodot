extends GutTest
## THE DUELIST'S FACE — the life register's other side (`docs/duel-todo.md`
## §6.5, [DuelistFace]).
##
## `Duel.hlp`'s **Duelist's Face** topic names three ways the panel turns
## over and each one is pinned here:
##
##   1. **By hand**, from the register's own mini-menu — and the menu is
##      `@MENU_LIFE` / `@MENU_FACE` verbatim, two tables that differ in
##      exactly one entry.
##   2. **Automatically**, while a spell that could take a player as a
##      target is being aimed.
##   3. **Automatically back**, *"when faces are no longer needed"* — which
##      is asserted by ending the cast and finding the number returned,
##      because the automatic flip is derived and never stored.
##
## Plus the two grounds themselves: the register wears the colour's
## wallpaper with the life total on it and the colour's duelist without,
## and they are DIFFERENT pictures — the defect this whole item started
## from was a panel whose two faces were the same file.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	var config := DuelConfig.hotseat_default()
	config.rng_seed = 606
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame


# ================================================= the 1997 mini-menus ==

func test_menu_life_is_the_1997_table() -> void:
	# `@MENU_LIFE`, Program/Text.res:1873 — four entries, this order.
	assert_eq(DuelistFace.MENU_LIFE, ["Target %s", "Target yourself",
		"Flip over to face", "Help..."] as Array[String])


func test_menu_face_is_the_1997_table() -> void:
	# `@MENU_FACE`, Program/Text.res:1844.
	assert_eq(DuelistFace.MENU_FACE, ["Target %s", "Target yourself",
		"Flip back to lifepoints", "Help..."] as Array[String])


func test_the_two_tables_differ_only_in_the_flip_verb() -> void:
	# This is the string tables' own statement that these are two faces of
	# ONE panel, and it is the reason the menu is rebuilt per open.
	for i in DuelistFace.MENU_LIFE.size():
		if i == DuelistFace.FLIP:
			assert_ne(DuelistFace.MENU_LIFE[i], DuelistFace.MENU_FACE[i])
		else:
			assert_eq(DuelistFace.MENU_LIFE[i], DuelistFace.MENU_FACE[i])


func test_the_opponents_name_lands_in_the_first_entry() -> void:
	var labels := DuelistFace.menu_labels(false, "Cromer")
	assert_eq(labels[0], "Target Cromer")
	assert_eq(labels[1], "Target yourself", "no stray substitution")
	assert_eq(labels[DuelistFace.FLIP], "Flip over to face")
	assert_eq(DuelistFace.menu_labels(true, "Cromer")[DuelistFace.FLIP],
		"Flip back to lifepoints")


# ========================================================== the art ==

func test_both_grounds_exist_for_every_colour_and_are_different() -> void:
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported — the flat panel is the fallback")
		return
	for color in ["white", "blue", "black", "red", "green"]:
		var register := DuelistFace.register(color)
		var face := DuelistFace.portrait(color)
		assert_not_null(register, "%s register ground" % color)
		assert_not_null(face, "%s duelist" % color)
		if register == null or face == null:
			continue
		# The register is 120x88 in 1997 and both sides are that size.
		assert_eq(register.get_size(), Vector2(120, 88), color)
		assert_eq(face.get_size(), Vector2(120, 88), color)
		# THE POINT OF THE ITEM: two faces, two pictures. `Face_*.pic` in
		# a Manalink install is five identical grey gradients and would
		# have failed this.
		assert_ne(register.get_image().get_data(), face.get_image().get_data(),
			"%s: the register's wallpaper is not the duelist" % color)


# ================================================ the picture's shape ==
# THE PICTURE KEEPS ITS SHAPE (2026-10-18): a 120x88 picture on a panel of
# another shape meets the panel halfway — the part shown has proportions
# between the picture's and the panel's, so it is widened a little and
# trimmed a little, never stretched to the panel nor cropped to it. The
# owner's photo of the green register stretched behind a 15; then, of the
# even cover, *"the images are too cropped now!"*; then *"Yes!"* to this
# ([method DuelistFace.shown_region]).

const INSIDE := Vector2(118, 86)   # a 120x88 picture inside its frame line


## The proportions halfway between the picture's and [param panel]'s.
static func _halfway(panel: Vector2) -> float:
	return sqrt(panel.x / panel.y * INSIDE.x / INSIDE.y)


func test_a_wide_panel_shows_a_centred_band_the_whole_width() -> void:
	var panel := Vector2(184, 76)
	var shown := DuelistFace.shown_region(Vector2(120, 88), panel)
	assert_almost_eq(shown.size.x / shown.size.y, _halfway(panel), 0.0001,
		"halfway between the picture's shape and the panel's")
	assert_eq(shown.size.x, 118.0, "the whole width inside the frame line")
	assert_eq(shown.position.x, 1.0)
	assert_almost_eq(shown.get_center().y, 44.0, 0.0001, "centred")
	# On the duel's own panel: three quarters of the height, widened by a
	# third, where the even cover showed 56% and the stretch widened 77%.
	assert_almost_eq(shown.size.y / INSIDE.y, 0.75, 0.01)
	var widened: float = (panel.x / panel.y) / (shown.size.x / shown.size.y)
	assert_almost_eq(widened, 1.33, 0.01)


func test_a_tall_panel_shows_the_whole_height() -> void:
	var panel := Vector2(60, 100)
	var shown := DuelistFace.shown_region(Vector2(120, 88), panel)
	assert_almost_eq(shown.size.x / shown.size.y, _halfway(panel), 0.0001)
	assert_eq(shown.size.y, 86.0)
	assert_eq(shown.position.y, 1.0)
	assert_almost_eq(shown.get_center().x, 60.0, 0.0001, "centred")


func test_the_frame_line_never_shows_and_a_panel_without_a_size_gets_the_inside() -> void:
	var inside := Rect2(Vector2.ONE, INSIDE)
	assert_eq(DuelistFace.shown_region(Vector2(120, 88), INSIDE), inside,
		"a panel of the picture's own shape: all of it inside the line")
	assert_eq(DuelistFace.shown_region(Vector2(120, 88), INSIDE * 2.5), inside,
		"at any size")
	assert_eq(DuelistFace.shown_region(Vector2(120, 88), Vector2.ZERO), inside,
		"no size yet")
	assert_eq(DuelistFace.shown_region(Vector2(2, 2), Vector2(10, 10)),
		Rect2(0, 0, 2, 2), "too small to have a line: as it is")


func test_both_sides_of_the_register_meet_its_shape_and_follow_its_size() -> void:
	if not GameSkin.is_present():
		pass_test("no 1997 skin imported — the flat panel is the fallback")
		return
	await get_tree().process_frame
	for pid in 2:
		var life: Button = screen._life_buttons[pid]
		for side in ["the register", "the face"]:
			if side == "the face":
				screen._life_menu_pid = pid
				screen._on_life_menu_chosen(DuelistFace.FLIP)
			for state in ["normal", "hover"]:
				var box := life.get_theme_stylebox(state) as StyleBoxTexture
				assert_not_null(box, "%s, %s" % [side, state])
				if box == null:
					continue
				var shown := box.region_rect
				assert_almost_eq(shown.size.x / shown.size.y, _halfway(life.size), 0.001,
					"seat %d, %s, %s: halfway to the panel's shape" % [pid, side, state])
		# A panel of another shape (above its minimum size, so it takes
		# it): the shown part follows at once.
		var before := life.size
		life.size = Vector2(300, 100)
		assert_ne(life.size, before)
		var after := (life.get_theme_stylebox("normal") as StyleBoxTexture).region_rect
		assert_almost_eq(after.size.x / after.size.y, _halfway(Vector2(300, 100)), 0.001,
			"seat %d follows" % pid)


# ======================================================== the flipping ==

func test_a_fresh_register_shows_lifepoints() -> void:
	for pid in 2:
		assert_false(screen._face_shown(pid), "seat %d starts face down" % pid)
		assert_eq(screen._life_buttons[pid].text,
			str(screen.game.players[pid].life))


func test_the_menu_turns_the_panel_over_and_back() -> void:
	screen._life_menu_pid = 0
	screen._on_life_menu_chosen(DuelistFace.FLIP)
	assert_true(screen._face_shown(0), "flipped to the face")
	assert_eq(screen._life_buttons[0].text, "",
		"the numeral goes with the wallpaper it was written on")
	assert_false(screen._face_shown(1), "the other register is untouched")
	screen._on_life_menu_chosen(DuelistFace.FLIP)
	assert_false(screen._face_shown(0), "and back again, same entry")
	assert_eq(screen._life_buttons[0].text, str(screen.game.players[0].life))


func test_the_menu_reads_whichever_way_the_panel_faces() -> void:
	screen._open_life_menu(0, Vector2(10, 10))
	assert_eq(screen._life_menu.get_item_text(DuelistFace.FLIP),
		"Flip over to face")
	screen._life_menu.hide()
	screen._face_flipped[0] = true
	screen._open_life_menu(0, Vector2(10, 10))
	assert_eq(screen._life_menu.get_item_text(DuelistFace.FLIP),
		"Flip back to lifepoints")
	screen._life_menu.hide()


func test_help_is_listed_and_live() -> void:
	# Greyed until 2026-10-13 (there was no Dueling Help to open); it opens
	# the life register's mini help now (tests/ui/test_c2_f_minihelp_menus.gd).
	screen._open_life_menu(0, Vector2(10, 10))
	assert_eq(screen._life_menu.item_count, 4, "all four entries listed")
	assert_false(screen._life_menu.is_item_disabled(3), "Help... is live")
	screen._life_menu.hide()


func test_the_flip_entry_is_greyed_without_a_face_to_flip_to() -> void:
	if GameSkin.is_present():
		pass_test("the skin is imported, so there is a face — see the "
			+ "art test above")
		return
	screen._open_life_menu(0, Vector2(10, 10))
	assert_true(screen._life_menu.is_item_disabled(DuelistFace.FLIP))
	screen._life_menu.hide()


# =============================================== the AUTOMATIC flip ==

func test_a_player_targeting_spell_turns_both_registers_over() -> void:
	# Lightning Bolt: "any target", so both duelists are legal — and
	# `Duel.hlp` says the register flips over for exactly that reason.
	var bolt := CardRegistry.get_card("Lightning Bolt")
	assert_not_null(bolt, "Lightning Bolt is in the pool")
	var inst := _into_hand(bolt)
	screen._click_hand_card(inst)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "the cast is aiming")
	for pid in 2:
		assert_true(screen._player_is_targetable(pid),
			"seat %d is a legal target" % pid)
		assert_true(screen._face_shown(pid),
			"seat %d's register turned over on its own" % pid)
	screen._refresh()
	assert_eq(screen._life_buttons[0].text, "", "no number over the face")
	# ...and back on its own when the aiming stops. Nothing stored the
	# automatic flip, so nothing has to remember to undo it.
	screen._on_escape()
	assert_false(screen._face_shown(0), "flipped back automatically")
	assert_false(screen._face_shown(1))


func test_a_creature_only_spell_leaves_the_registers_alone() -> void:
	# Healing Salve targets a player; Giant Growth does not. The face must
	# not appear for a spell that could never take a duelist.
	var growth := CardRegistry.get_card("Giant Growth")
	assert_not_null(growth)
	var inst := _into_hand(growth)
	screen._click_hand_card(inst)
	for pid in 2:
		assert_false(screen._player_is_targetable(pid),
			"seat %d cannot be a target of Giant Growth" % pid)
		assert_false(screen._face_shown(pid))
	screen._on_escape()


func test_a_hand_flip_survives_the_automatic_one() -> void:
	# The player turned it over; a spell turning it over too must not undo
	# their choice when it finishes.
	screen._life_menu_pid = 0
	screen._on_life_menu_chosen(DuelistFace.FLIP)
	var bolt := CardRegistry.get_card("Lightning Bolt")
	if bolt == null:
		return
	var inst := _into_hand(bolt)
	screen._click_hand_card(inst)
	screen._on_escape()
	assert_true(screen._face_shown(0), "the player's own flip is still on")
	assert_false(screen._face_shown(1), "the automatic one is not")


func _into_hand(data: CardData) -> CardInstance:
	var game := screen.game
	var inst := CardInstance.new(data, game._next_instance_id, 0)
	game._next_instance_id += 1
	game._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	game.players[0].hand.append(inst)
	# Enough mana that the cast is not refused for cost before it aims.
	for _i in 5:
		var land := CardRegistry.get_card("Mountain")
		if land == null:
			break
		var permanent := CardInstance.new(land, game._next_instance_id, 0)
		game._next_instance_id += 1
		game._instances[permanent.id] = permanent
		game._put_on_battlefield(permanent, 0)
	game.recalculate()
	return inst
