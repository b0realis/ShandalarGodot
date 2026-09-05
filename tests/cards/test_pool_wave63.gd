extends GameTest
## Wave-63 tests: the OPTION choice primitive (DecisionAgent.choose_option /
## choose_number), the "as it enters" replacement hook
## (CardData.as_it_enters) and the six cards that needed them —
## Shapeshifter, Wood Elemental, Nameless Race, Tetravus, Power Leak and
## Petra Sphinx.


## Answers every OPTION question with a fixed number (choose_number) or a
## fixed index (choose_option), and says yes to everything else.
class NumberAgent extends DecisionAgent:
	var want := 0
	var say_yes := true

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], _hint: int) -> int:
		# choose_number's labels ARE the numbers, so a test can ask for one
		# by value; anything else takes `want` as a plain index.
		var as_text := str(want)
		var by_value := options.find(as_text)
		return by_value if by_value >= 0 else clampi(want, 0, options.size() - 1)

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return say_yes


func _numbers(pid: int, want: int) -> NumberAgent:
	var agent := NumberAgent.new()
	agent.want = want
	g.set_agent(pid, agent)
	return agent


func _bury(pid: int, card_name: String) -> CardInstance:
	var dead := give_hand(pid, card_name)
	g.players[pid].hand.erase(dead)
	dead.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(dead)
	return dead


func test_registry_loaded_wave63() -> void:
	for name in ["Shapeshifter", "Wood Elemental", "Nameless Race",
			"Tetravus", "Power Leak", "Petra Sphinx"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------- the OPTION primitive --

func test_choose_number_answers_with_the_number_not_the_index() -> void:
	var agent := _numbers(0, 5)
	assert_eq(agent.choose_number(g, 0, 3, 9, "pick", 3), 5)
	assert_eq(g.choice_log.size(), 1, "the question is on the record")
	var asked: PlayerChoice = g.choice_log[0]
	assert_eq(asked.kind, PlayerChoice.Kind.OPTION)
	assert_eq(asked.options, ["3", "4", "5", "6", "7", "8", "9"] as Array[String])
	assert_eq(asked.answer, 2, "the ANSWER is the index into those labels")
	assert_string_contains(asked.describe(), "5")


func test_choose_option_clamps_an_out_of_range_answer() -> void:
	var agent := _numbers(0, 99)
	var labels: Array[String] = ["a", "b", "c"]
	assert_eq(agent.choose_option(g, 0, labels, "pick", 0), 2, "clamped to the last")


func test_choose_option_with_nothing_to_choose_from_declines() -> void:
	var agent := DecisionAgent.new()
	assert_eq(agent.choose_option(g, 0, [] as Array[String], "pick", 0), -1)
	assert_eq(g.choice_log.size(), 0, "and nothing is filed")


func test_choose_number_follows_the_hint_by_default() -> void:
	var agent := DecisionAgent.new()
	assert_eq(agent.choose_number(g, 0, 0, 7, "pick", 4), 4)
	assert_eq(agent.choose_number(g, 0, 0, 7, "pick", 99), 7, "hint clamped too")


func test_an_option_question_is_not_held_open_for_a_seat_that_cannot_show_it() -> void:
	# DecisionAgent.can_answer: the duel overlay has no OPTION case yet, so
	# the pre-flight must NOT stop the duel on one. It falls through to the
	# heuristic and is ledgered, like the six sites a probe cannot reach.
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var elemental := put_battlefield(0, "Wood Elemental")
	assert_null(g.awaiting_choice, "the duel is not stuck")
	assert_eq(elemental.cur_power, 2, "the heuristic answered")
	assert_true(g.unanswered_choices.size() >= 1, "and it is on the honest ledger")


# ------------------------------------------------------------ Shapeshifter --

func test_shapeshifter_splits_seven_as_it_enters() -> void:
	var shifter := put_battlefield(0, "Shapeshifter")
	# Nothing to fear across the table: all the power it can take and live.
	assert_eq(shifter.cur_power, 6)
	assert_eq(shifter.cur_toughness, 1)


func test_shapeshifter_keeps_enough_toughness_to_survive_the_board() -> void:
	put_battlefield(1, "Hill Giant")          # 3/3
	var shifter := put_battlefield(0, "Shapeshifter")
	assert_eq(shifter.cur_power, 3)
	assert_eq(shifter.cur_toughness, 4, "outlasts a 3-power blocker")


func test_shapeshifter_takes_the_number_its_controller_names() -> void:
	_numbers(0, 2)
	var shifter := put_battlefield(0, "Shapeshifter")
	assert_eq(shifter.cur_power, 2)
	assert_eq(shifter.cur_toughness, 5)


func test_shapeshifter_may_be_a_seven_zero_and_dies_for_it() -> void:
	_numbers(0, 7)
	var shifter := put_battlefield(0, "Shapeshifter")
	assert_eq(shifter.cur_power, 7)
	assert_eq(shifter.cur_toughness, 0)
	g.check_state_based_actions()
	assert_eq(shifter.zone, Mtg.Zone.GRAVEYARD, "CR 704.5f")


func test_shapeshifter_only_sets_its_BASE_stats() -> void:
	# Duel.hlp: "It only changes its base power and toughness; any modifiers
	# to these stats (such as counters) are applied normally."
	_numbers(0, 3)
	var shifter := put_battlefield(0, "Shapeshifter")
	g.add_counters(shifter, "+1/+1", 2)
	assert_eq(shifter.cur_power, 5)
	assert_eq(shifter.cur_toughness, 6)


func test_shapeshifter_resplits_at_upkeep() -> void:
	var shifter := put_battlefield(0, "Shapeshifter")
	assert_eq(shifter.cur_power, 6)
	var agent := _numbers(0, 1)
	advance_to_next_turn()      # their turn — not ours, no re-split
	assert_eq(shifter.cur_power, 6)
	advance_to_next_turn()      # ours
	assert_eq(shifter.cur_power, 1)
	assert_eq(shifter.cur_toughness, 6)
	assert_eq(agent.want, 1)


func test_shapeshifter_may_decline_the_resplit() -> void:
	var agent := _numbers(0, 0)
	agent.say_yes = false
	var shifter := put_battlefield(0, "Shapeshifter")
	assert_eq(shifter.cur_power, 0, "the arrival choice is NOT optional")
	agent.want = 4
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(shifter.cur_power, 0, "declined, so the old split stands")


# ----------------------------------------------------------- Wood Elemental --

func test_wood_elemental_eats_every_untapped_forest() -> void:
	for i in 3:
		put_battlefield(0, "Forest")
	var elemental := put_battlefield(0, "Wood Elemental")
	assert_eq(elemental.cur_power, 3)
	assert_eq(elemental.cur_toughness, 3)
	assert_eq(g.players[0].battlefield.size(), 1, "the forest is gone")
	assert_eq(g.players[0].graveyard.size(), 3)


func test_wood_elemental_leaves_tapped_forests_alone() -> void:
	var standing := put_battlefield(0, "Forest")
	var felled := put_battlefield(0, "Forest")
	standing.tapped = true
	var elemental := put_battlefield(0, "Wood Elemental")
	assert_eq(elemental.cur_power, 1)
	assert_eq(standing.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(felled.zone, Mtg.Zone.GRAVEYARD)


func test_wood_elemental_without_a_forest_is_a_dead_zero_zero() -> void:
	var elemental := put_battlefield(0, "Wood Elemental")
	assert_eq(elemental.cur_toughness, 0)
	g.check_state_based_actions()
	assert_eq(elemental.zone, Mtg.Zone.GRAVEYARD)


func test_wood_elemental_takes_only_what_its_controller_offers() -> void:
	for i in 4:
		put_battlefield(0, "Forest")
	_numbers(0, 2)
	var elemental := put_battlefield(0, "Wood Elemental")
	assert_eq(elemental.cur_power, 2)
	assert_eq(g.players[0].graveyard.size(), 2, "two forests, not four")


# ------------------------------------------------------------ Nameless Race --

func test_nameless_race_is_as_big_as_the_white_it_hates() -> void:
	put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "Benalish Hero")
	_bury(1, "Serra Angel")
	_numbers(0, 3)
	var race := put_battlefield(0, "Nameless Race")
	assert_eq(race.cur_power, 3)
	assert_eq(race.cur_toughness, 3)
	assert_eq(g.players[0].life, 17, "and it was paid for in life")
	assert_true(race.has_keyword(Mtg.Keyword.TRAMPLE))


func test_nameless_race_cannot_be_paid_past_the_white_it_can_see() -> void:
	put_battlefield(1, "Savannah Lions")
	put_battlefield(1, "Grizzly Bears")     # green — does not count
	_numbers(0, 9)                          # asks for more than the ceiling
	var race := put_battlefield(0, "Nameless Race")
	assert_eq(race.cur_power, 1, "one white permanent, one point")
	assert_eq(g.players[0].life, 19)


func test_nameless_race_against_no_white_is_a_dead_zero_zero() -> void:
	put_battlefield(1, "Grizzly Bears")
	var race := put_battlefield(0, "Nameless Race")
	assert_eq(race.cur_toughness, 0)
	assert_eq(g.players[0].life, 20, "and no life was paid")
	g.check_state_based_actions()
	assert_eq(race.zone, Mtg.Zone.GRAVEYARD)


func test_nameless_race_cannot_pay_life_it_does_not_have() -> void:
	for i in 9:
		put_battlefield(1, "Savannah Lions")
	g.players[0].life = 4
	_numbers(0, 9)
	var race := put_battlefield(0, "Nameless Race")
	assert_eq(race.cur_power, 4, "CR 119.4 — capped at the life it has")
	assert_eq(g.players[0].life, 0)
	assert_true(g.game_over, "and paying all of it is how you lose")


# ----------------------------------------------------------------- Tetravus --

func test_tetravus_arrives_as_a_four_four() -> void:
	var tet := put_battlefield(0, "Tetravus")
	assert_eq(int(tet.counters.get("+1/+1", 0)), 3)
	assert_eq(tet.cur_power, 4)
	assert_eq(tet.cur_toughness, 4)
	assert_true(tet.has_keyword(Mtg.Keyword.FLYING))


func test_tetravus_buds_its_counters_into_tetravites() -> void:
	var tet := put_battlefield(0, "Tetravus")
	advance_to_next_turn()
	advance_to_next_turn()      # back to our upkeep
	assert_eq(int(tet.counters.get("+1/+1", 0)), 0)
	assert_eq(tet.cur_power, 1, "the Tetravus shrinks to its printed body")
	var brood: Array = []
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Tetravite":
			brood.append(inst)
	assert_eq(brood.size(), 3)
	var tetravite: CardInstance = brood[0]
	assert_eq(tetravite.cur_power, 1)
	assert_eq(tetravite.cur_toughness, 1)
	assert_true(tetravite.has_keyword(Mtg.Keyword.FLYING))
	assert_true(tetravite.is_type(Mtg.CardType.ARTIFACT))
	assert_true(tetravite.data.cant_be_aura_target, "can't be enchanted")
	assert_true(tetravite.is_token)


func test_tetravus_absorbs_a_tetravite_an_opponent_took() -> void:
	var tet := put_battlefield(0, "Tetravus")
	advance_to_next_turn()
	advance_to_next_turn()
	var stolen: CardInstance = null
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Tetravite":
			stolen = inst
			break
	assert_not_null(stolen)
	# Hand one Tetravite across the table; the heuristic absorbs strays.
	g.change_control(stolen, 1)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(stolen.zone, Mtg.Zone.EXILE, "absorbed, wherever it was")
	# ...and the same upkeep's budding trigger spends the counter it just
	# earned, so the stray comes back as a Tetravite on OUR side.
	var ours := 0
	var theirs := 0
	for inst in g.all_battlefield():
		if inst.data.card_name == "Tetravite":
			if inst.controller_id == 0:
				ours += 1
			else:
				theirs += 1
	assert_eq(ours, 3, "three Tetravites, all ours again")
	assert_eq(theirs, 0)


func test_tetravus_forgets_a_tetravite_that_died() -> void:
	var tet := put_battlefield(0, "Tetravus")
	advance_to_next_turn()
	advance_to_next_turn()
	for inst in g.players[0].battlefield.duplicate():
		if inst.data.card_name == "Tetravite":
			g.destroy(inst)
	# The observable claim: a later upkeep cannot absorb what is dead.
	_numbers(0, 3)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(int(tet.counters.get("+1/+1", 0)), 0, "nothing left to absorb")


# --------------------------------------------------------------- Power Leak --

func test_power_leak_bleeds_the_enchantments_controller() -> void:
	var moat := put_battlefield(1, "Moat")
	var leak := give_hand(0, "Power Leak")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, leak, [TargetRef.card(moat)]))
	resolve_stack()
	assert_eq(leak.attached_to, moat.id)
	advance_to_next_turn()      # their upkeep passes on the way
	assert_eq(g.players[1].life, 18)
	assert_eq(g.players[0].life, 20, "the Aura's controller pays nothing")


func test_power_leak_can_be_bought_off() -> void:
	var moat := put_battlefield(1, "Moat")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var leak := give_hand(0, "Power Leak")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, leak, [TargetRef.card(moat)]))
	resolve_stack()
	_numbers(1, 2)
	advance_to_next_turn()
	assert_eq(g.players[1].life, 20, "two mana bought off two damage")


func test_power_leak_half_payment_prevents_half() -> void:
	var moat := put_battlefield(1, "Moat")
	put_battlefield(1, "Island")
	var leak := give_hand(0, "Power Leak")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, leak, [TargetRef.card(moat)]))
	resolve_stack()
	_numbers(1, 2)              # wants 2, can only afford 1
	advance_to_next_turn()
	assert_eq(g.players[1].life, 19)


# -------------------------------------------------------------- Petra Sphinx --

func test_petra_sphinx_hits_the_named_card() -> void:
	var sphinx := put_battlefield(0, "Petra Sphinx")
	# The filler library is thirty Forests, so the only nameable name hits.
	var before := g.players[0].hand.size()
	assert_ok(g.activate_ability(0, sphinx, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before + 1)
	assert_eq(g.players[0].graveyard.size(), 0)


func test_petra_sphinx_misses_and_mills() -> void:
	var sphinx := put_battlefield(0, "Petra Sphinx")
	# Bury a Mountain under thirty Forests: "Forest" is the popular name the
	# heuristic reaches for, and the top card is not one.
	var odd := give_hand(1, "Mountain")
	g.players[1].hand.erase(odd)
	odd.zone = Mtg.Zone.LIBRARY
	g.players[1].library.append(odd)       # the TOP of the library
	assert_ok(g.activate_ability(0, sphinx, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(odd.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].graveyard.size(), 1)


func test_petra_sphinx_does_not_make_the_player_DRAW() -> void:
	# "Puts it into their hand" is not a draw (CR 121.8).
	put_battlefield(1, "Underworld Dreams")
	var sphinx := put_battlefield(0, "Petra Sphinx")
	assert_ok(g.activate_ability(0, sphinx, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "Underworld Dreams stayed quiet")
