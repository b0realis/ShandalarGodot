extends GameTest
## THE OPENING HAND COUNTS MANA, NOT LANDS (2026-09-10, casting note P12).
##
## [AiMulligan] read the keep band against [method AiMulligan.land_count],
## and the era's mana is not all land: a Mox is a land drop that does not
## use the land drop up, a Black Lotus is three of them at once, and a
## Mana Crypt is two. So a hand of one Island and two Moxen — four mana on
## turn one, the best keep in the format — went back as "1 land in 7", and
## an Island beside a Mox Ruby could not cast the Lightning Bolt the Mox
## pays for ("the lands cast none of the spells"). Sixty-nine of the pool's
## 217 loadable lists carry one of those cards — nineteen of them 1997
## enemy decks — and the five shipped starters carry none, which is why
## the null does not move.
##
## THE CORRECTION IS ONE-DIRECTIONAL, and that is the whole of its safety:
## it only ever turns a mulligan into a keep. The FLOOR of the band is read
## against [method AiMulligan.mana_sources] (lands plus the free sources)
## and the CEILING still against the lands alone, because "nothing but
## land" asks what the hand can cast and a Mox is a spell. No knob: the
## rungs all judge their opening hand through [member AiProfile.mulligans]
## and a hand that functions is not a difficulty setting (CR 103.4).
##
## Hands are built in place; the judgement reads the hand and nothing else.


func _hand(pid: int, names: Array) -> void:
	for inst in g.players[pid].hand:
		inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].hand.clear()
	for card_name in names:
		give_hand(pid, card_name)


func _fill(names: Array, filler: String, upto: int) -> Array:
	var out: Array = names.duplicate()
	while out.size() < upto:
		out.append(filler)
	return out


# ================================================== what a free source is --

func test_the_free_sources_are_named_by_shape() -> void:
	# {0} and a mana ability, and no card name anywhere: five Moxen, the
	# Lotus and the Crypt are the whole of it in this pool.
	for card_name in ["Mox Ruby", "Mox Jet", "Mox Pearl", "Mox Sapphire",
			"Mox Emerald", "Black Lotus", "Mana Crypt"]:
		var inst := give_hand(0, card_name)
		assert_true(AiMulligan.is_free_source(inst), card_name)
	# A Sol Ring costs {1}: it needs the land drop this hand has not got.
	assert_false(AiMulligan.is_free_source(give_hand(0, "Sol Ring")))
	# A land is a land, counted by land_count and not twice.
	assert_false(AiMulligan.is_free_source(give_hand(0, "Forest")))
	# A spell that makes no mana is no source however cheap.
	assert_false(AiMulligan.is_free_source(give_hand(0, "Ornithopter")))


func test_mana_sources_is_the_lands_plus_the_free_ones() -> void:
	_hand(0, ["Island", "Mox Ruby", "Black Lotus", "Sol Ring", "Grizzly Bears"])
	assert_eq(AiMulligan.land_count(g.players[0].hand), 1, "one land")
	assert_eq(AiMulligan.mana_sources(g.players[0].hand), 3, "and two free sources")


# ========================================================== the low end --

func test_one_land_and_a_mox_is_a_keep() -> void:
	# The hand the note is about: it makes two mana on turn one.
	_hand(0, _fill(["Island", "Mox Sapphire"], "Counterspell", 7))
	assert_eq(AiMulligan.reason(g, 0), "")
	assert_false(AiMulligan.wants_mulligan(g, 0))


func test_one_land_and_a_lotus_is_a_keep() -> void:
	_hand(0, _fill(["Island", "Black Lotus"], "Counterspell", 7))
	assert_eq(AiMulligan.reason(g, 0), "")


func test_no_land_and_two_free_sources_is_a_keep() -> void:
	# Two mana is two mana. The band's floor asks for a count, not a type.
	_hand(0, _fill(["Mox Sapphire", "Black Lotus"], "Counterspell", 7))
	assert_eq(AiMulligan.reason(g, 0), "")


func test_the_hands_that_must_still_go_back() -> void:
	# A one-lander with nothing else that makes mana is the hand the band
	# was written about, whatever it holds.
	_hand(0, _fill(["Mountain"], "Serra Angel", 7))
	assert_eq(AiMulligan.reason(g, 0), "1 land in 7")
	# Cheap spells do not buy the keep either: one land is one land.
	_hand(0, _fill(["Mountain"], "Lightning Bolt", 7))
	assert_eq(AiMulligan.reason(g, 0), "1 land in 7")
	# A Sol Ring is not a land drop — it needs the land this hand lacks.
	_hand(0, _fill(["Mountain", "Sol Ring"], "Lightning Bolt", 7))
	assert_eq(AiMulligan.reason(g, 0), "1 land in 7")
	# One free source and no land is still one mana.
	_hand(0, _fill(["Mox Ruby"], "Lightning Bolt", 7))
	assert_eq(AiMulligan.reason(g, 0), "no land")
	# And no mana at all is no game, as it always was.
	_hand(0, _fill([], "Lightning Bolt", 7))
	assert_eq(AiMulligan.reason(g, 0), "no land")


func test_the_six_and_the_five_read_the_same_census() -> void:
	_hand(0, _fill(["Island", "Mox Sapphire"], "Counterspell", 6))
	assert_eq(AiMulligan.reason(g, 0), "", "two mana of six keeps")
	_hand(0, _fill(["Island"], "Counterspell", 6))
	assert_eq(AiMulligan.reason(g, 0), "1 land in 6")
	# A five asks for one, and a lone Mox is that one.
	_hand(0, _fill(["Mox Sapphire"], "Counterspell", 5))
	assert_eq(AiMulligan.reason(g, 0), "")


# ========================================================= the ceiling --

func test_the_ceiling_still_counts_lands_alone() -> void:
	# Five lands and two Moxen is not "all land": the Moxen are spells,
	# and the question the ceiling asks is what the hand can cast.
	_hand(0, ["Island", "Island", "Island", "Island", "Island",
		"Mox Sapphire", "Mox Sapphire"])
	assert_eq(AiMulligan.reason(g, 0), "")
	_hand(0, ["Island", "Island", "Island", "Island", "Island", "Island",
		"Mox Sapphire"])
	assert_eq(AiMulligan.reason(g, 0), "6 lands in 7", "six lands is still six")


func test_all_land_still_goes_back() -> void:
	_hand(0, ["Forest", "Forest", "Forest", "Forest", "Forest", "Forest", "Forest"])
	assert_eq(AiMulligan.reason(g, 0), "all land")


# ========================================================== the colours --

func test_the_colour_check_reads_the_free_sources() -> void:
	# Two Islands under five red cards is no better than no land at all —
	# unless one of them is a Mox Ruby, which casts the Bolt.
	_hand(0, ["Island", "Island", "Lightning Bolt", "Lightning Bolt", "Hill Giant",
		"Gray Ogre", "Fireball"])
	assert_eq(AiMulligan.reason(g, 0), "the lands cast none of the spells")
	_hand(0, ["Island", "Island", "Mox Ruby", "Lightning Bolt", "Hill Giant",
		"Gray Ogre", "Fireball"])
	assert_eq(AiMulligan.reason(g, 0), "")
	assert_true(AiMulligan.casts_a_spell(g.players[0].hand))


func test_a_lotus_casts_any_colour() -> void:
	_hand(0, ["Island", "Black Lotus", "Hypnotic Specter", "Hypnotic Specter",
		"Hypnotic Specter", "Hypnotic Specter", "Hypnotic Specter"])
	assert_eq(AiMulligan.reason(g, 0), "", "the Lotus makes the {B}{B}")


# ============================================================= the null --

func test_a_hand_with_no_free_source_judges_exactly_as_before() -> void:
	# The shipped five carry no Mox and no Lotus, which is why the whole
	# recorded baseline is untouched: with none in hand the census IS the
	# land count and every line above reads as it did on 2026-09-08.
	var hands := [
		["Forest", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears",
			"Grizzly Bears", "Grizzly Bears", "Grizzly Bears"],
		["Forest", "Forest", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears",
			"Grizzly Bears", "Grizzly Bears"],
		["Forest", "Forest", "Forest", "Forest", "Forest", "Forest", "Grizzly Bears"],
		["Island", "Island", "Lightning Bolt", "Lightning Bolt", "Hill Giant",
			"Gray Ogre", "Fireball"],
	]
	var reasons := ["1 land in 7", "", "6 lands in 7", "the lands cast none of the spells"]
	for i in hands.size():
		_hand(0, hands[i])
		assert_eq(AiMulligan.mana_sources(g.players[0].hand),
			AiMulligan.land_count(g.players[0].hand), "no free source, one census")
		assert_eq(AiMulligan.reason(g, 0), reasons[i], str(hands[i]))


# ============================================================= the seat --

func test_every_rung_keeps_the_hand() -> void:
	# No knob and no rung: [member AiProfile.mulligans] is on everywhere,
	# and a hand that makes two mana on turn one is not a difficulty
	# setting.
	for profile in [AiProfile.apprentice(), AiProfile.magician(),
			AiProfile.sorcerer(), AiProfile.wizard()]:
		var ai := AiPlayer.new(0, profile)
		g.set_agent(0, ai)
		_hand(0, _fill(["Island", "Mox Sapphire"], "Counterspell", 7))
		assert_false(ai.choose_mulligan(g, 0), profile.profile_name)
		_hand(0, _fill(["Island"], "Counterspell", 7))
		assert_true(ai.choose_mulligan(g, 0), profile.profile_name + ", one mana")


func test_with_the_knob_off_the_plain_rule_is_untouched() -> void:
	# The Deck Lab's null: no land or all land, and nothing else. A Mox
	# has never been a land to [method MtgGame.hand_is_a_mulligan_hand]
	# and is not one now.
	var profile := AiProfile.wizard()
	profile.mulligans = false
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	_hand(0, _fill(["Island", "Mox Ruby"], "Lightning Bolt", 7))
	assert_false(ai.choose_mulligan(g, 0), "one land is one land to the plain rule")
	_hand(0, _fill(["Mox Ruby"], "Lightning Bolt", 7))
	assert_true(ai.choose_mulligan(g, 0), "and a Mox is not a land to it: no land, back it goes")
