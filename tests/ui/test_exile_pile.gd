extends GutTest
## THE EXILE PILE — the plate to the right of the graveyard, and the
## derived art behind it (`game/duel/exile_plate.gd`).
##
## The 1997 game had no exile plate at all (`@MENU_GRAVEYARD` reached the
## zone through the graveyard's right-click menu), so this pile is the
## owner's deliberate divergence and its plate is DERIVED — painted at the
## grave plate's own size out of the grave plate's own palette. These tests
## pin both halves: the pile behaves like the graveyard beside it, and the
## derived art never invents a colour.
##
## Every test needs the original skin (`assets/original/`); without it the
## duel table draws no pile plates at all and the checks are skipped, which
## is the same contract `GameSkin` gives every other caller.


func _skin_present() -> bool:
	return GameSkin.texture("grave_panel_red") != null


func test_the_derived_plate_matches_the_grave_plates_footprint() -> void:
	if not _skin_present():
		return
	for seat_color in ["white", "blue", "black", "red", "green"]:
		var grave := GameSkin.texture("grave_panel_" + seat_color)
		var exile := ExilePlate.plate(seat_color)
		assert_not_null(exile, "a seat with a grave plate has an exile plate")
		assert_eq(exile.get_size(), grave.get_size(),
			"%s: the two piles are the same plate size" % seat_color)


func test_the_derived_plate_only_uses_the_grave_plates_own_colours() -> void:
	# The provenance claim in exile_plate.gd's header, pinned: the
	# composition is ours, every COLOUR is 1997's.
	if not _skin_present():
		return
	for seat_color in ["white", "blue", "black", "red", "green"]:
		var source := GameSkin.texture("grave_panel_" + seat_color).get_image()
		var allowed: Dictionary = {}
		for y in source.get_height():
			for x in source.get_width():
				allowed[source.get_pixel(x, y).to_rgba32()] = true
		var painted := ExilePlate.plate(seat_color).get_image()
		var strangers := 0
		for y in painted.get_height():
			for x in painted.get_width():
				if not allowed.has(painted.get_pixel(x, y).to_rgba32()):
					strangers += 1
		assert_eq(strangers, 0,
			"%s: %d pixels are not a colour of the 1997 plate"
				% [seat_color, strangers])


func test_the_derived_plate_wears_the_originals_white_border() -> void:
	# Grave_*.pic.png is 59x89 of art inside a 1px white frame; the plate
	# beside it has to be built the same way or the pair does not match.
	if not _skin_present():
		return
	var img := ExilePlate.plate("red").get_image()
	var w := img.get_width()
	var h := img.get_height()
	var gaps := 0
	for x in w:
		gaps += int(img.get_pixel(x, 0) != Color.WHITE)
		gaps += int(img.get_pixel(x, h - 1) != Color.WHITE)
	for y in h:
		gaps += int(img.get_pixel(0, y) != Color.WHITE)
		gaps += int(img.get_pixel(w - 1, y) != Color.WHITE)
	assert_eq(gaps, 0, "the 1px white frame runs all the way round")
	assert_ne(img.get_pixel(w / 2, h / 2), Color.WHITE, "and only the frame")


func test_there_is_no_exile_plate_without_the_original_skin() -> void:
	# The two piles appear and disappear together: nothing is invented for
	# a player who never imported the original art.
	assert_null(ExilePlate.plate("no such seat colour"))


func test_the_sidebar_carries_an_exile_pile_beside_the_graveyard() -> void:
	if not _skin_present():
		return
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	for pid in 2:
		assert_not_null(screen._exile_icons[pid], "seat %d has an exile pile" % pid)
		var row := screen._grave_icons[pid].get_parent()
		assert_eq(screen._exile_icons[pid].get_parent(), row,
			"it shares the piles row with the deck and the graveyard")
		assert_gt(screen._exile_icons[pid].get_index(),
			screen._grave_icons[pid].get_index(),
			"and sits to the RIGHT of the graveyard")


func test_the_exile_pile_shows_its_top_card() -> void:
	# Exactly the graveyard's own rule: the top card when it holds one,
	# the empty plate when it does not.
	if not _skin_present():
		return
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var empty_plate: Texture2D = screen._exile_icons[0].texture
	assert_not_null(empty_plate, "an empty pile still wears its plate")
	var gone: CardInstance = screen.game.players[0].hand[0]
	screen.game.players[0].hand.erase(gone)
	gone.zone = Mtg.Zone.EXILE
	screen.game.players[0].exile.append(gone)
	screen._refresh()
	assert_ne(screen._exile_icons[0].texture, empty_plate,
		"a filled exile pile shows its top card")


func test_clicking_the_exile_pile_opens_the_same_viewer() -> void:
	# GraveyardView already lays out all three of @MENU_GRAVEYARD's zones,
	# so the exile plate opens it rather than a second overlay.
	if not _skin_present():
		return
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var gone: CardInstance = screen.game.players[0].hand[0]
	screen.game.players[0].hand.erase(gone)
	gone.zone = Mtg.Zone.EXILE
	screen.game.players[0].exile.append(gone)
	screen._refresh()
	screen._on_grave_pile_clicked(0)
	assert_true(screen.graveyard_is_open(), "the pile viewer opened")
	assert_not_null(screen._grave_view)
	assert_false(screen._grave_view.shown(Mtg.Zone.EXILE, 0).is_empty(),
		"and it is showing the exiled card")
	screen._on_grave_pile_clicked(0)
	assert_false(screen.graveyard_is_open(), "the same pile again shuts it")
