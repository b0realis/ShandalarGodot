extends GameTest
## Card pins from the 2026-09 full audit (docs/audit-2026-09.md).
## Every test here failed before the fix recorded in the same row of that
## document, and each one quotes the oracle behaviour it protects.


# --------------------------------------------------------------- Mana Short --

func test_mana_short_costs_two_generic_and_one_blue() -> void:
	# Printed cost is {2}{U} (cards/data/2ed.json and 4ed.json agree, as does
	# mage-go); the card was built at {1}{U} — a mana cheaper every game.
	var short := give_hand(0, "Mana Short")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, short, [TargetRef.player(1)]), "not enough mana")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, short, [TargetRef.player(1)]))


# ------------------------------------------------------------- Dragon Whelp --

func test_dragon_whelp_is_a_two_three() -> void:
	# Printed 2/3 (both snapshots and mage-go); it was built as a 4/4.
	var whelp := put_battlefield(0, "Dragon Whelp")
	assert_eq(whelp.cur_power, 2)
	assert_eq(whelp.cur_toughness, 3)


func test_dragon_whelp_counts_breaths_per_turn() -> void:
	# "If this ability has been activated four or more times THIS TURN" —
	# the count lived in card memory, which nothing resets between turns, so
	# the fourth breath of the GAME doomed the Whelp.
	var whelp := put_battlefield(0, "Dragon Whelp")
	for _turn in 3:
		advance_to_step(Mtg.Step.MAIN1)
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.activate_ability(0, whelp, 0, []))
		resolve_stack()
		advance_to_next_turn()   # opponent's turn
		advance_to_next_turn()   # back to ours
	assert_eq(whelp.zone, Mtg.Zone.BATTLEFIELD,
		"three separate turns of one breath each must never add up to four")


func test_dragon_whelp_burns_out_by_sacrifice() -> void:
	# "Sacrifice this creature at the beginning of the next end step" — a
	# sacrifice, so a regeneration shield cannot save it (CR 701.17).
	var whelp := put_battlefield(0, "Dragon Whelp")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R, 4)
	for _i in 4:
		assert_ok(g.activate_ability(0, whelp, 0, []))
		resolve_stack()
	whelp.regeneration_shields = 1
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(whelp.zone, Mtg.Zone.GRAVEYARD, "a sacrifice ignores regeneration")


# ---------------------------------------------- "activate only during your ..." --

func test_cyclopean_tomb_only_mires_in_your_own_upkeep() -> void:
	# "Activate only during YOUR upkeep" — the step was enforced, the turn
	# was not, so the Tomb worked in the opponent's upkeep too.
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var forest := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.END)      # ... out of our own turn ...
	advance_to_step(Mtg.Step.UPKEEP)   # ... and into the opponent's upkeep
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))   # priority reaches us; the turn is still theirs
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, tomb, 0, [TargetRef.card(forest)]),
		"your turn")


func test_clockwork_avian_only_rewinds_in_your_own_upkeep() -> void:
	var avian := put_battlefield(0, "Clockwork Avian")
	advance_to_step(Mtg.Step.END)
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 1)
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, avian, 0, [], 2), "your turn")


# ---------------------------------------- "mana value X" is a targeting restriction --

func test_detonate_refuses_an_artifact_of_the_wrong_mana_value() -> void:
	# "Destroy target artifact with mana value X" (CR 115.4): an artifact of
	# another mana value is not a legal target, so the cast is refused —
	# it used to be castable and then quietly do nothing.
	var ring := put_battlefield(1, "Sol Ring")       # mana value 1
	var disk := put_battlefield(1, "Nevinyrral's Disk")  # mana value 4
	var bomb := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G, 4)
	assert_refused(g.cast_spell(0, bomb, [TargetRef.card(disk)], 1))
	assert_ok(g.cast_spell(0, bomb, [TargetRef.card(ring)], 1))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 19, "and X damage to its controller")


func test_spell_blast_refuses_a_spell_of_the_wrong_mana_value() -> void:
	# "Counter target spell with mana value X" — same targeting restriction.
	var bolt := give_hand(1, "Lightning Bolt")       # mana value 1
	var blast := give_hand(0, "Spell Blast")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))   # the opponent gets a window
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, blast, [TargetRef.card(bolt)], 2))
	assert_ok(g.cast_spell(0, blast, [TargetRef.card(bolt)], 1))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20, "the Bolt never resolved")


# ------------------------------------------------------------- Fellwar Stone --

func test_fellwar_stone_offers_every_colour_the_opponent_could_make() -> void:
	# "Add one mana of ANY color that a land an opponent controls could
	# produce" — the choice is the controller's; the Stone used to hand back
	# the first colour it happened to walk past.
	var stone := put_battlefield(0, "Fellwar Stone")
	put_battlefield(1, "Plains")
	put_battlefield(1, "Island")
	g.set_agent(0, BlueLover.new())
	assert_ok(g.tap_for_mana(0, stone))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1,
		"the controller picks blue over white")


func test_fellwar_stone_makes_nothing_without_a_coloured_opponent_land() -> void:
	var stone := put_battlefield(0, "Fellwar Stone")
	assert_ok(g.tap_for_mana(0, stone))
	assert_eq(g.players[0].mana_pool.total(), 0,
		"no opponent land could produce coloured mana, so no mana is added")


## A seat that always answers "blue" to a colour question.
class BlueLover extends DecisionAgent:
	func answer_color(_game: MtgGame, _pid: int, _prompt: String, _hint: int) -> int:
		return Mtg.ManaColor.U
