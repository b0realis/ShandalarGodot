extends GameTest
## THE AI'S MULLIGAN (2026-09-08). The owner, from a playtest: *"If you
## have no lands or all lands in hand, the ai or human decision to take
## mulligan is almost automatic - no special rules needed - ok maybe for
## ai lets write some mulliganning logic!"* — and [AiMulligan] is that
## logic, behind [member AiProfile.mulligans]: lands against a keep range
## that narrows with the hand, then whether those lands cast anything, and
## a floor under which any hand is kept.
##
## Hands are built in place; the judgment reads the hand and nothing else.


func _hand(pid: int, names: Array) -> void:
	for inst in g.players[pid].hand:
		inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].hand.clear()
	for card_name in names:
		give_hand(pid, card_name)


func _lands(land_name: String, count: int) -> Array:
	var out: Array = []
	for _i in count:
		out.append(land_name)
	return out


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


# ============================================================ the ranges --

func test_the_keep_ranges_and_the_floor() -> void:
	assert_eq(AiMulligan.FLOOR, 4)
	assert_eq(AiMulligan.KEEP_LANDS, {7: [2, 5], 6: [2, 4], 5: [1, 4]})
	assert_eq(AiMulligan.FLOOR, DecisionAgent.MULLIGAN_FLOOR, "one floor, one reason")


func test_no_land_and_all_land_go_back() -> void:
	_hand(0, ["Grizzly Bears", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears",
		"Grizzly Bears", "Grizzly Bears", "Grizzly Bears"])
	assert_eq(AiMulligan.reason(g, 0), "no land")
	assert_true(AiMulligan.wants_mulligan(g, 0))
	_hand(0, _lands("Forest", 7))
	assert_eq(AiMulligan.reason(g, 0), "all land")
	assert_true(AiMulligan.wants_mulligan(g, 0))


func test_one_land_in_seven_goes_back_and_two_keep() -> void:
	_hand(0, ["Forest", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears",
		"Grizzly Bears", "Grizzly Bears", "Grizzly Bears"])
	assert_eq(AiMulligan.reason(g, 0), "1 land in 7")
	_hand(0, ["Forest", "Forest", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears",
		"Grizzly Bears", "Grizzly Bears"])
	assert_eq(AiMulligan.reason(g, 0), "", "two Forests under green creatures: a keep")
	assert_false(AiMulligan.wants_mulligan(g, 0))


func test_six_lands_in_seven_go_back_and_five_keep() -> void:
	_hand(0, _lands("Forest", 6) + ["Grizzly Bears"])
	assert_eq(AiMulligan.reason(g, 0), "6 lands in 7")
	_hand(0, _lands("Forest", 5) + ["Grizzly Bears", "Grizzly Bears"])
	assert_eq(AiMulligan.reason(g, 0), "", "five lands and two spells is a slow keep")


func test_the_range_narrows_with_the_hand() -> void:
	# Five of six is out; five of seven was in.
	_hand(0, _lands("Forest", 5) + ["Grizzly Bears"])
	assert_eq(AiMulligan.reason(g, 0), "5 lands in 6")
	# One of five is in; one of six is out.
	_hand(0, ["Forest", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears"])
	assert_eq(AiMulligan.reason(g, 0), "")
	_hand(0, ["Forest", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears",
		"Grizzly Bears", "Grizzly Bears"])
	assert_eq(AiMulligan.reason(g, 0), "1 land in 6")


func test_the_floor_keeps_anything() -> void:
	_hand(0, _lands("Forest", 4))
	assert_eq(AiMulligan.reason(g, 0), "", "four lands, kept: the replacement is three")
	_hand(0, ["Grizzly Bears", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears"])
	assert_eq(AiMulligan.reason(g, 0), "", "four spells, kept for the same reason")
	_hand(0, [])
	assert_eq(AiMulligan.reason(g, 0), "", "nothing to judge")


# ============================================================ the colours --

func test_lands_that_cast_none_of_the_spells_go_back() -> void:
	# Two Islands under five red cards is no better than no land at all.
	_hand(0, ["Island", "Island", "Lightning Bolt", "Lightning Bolt", "Hill Giant",
		"Gray Ogre", "Fireball"])
	assert_eq(AiMulligan.reason(g, 0), "the lands cast none of the spells")
	assert_true(AiMulligan.wants_mulligan(g, 0))
	# One Mountain among them and the Bolt is a spell the hand can cast.
	_hand(0, ["Island", "Mountain", "Lightning Bolt", "Lightning Bolt", "Hill Giant",
		"Gray Ogre", "Fireball"])
	assert_eq(AiMulligan.reason(g, 0), "")


func test_the_colour_check_reads_pips_not_generic_mana() -> void:
	# Two Mountains cast a Hill Giant ({2}{R}) as far as colour goes: the
	# generic part is a matter of a later land drop, not of the keep.
	_hand(0, ["Mountain", "Mountain", "Hill Giant", "Hill Giant", "Hill Giant",
		"Hill Giant", "Hill Giant"])
	assert_eq(AiMulligan.reason(g, 0), "")
	assert_true(AiMulligan.casts_a_spell(g.players[0].hand))


func test_a_colourless_spell_is_cast_by_any_land() -> void:
	_hand(0, ["Island", "Island", "Sol Ring", "Lightning Bolt", "Lightning Bolt",
		"Lightning Bolt", "Lightning Bolt"])
	assert_eq(AiMulligan.reason(g, 0), "", "the Islands cast the Sol Ring")


func test_the_colour_check_is_waived_for_a_five() -> void:
	# A five is judged on its land count alone: it is one redraw from the
	# floor and a four of whatever colour is worse than this.
	_hand(0, ["Island", "Island", "Lightning Bolt", "Lightning Bolt", "Hill Giant"])
	assert_eq(AiMulligan.reason(g, 0), "")


func test_the_land_count_reads_lands_as_the_engine_does() -> void:
	_hand(0, ["Forest", "Mountain", "Sol Ring", "Grizzly Bears"])
	assert_eq(AiMulligan.land_count(g.players[0].hand), 2, "an artifact is not a land")


# ============================================================== the seat --

func test_the_pilot_judges_through_ai_mulligan() -> void:
	var ai := _wizard(0)
	assert_true(ai.profile.mulligans, "on for every profile")
	assert_true(AiProfile.apprentice().mulligans)
	_hand(0, ["Forest", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears",
		"Grizzly Bears", "Grizzly Bears", "Grizzly Bears"])
	assert_true(ai.choose_mulligan(g, 0), "one land in seven goes back")
	_hand(0, ["Island", "Island", "Lightning Bolt", "Lightning Bolt", "Hill Giant",
		"Gray Ogre", "Fireball"])
	assert_true(ai.choose_mulligan(g, 0), "wrong colours go back")


func test_with_the_knob_off_the_seat_uses_the_plain_rule() -> void:
	# The Deck Lab's null: no land or all land, and nothing else.
	var profile := AiProfile.wizard()
	profile.mulligans = false
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	_hand(0, ["Forest", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears",
		"Grizzly Bears", "Grizzly Bears", "Grizzly Bears"])
	assert_false(ai.choose_mulligan(g, 0), "one land is kept on the plain rule")
	_hand(0, _lands("Forest", 7))
	assert_true(ai.choose_mulligan(g, 0), "all land still goes back")
	_hand(0, _lands("Forest", 4))
	assert_false(ai.choose_mulligan(g, 0), "and the floor holds")


func test_the_knob_is_a_lab_override() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("mulligans=off"), "")
	assert_false(profile.mulligans)


func test_the_opening_runs_the_pilot_down_to_a_keep() -> void:
	# An all-Forest library deals all land every time: the pilot throws
	# back seven, six and five, and keeps the four the floor allows.
	var forests: Array = _lands("Forest", 40)
	var mixed: Array = _lands("Forest", 17)
	for _i in 23:
		mixed.append("Grizzly Bears")
	g = MtgGame.new()
	g.setup(forests, mixed, "P0", "P1", 20, 20, 99)
	g.set_agent(0, AiPlayer.new(0, AiProfile.wizard()))
	g.set_agent(1, AiPlayer.new(1, AiProfile.wizard()))
	g.deal_opening_hands(7)
	var opening := OpeningHand.new()
	add_child_autofree(opening)
	var lines: Array[String] = []
	opening.announced.connect(func(line: String) -> void: lines.append(line))
	await opening.run(g, 0, func(_pid: int) -> bool: return false)
	assert_eq(g.mulligans_taken[0], 3, str(lines))
	assert_eq(g.players[0].hand.size(), AiMulligan.FLOOR)
	assert_true(lines.has("P0 has all land and will take a mulligan, drawing 4"))
	assert_eq(g.turn_number, 1)
