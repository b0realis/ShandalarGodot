extends GameTest
## THE COUNTER STONES — `game/duel/counter_marks.gd` and the counter row
## of `game/duel/mini_card.gd`, 2026-09-08. Until today no small card drew
## its counters at all (`docs/card-states.md` §3.7 carried the gap as
## deliberate) and the 1997 game's `Cardcounters.pic` and its
## `@CUECARD_COUNTERS_*` strings (`UIStrings.txt:745-840`) were not
## imported. What is pinned:
##
##   1. A permanent with counters wears ONE CHIP PER KIND with the count,
##      and its cue card says the 1997 line for that card — `Carrion
##      counters: 1` on an Osai Vultures, `+1/+1 counters: 2` on a Sengir
##      Vampire — VERBATIM.
##   2. A card without counters wears nothing, and a face-down one hides
##      its row like the rest of its face.
##   3. Two kinds are two chips, each with its own line.
##   4. Without the skin the chip is still there, lettered — the clean
##      skin's fallback — so the count never depends on a file.
##   5. The tables are the executable's own (`Magic.exe` 0x4d4ca0 and
##      0x4d3cc0), and the stone is cut from the strip at its native size
##      with its mask applied.
##   6. A permanent carrying counters is never folded into a strip pile,
##      whose covered rows would hide the row it wears.


func _mini(inst: CardInstance) -> MiniCard:
	var w := MiniCard.new(inst, g)
	add_child_autofree(w)
	return w


# ================================= 1. the chip and the cue, verbatim ==

func test_a_sengir_vampire_with_two_counters_wears_one_chip_and_says_so() -> void:
	var vampire := put_battlefield(0, "Sengir Vampire")
	g.add_counters(vampire, "+1/+1", 2)
	var card := _mini(vampire)
	var chips := card.counter_chips()
	assert_eq(chips.size(), 1, "one chip for the one kind")
	assert_eq(chips[0]["kind"], "+1/+1")
	assert_eq(chips[0]["count"], 2, "...with the count on it, not a stone per counter")
	assert_true(card._counter_row.visible, "the row is shown")
	# `@CUECARD_COUNTERS_SengirVampire`, UIStrings.txt:785 — verbatim.
	assert_true(card.tooltip_text.contains("+1/+1 counters: 2"),
		"the cue card names them the 1997 way: " + card.tooltip_text)


func test_an_osai_vultures_carrion_counter_uses_its_own_line() -> void:
	var vultures := put_battlefield(0, "Osai Vultures")
	g.add_counters(vultures, "carrion", 1)
	var card := _mini(vultures)
	var chips := card.counter_chips()
	assert_eq(chips.size(), 1)
	assert_eq(chips[0]["kind"], "carrion")
	assert_eq(chips[0]["count"], 1)
	# `@CUECARD_COUNTERS_OsaiVultures`, UIStrings.txt:777 — the owner's
	# own example, verbatim.
	assert_true(card.tooltip_text.contains("Carrion counters: 1"),
		card.tooltip_text)


func test_the_count_follows_the_counters() -> void:
	var vultures := put_battlefield(0, "Osai Vultures")
	g.add_counters(vultures, "carrion", 1)
	var card := _mini(vultures)
	g.add_counters(vultures, "carrion", 2)
	card.refresh()
	assert_eq(card.counter_chips()[0]["count"], 3)
	assert_true(card.tooltip_text.contains("Carrion counters: 3"))
	g.remove_counters(vultures, "carrion", 3)
	card.refresh()
	assert_eq(card.counter_chips().size(), 0, "none left, no chip")


# ============================ 2. nothing without, nothing face down ==

func test_a_card_without_counters_wears_no_chip() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var card := _mini(bears)
	assert_eq(card.counter_chips().size(), 0)
	assert_false(card._counter_row.visible)
	assert_false(card.tooltip_text.contains("counters:"),
		"and the cue card says nothing about counters")
	assert_eq(card._status_label.offset_left, float(MiniCard.COUNTER_ROW_LEFT),
		"the status text keeps its old place when there is no row")


func test_a_face_down_card_hides_its_counters_with_the_rest_of_its_face() -> void:
	var vampire := put_battlefield(0, "Sengir Vampire")
	g.add_counters(vampire, "+1/+1", 1)
	var card := _mini(vampire)
	assert_true(card._counter_row.visible)
	card.face_down = true
	assert_false(card._counter_row.visible,
		"a card back tells the table nothing about itself")
	assert_false(card.tooltip_text.contains("counters:"))


# ======================================= 3. two kinds, two chips ==

func test_two_kinds_are_two_chips_each_with_its_own_line() -> void:
	# A Sengir Vampire that grew one head and then took an Unstable
	# Mutation: its OWN kind by its own line, the foreign kind by the
	# Mutation's (`UIStrings.txt:827`, the 1997 wording, not Manalink's).
	var vampire := put_battlefield(0, "Sengir Vampire")
	g.add_counters(vampire, "+1/+1", 1)
	g.add_counters(vampire, "-1/-1", 2)
	var card := _mini(vampire)
	var chips := card.counter_chips()
	assert_eq(chips.size(), 2)
	assert_eq(chips[0]["kind"], "+1/+1")
	assert_eq(chips[1]["kind"], "-1/-1")
	assert_eq(chips[1]["count"], 2)
	assert_true(card.tooltip_text.contains("+1/+1 counters: 1"), card.tooltip_text)
	assert_true(card.tooltip_text.contains("Mutation (-1/-1) counters: 2"), card.tooltip_text)
	assert_gt(card._status_label.offset_left, float(MiniCard.COUNTER_ROW_LEFT),
		"the status text has moved out from under the chips")
	assert_lt(card._counter_row.size.x + card._counter_row.offset_left,
		float(MiniCard.SIZE.x - MiniCard.CORNER_MARK),
		"the row stops short of the WILL_UNTAP arrow's corner")


# ======================================== 4. the clean-skin fallback ==

func test_without_the_strip_the_chip_is_lettered_and_still_there() -> void:
	# Take the strip away from a running widget: a null in the texture
	# cache is what `GameSkin.texture` returns for a file that is not
	# there, and the cut stones are dropped so nothing is remembered.
	GameSkin._texture_cache[CounterMarks.SKIN_KEY] = null
	CounterMarks.clear_cache()
	var vultures := put_battlefield(0, "Osai Vultures")
	g.add_counters(vultures, "carrion", 2)
	var card := _mini(vultures)
	var chips := card.counter_chips()
	GameSkin._texture_cache.erase(CounterMarks.SKIN_KEY)
	CounterMarks.clear_cache()
	assert_eq(chips.size(), 1, "the chip is there without the file")
	assert_false(chips[0]["stone"], "...lettered, with no stone on it")
	assert_eq(chips[0]["count"], 2)
	assert_true(card._counter_row.visible)
	assert_true(card.tooltip_text.contains("Carrion counters: 2"),
		"the cue card does not depend on the file either")


func test_a_kind_the_1997_game_never_drew_gets_the_lettered_chip_and_a_generic_line() -> void:
	# Pupa's pupae (Legends) had no stone and no string in 1997. The chip
	# is the clean one whatever the skin, and the line is the generic
	# `<Kind> counters: %d` — the same shape as the 24 real ones.
	var bears := put_battlefield(0, "Grizzly Bears")
	g.add_counters(bears, "pupa", 1)
	var card := _mini(bears)
	var chips := card.counter_chips()
	assert_eq(chips.size(), 1)
	assert_false(chips[0]["stone"])
	assert_true(card.tooltip_text.contains("Pupa counters: 1"), card.tooltip_text)


# ================================= 5. the tables and the stone cut ==

func test_the_cue_rows_are_the_twenty_four_of_the_string_table() -> void:
	assert_eq(CounterMarks.CUE_ROWS.size(), 24, "UIStrings.txt:745-840, one per card")
	for row in CounterMarks.CUE_ROWS:
		assert_true(str(row[2]).ends_with("counters: %d"), str(row))
	assert_eq(CounterMarks.cue_template("Osai Vultures", "carrion"), "Carrion counters: %d")
	assert_eq(CounterMarks.cue_template("Armageddon Clock", "doom"), "Doom counters: %d")
	assert_eq(CounterMarks.cue_template("Tetravus", "+1/+1"), "Drone (+1/+1) counters: %d")
	assert_eq(CounterMarks.cue_template("Ivory Cup", "life"), "Life counters: %d",
		"the five charms share `@CUECARD_COUNTERS_LuckyCharms`")
	assert_eq(CounterMarks.cue_template("Blue Mana Battery", "charge"), "Charge counters: %d",
		"the five batteries share `@CUECARD_COUNTERS_ManaBattery`")
	# A foreign kind on a card that has a line of its own for ANOTHER
	# kind takes the foreign kind's line, not the card's.
	assert_eq(CounterMarks.cue_template("Sengir Vampire", "-0/-2"), "Shackle (-0/-2) counters: %d")
	assert_eq(CounterMarks.cue_template("Grizzly Bears", "+1/+1"), "+1/+1 counters: %d")
	assert_eq(CounterMarks.cue_template("Grizzly Bears", "-0/-1"), "Damage (-0/-1) counters: %d")
	assert_eq(CounterMarks.cue("Osai Vultures", "carrion", 4), "Carrion counters: 4")


func test_every_card_the_tables_name_is_in_the_pool() -> void:
	# A KEY THAT DOES NOT MATCH THE PRINTED NAME FAILS IN SILENCE: the
	# lookup falls through to the kind table and the card wears the wrong
	# stone rather than none, which no other assertion in this file can
	# see. "Khabál Ghoul" was keyed without its accent and wore Dwarven
	# Weaponsmith's red yin-yang instead of its own black one (found
	# 2026-09-09 while writing the help page for the stones).
	for card_name in CounterMarks.ROW_BY_CARD:
		assert_true(CardRegistry.has_card(card_name),
			"ROW_BY_CARD's '%s' is a card in the pool" % card_name)
	for card_name in CounterMarks.TILE_BY_CARD:
		assert_true(CardRegistry.has_card(card_name),
			"TILE_BY_CARD's '%s' is a card in the pool" % card_name)
	assert_eq(CounterMarks.tile_for("Khabál Ghoul", "+1/+1"), 16,
		"the black yin-yang, not the Weaponsmith's red one")


func test_the_stone_table_is_the_executables() -> void:
	# `Magic.exe` 0x4d4ca0: the card's own stone...
	assert_eq(CounterMarks.tile_for("Osai Vultures", "carrion"), 14, "the bird")
	assert_eq(CounterMarks.tile_for("Sengir Vampire", "+1/+1"), 16, "the black yin-yang")
	assert_eq(CounterMarks.tile_for("Rock Hydra", "+1/+1"), 20, "the red one")
	assert_eq(CounterMarks.tile_for("Cyclone", "wind"), 23, "the whirl")
	assert_eq(CounterMarks.tile_for("Time Vault", "turn"), 6, "the gear")
	# ...0x4d3cc0: the five kinds other cards put down, by the source's colour...
	assert_eq(CounterMarks.tile_for("Grizzly Bears", "+1/+1"), 20)
	assert_eq(CounterMarks.tile_for("Sengir Vampire", "-1/-1"), 22, "Unstable Mutation's blue")
	assert_eq(CounterMarks.tile_for("Sengir Vampire", "-0/-2"), 21, "Spirit Shackle's grey")
	assert_eq(CounterMarks.tile_for("Grizzly Bears", "-0/-1"), 20, "Orcish Catapult's red")
	# ...and nothing for a kind the 1997 game never had.
	assert_eq(CounterMarks.tile_for("Grizzly Bears", "pupa"), -1)
	assert_eq(CounterMarks.tile_for("Osai Vultures", "doom"), -1,
		"a card's own stone is for its own kind only")


func test_the_stone_is_cut_at_its_native_size_and_masked() -> void:
	if GameSkin.texture(CounterMarks.SKIN_KEY) == null:
		pass_test("no card_counters.png in this checkout — the decode is skipped")
		return
	CounterMarks.clear_cache()
	var stone := CounterMarks.tile(14)
	assert_not_null(stone, "the bird")
	assert_eq(stone.get_width(), CounterMarks.STONE.size.x, "22 wide")
	assert_eq(stone.get_height(), CounterMarks.STONE.size.y, "28 tall")
	var img := stone.get_image()
	assert_lt(img.get_pixel(0, 0).a, 0.5, "the corner outside the oval is clear")
	assert_gt(img.get_pixel(11, 14).a, 0.5, "the middle of the stone is opaque")
	var inked := 0
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a > 0.5 and px.r < 0.1 and px.g < 0.1 and px.b < 0.1:
				inked += 1
	assert_gt(inked, 0, "the glyph's black ink is painted, not punched through")
	assert_null(CounterMarks.tile(24), "the mask row is not a stone")
	assert_null(CounterMarks.tile(-1), "and -1 is 'none'")
	assert_true(CounterMarks.tile(14) == stone, "cut once, kept")


# ================================== 6. a counter keeps a card out of a pile ==

func _in_pile(node: Node) -> bool:
	var n := node.get_parent()
	while n != null:
		if n is CardPile:
			return true
		n = n.get_parent()
	return false


func _widgets(root: Node) -> Dictionary:
	var out := {}
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MiniCard and (n as MiniCard).instance != null:
			out[(n as MiniCard).instance.id] = n
		for c in n.get_children():
			stack.append(c)
	return out


func test_a_permanent_carrying_counters_keeps_a_slot_of_its_own() -> void:
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	var game: MtgGame = screen.game
	var cups: Array = []
	for _i in 3:
		var cup := CardInstance.new(CardRegistry.get_card("Ivory Cup"), game._next_instance_id, 0)
		game._next_instance_id += 1
		game._instances[cup.id] = cup
		game._put_on_battlefield(cup, 0)
		cups.append(cup)
	# Three cups: two plain ones and, LAST in the row, the one that has
	# gained life twice. The two pile; the third stands beside the pile.
	game.add_counters(cups[2], "life", 2)
	screen._refresh()
	await get_tree().process_frame
	var drawn := _widgets(screen)
	assert_true(drawn.has(cups[2].id), "the cup with the counters is drawn")
	assert_false(_in_pile(drawn[cups[2].id]),
		"...on a slot of its own, where its row is not covered")
	assert_true(_in_pile(drawn[cups[0].id]) and _in_pile(drawn[cups[1].id]),
		"the other two still pile")
	assert_eq((drawn[cups[2].id] as MiniCard).counter_chips().size(), 1)
