extends GameTest
## Whole-game campaign 2026-10 (fix-cards): core-pool card fixes.
##   w1-9  Vesuvan Doppelganger's upkeep copy TARGETS (CR 603.3d): chosen
##         as the trigger goes on the stack, protection from blue keeps a
##         creature out, a target gone by resolution copies nothing.
##   w1-10 Drain Power: the drained player chooses WHICH mana ability of
##         each land ("target player activates a mana ability").
##   w1-11 Fellwar Stone reads what a land COULD produce (CR 106.7): a Gem
##         Bazaar's chosen colour, nothing from a Bazaar that would make none.
##   w1-3 / w1-12 the card side of the AI's card picks: Kudzu, Drop of
##         Honey, Juxtapose, Enchantment Alteration, Eureka and Cyclopean
##         Tomb pre-sort their candidates for the asked seat and say so
##         (PlayerChoice.ordered), so a heuristic seat takes the head of the
##         list; Kudzu's prompts say what the card says.


## Records every question it is asked and answers with the hint / the
## head of the list (what a heuristic seat that honours the card does).
class Spy extends DecisionAgent:
	var yes_no: Array = []      # [prompt, hint]
	var cards: Array = []       # [prompt, ordered, candidates]
	var options: Array = []     # [prompt, options, hint]
	var pick_option := ""       # an option label containing this is chosen
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		yes_no.append([prompt, hint])
		return hint
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		var asked := current_choice()
		cards.append([prompt, asked != null and asked.ordered, candidates.duplicate()])
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			labels: Array[String], hint: int) -> int:
		options.append([prompt, labels.duplicate(), hint])
		if pick_option != "":
			for i in labels.size():
				if labels[i].contains(pick_option): return i
		return hint


func _spy(pid: int) -> Spy:
	var spy := Spy.new()
	g.set_agent(pid, spy)
	return spy


func _wizard(pid: int) -> AiPlayer:
	var ai := AiPlayer.new(pid, AiProfile.wizard())
	g.set_agent(pid, ai)
	return ai


## Pass until [param pid]'s upkeep of a later turn has its trigger stacked.
func _to_upkeep_trigger(pid: int) -> void:
	var guard := 0
	while not g.game_over and guard < 600 and not (g.active_player == pid
			and g.turn_number > 1 and g.current_step() == Mtg.Step.UPKEEP
			and not g.stack.is_empty()):
		_advance_once()
		guard += 1
	assert_lt(guard, 600, "never reached the upkeep trigger")


# --------------------------------------------------- Vesuvan Doppelganger --

func test_vesuvan_upkeep_copy_cannot_target_a_creature_with_protection_from_blue() -> void:
	put_battlefield(0, "Grizzly Bears")
	var dopp := put_battlefield(0, "Vesuvan Doppelganger")   # enters as the Bears
	assert_eq(dopp.data.card_name, "Grizzly Bears", "precondition")
	var angel := put_battlefield(1, "Serra Angel")
	var ward := _make_instance(1, "Blue Ward")
	g.attach_aura_from_anywhere(ward, angel, 1)
	assert_ne(angel.cur_protection & Mtg.ManaColor.U, 0, "precondition: protection from blue")
	_to_upkeep_trigger(0)
	var item: StackItem = g.stack.back()
	assert_eq(item.card, dopp, "the Doppelganger's upkeep trigger")
	for ref in item.targets:
		assert_ne(ref.instance_id, angel.id, "a pro-blue creature is no legal target")
		assert_ne(ref.instance_id, dopp.id, "nor the Doppelganger itself")
	resolve_stack()
	assert_ne(dopp.data.card_name, "Serra Angel")


func test_vesuvan_upkeep_target_is_chosen_on_the_stack_and_a_gone_target_copies_nothing() -> void:
	put_battlefield(0, "Grizzly Bears")
	var dopp := put_battlefield(0, "Vesuvan Doppelganger")
	assert_eq(dopp.data.card_name, "Grizzly Bears", "precondition")
	var giant := put_battlefield(1, "Hill Giant")
	_to_upkeep_trigger(0)
	var item: StackItem = g.stack.back()
	assert_eq(item.card, dopp)
	assert_eq(item.targets.size(), 1, "one target, named as the trigger goes on the stack")
	if item.targets.size() == 1:
		assert_eq(item.targets[0].instance_id, giant.id, "the biggest other creature is the hint")
	g.return_to_hand(giant)   # setup: the target leaves in response
	resolve_stack()
	assert_eq(dopp.data.card_name, "Grizzly Bears", "a target gone by resolution: no copy")


func test_vesuvan_upkeep_copy_still_takes_its_target() -> void:
	put_battlefield(0, "Grizzly Bears")
	var dopp := put_battlefield(0, "Vesuvan Doppelganger")
	put_battlefield(1, "Hill Giant")
	_to_upkeep_trigger(0)
	resolve_stack()
	assert_eq(dopp.data.card_name, "Hill Giant", "yes is the hint for a bigger body")
	assert_true(dopp.has_color(Mtg.ManaColor.U), "still blue")
	assert_false(dopp.data.triggered_abilities.is_empty(), "and it keeps the ability")


# ------------------------------------------------------------ Drain Power --

func test_drain_power_lets_the_drained_player_choose_each_lands_mana_ability() -> void:
	var spy := _spy(1)
	spy.pick_option = "Blue"
	put_battlefield(1, "City of Brass")
	put_battlefield(1, "Forest")
	var drain := give_hand(0, "Drain Power")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(spy.options.size(), 1, "the City asks; a Forest has one ability and is not asked")
	if spy.options.size() == 1:
		assert_string_contains(String(spy.options[0][0]), "Drain Power")
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.U), 1, "the colour the drained player chose")
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.W), 0)
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 1, "and the Forest's green")
	assert_eq(g.players[1].mana_pool.total(), 0)


func test_drain_power_skips_a_tapped_land_without_asking() -> void:
	var spy := _spy(1)
	put_battlefield(1, "City of Brass").tapped = true
	put_battlefield(1, "Forest")
	var drain := give_hand(0, "Drain Power")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(spy.options.size(), 0, "a tapped City has no ability it could activate")
	assert_eq(g.players[0].mana_pool.total(), 1, "the Forest's mana only")


# ----------------------------------------------------------- Fellwar Stone --

func test_fellwar_stone_reads_gem_bazaars_chosen_colour() -> void:
	var stone := put_battlefield(0, "Fellwar Stone")
	var bazaar := put_battlefield(1, "Gem Bazaar")
	bazaar.memory["color"] = Mtg.ManaColor.G
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, stone))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.W), 0, "not the Bazaar's placeholder white")
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.G), 1)


func test_fellwar_stone_finds_nothing_in_a_bazaar_that_would_make_no_mana() -> void:
	var stone := put_battlefield(0, "Fellwar Stone")
	var bazaar := put_battlefield(1, "Gem Bazaar")
	advance_to_step(Mtg.Step.MAIN1)
	bazaar.memory.erase("color")
	g.tap_for_mana(0, stone)
	assert_eq(g.players[0].mana_pool.total(), 0, "a Bazaar with no colour chosen could produce none")


# ------------------------------------------------------------------ Kudzu --

func test_kudzu_ai_victim_hands_the_vine_to_the_kudzu_players_land() -> void:
	_wizard(1)
	var host := put_battlefield(1, "Forest")
	put_battlefield(1, "Bayou")          # the AI's valuable dual
	put_battlefield(1, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var kudzu := _make_instance(0, "Kudzu")
	g.attach_aura_from_anywhere(kudzu, host, 0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(1, host))
	resolve_stack()
	assert_eq(host.zone, Mtg.Zone.GRAVEYARD)
	var new_host := g.find_instance(kudzu.attached_to)
	assert_not_null(new_host)
	if new_host != null:
		assert_eq(new_host.controller_id, 0, "the vine goes back to the Kudzu player's land")


func test_kudzu_hop_asks_in_the_cards_words_and_ranks_for_the_victim() -> void:
	var spy := _spy(1)
	var host := put_battlefield(1, "Forest")
	var own := put_battlefield(1, "Forest")
	var theirs := put_battlefield(0, "Forest")
	var kudzu := _make_instance(0, "Kudzu")
	g.attach_aura_from_anywhere(kudzu, host, 0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(1, host))
	resolve_stack()
	assert_eq(spy.yes_no.size(), 1)
	if spy.yes_no.size() == 1:
		assert_false(String(spy.yes_no[0][0]).contains("your lands"), "prompt: %s" % spy.yes_no[0][0])
		assert_true(bool(spy.yes_no[0][1]), "an opponent's land to hand it to: the hint is yes")
	assert_eq(spy.cards.size(), 1)
	if spy.cards.size() == 1:
		assert_true(bool(spy.cards[0][1]), "an ORDERED ask")
		var offered: Array = spy.cards[0][2]
		assert_eq(offered[0], theirs, "the Kudzu player's land first")
		assert_eq(offered[-1], own, "the victim's own land last")
	assert_eq(kudzu.attached_to, theirs.id)


func test_kudzu_with_only_own_lands_left_hints_letting_the_vine_die() -> void:
	var spy := _spy(1)
	var host := put_battlefield(1, "Forest")
	var own := put_battlefield(1, "Forest")
	var kudzu := _make_instance(0, "Kudzu")
	g.attach_aura_from_anywhere(kudzu, host, 0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(1, host))
	resolve_stack()
	assert_eq(spy.yes_no.size(), 1)
	if spy.yes_no.size() == 1:
		assert_false(bool(spy.yes_no[0][1]), "moving it onto one's own land is never the hint")
	assert_eq(own.zone, Mtg.Zone.BATTLEFIELD)
	assert_ne(kudzu.attached_to, own.id)
	assert_eq(kudzu.zone, Mtg.Zone.GRAVEYARD, "the vine died with its land")


# ---------------------------------------------------------- Drop of Honey --

func test_drop_of_honey_ai_destroys_the_opponents_tied_creature() -> void:
	_wizard(1)
	put_battlefield(1, "Drop of Honey")
	var wall := put_battlefield(1, "Wall of Stone")          # 0/8, the AI's
	var thopter := put_battlefield(0, "Ornithopter")         # 0/2, the opponent's
	put_battlefield(1, "Craw Wurm")
	_to_upkeep_trigger(1)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "its own Wall is not fed to its Drop")
	assert_eq(thopter.zone, Mtg.Zone.GRAVEYARD)


func test_drop_of_honey_tie_ask_is_ordered_enemy_first() -> void:
	var spy := _spy(0)
	put_battlefield(0, "Drop of Honey")
	var mine := put_battlefield(0, "Ornithopter")
	var theirs := put_battlefield(1, "Ornithopter")
	_to_upkeep_trigger(0)
	resolve_stack()
	assert_eq(spy.cards.size(), 1)
	if spy.cards.size() == 1:
		assert_true(bool(spy.cards[0][1]), "an ORDERED ask")
		assert_eq(spy.cards[0][2][0], theirs)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------------- Juxtapose --

func test_juxtapose_ai_gives_away_its_lesser_tied_creature() -> void:
	_wizard(1)
	var angel := put_battlefield(1, "Serra Angel")        # MV 5, 4/4 flier
	var earth := put_battlefield(1, "Earth Elemental")    # MV 5, 4/5 vanilla
	var mine := put_battlefield(0, "Grizzly Bears")
	var jux := give_hand(0, "Juxtapose")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, jux, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(mine.controller_id, 1)
	assert_eq(angel.controller_id, 1, "the AI keeps its Serra Angel")
	assert_eq(earth.controller_id, 0, "and hands over the vanilla 4/5")


# -------------------------------------------------- Enchantment Alteration --

func test_enchantment_alteration_steals_a_helpful_aura_onto_our_biggest() -> void:
	var spy := _spy(0)
	var giant := put_battlefield(1, "Hill Giant")
	var strength := _make_instance(1, "Holy Strength")
	g.attach_aura_from_anywhere(strength, giant, 1)
	put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(0, "Craw Wurm")
	var alter := give_hand(0, "Enchantment Alteration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, alter, [TargetRef.card(strength)]))
	resolve_stack()
	assert_eq(spy.cards.size(), 1)
	if spy.cards.size() == 1:
		assert_true(bool(spy.cards[0][1]), "an ORDERED ask")
	assert_eq(strength.attached_to, wurm.id)


func test_enchantment_alteration_frees_our_creature_from_their_control_magic() -> void:
	_spy(0)
	var wurm := put_battlefield(0, "Craw Wurm")
	var magic := _make_instance(1, "Control Magic")
	g.attach_aura_from_anywhere(magic, wurm, 1)
	g.recalculate()
	assert_eq(wurm.controller_id, 1, "precondition: stolen")
	var giant := put_battlefield(1, "Hill Giant")
	put_battlefield(0, "Grizzly Bears")
	var alter := give_hand(0, "Enchantment Alteration")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, alter, [TargetRef.card(magic)]))
	resolve_stack()
	assert_eq(magic.attached_to, giant.id, "onto a creature they already own")
	assert_eq(wurm.controller_id, 0, "our Wurm comes home")
	assert_eq(giant.controller_id, 1)


# ----------------------------------------------------------------- Eureka --

func test_eureka_aura_host_ask_is_ordered() -> void:
	var spy := _spy(0)
	_spy(1)
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Craw Wurm")
	var strength := give_hand(0, "Holy Strength")
	var eureka := give_hand(0, "Eureka")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, eureka, []))
	resolve_stack()
	var host_asks: Array = spy.cards.filter(func(row: Array) -> bool:
		return String(row[0]).contains("enchants"))
	assert_eq(host_asks.size(), 1)
	if host_asks.size() == 1:
		assert_true(bool(host_asks[0][1]), "an ORDERED ask")
	assert_eq(strength.attached_to, bear.id, "a helpful Aura on our own creature")


# --------------------------------------------------------- Cyclopean Tomb --

func test_cyclopean_tomb_reversion_ask_is_ordered_own_land_first() -> void:
	var spy := _spy(0)
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var island := put_battlefield(1, "Island")
	var forest := put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tomb, 0, [TargetRef.card(island)]))
	resolve_stack()
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 0, "precondition: our next upkeep")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tomb, 0, [TargetRef.card(forest)]))
	resolve_stack()
	assert_eq(int(forest.counters.get("mire", 0)), 1, "precondition: our Forest mired too")
	g.destroy(tomb)
	resolve_stack()
	spy.cards.clear()
	_to_upkeep_trigger(0)
	resolve_stack()
	var asks: Array = spy.cards.filter(func(row: Array) -> bool:
		return String(row[0]).contains("revert"))
	assert_eq(asks.size(), 1)
	if asks.size() == 1:
		assert_true(bool(asks[0][1]), "an ORDERED ask")
		assert_eq(asks[0][2][0], forest, "our own land first")
	assert_eq(int(forest.counters.get("mire", 0)), 0, "our Forest is freed first")
	assert_eq(int(island.counters.get("mire", 0)), 1)


# ---------------------------- the bonus-mana descriptors (wave 2, fix-mana) --
#
# Mana Flare, Wild Growth and Gauntlet of Might DESCRIBE their bonus
# (TriggeredAbility.mana_bonus_*), so ManaPlanner plans with it rather than
# only stopping once the pool covers the bill: a land under a bonus is one
# row that makes more (w1-1).

## The amount of [param color] the planner's row for [param inst] makes.
func _planned_amount(inst: CardInstance, color: int) -> int:
	for s in ManaPlanner.sources(g, 0):
		if s[0] == inst and int(s[2]) == color:
			return int(s[3])
	return -1


func test_mana_flare_describes_one_more_mana_of_the_type_each_land_made() -> void:
	put_battlefield(1, "Mana Flare")      # anyone's Flare: "whenever a player taps a land"
	var mountains: Array = []
	for _i in 4:
		mountains.append(put_battlefield(0, "Mountain"))
	assert_eq(_planned_amount(mountains[0], Mtg.ManaColor.R), 2)
	assert_eq(ManaPlanner.plan(g, 0, CardRegistry.get_card("Hill Giant").cost, 0).size(), 2,
		"two Mountains pay {3}{R} under a Flare")
	assert_eq(ManaPlanner.max_affordable_x(g, 0, CardRegistry.get_card("Fireball").cost), 7,
		"eight red from four Mountains: X = 7")


func test_mana_flare_lets_three_forests_pay_force_of_nature_with_nothing_left() -> void:
	put_battlefield(0, "Mana Flare")
	for _i in 3:
		put_battlefield(0, "Forest")
	var force := CardRegistry.get_card("Force of Nature").cost   # {2}{G}{G}{G}{G}
	assert_false(ManaPlanner.plan(g, 0, force, 0).is_empty(), "six green from three Forests")
	assert_true(g.try_pay(0, force))
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing floats to burn")


func test_wild_growth_describes_its_enchanted_land_only() -> void:
	var host := put_battlefield(0, "Forest")
	var other := put_battlefield(0, "Forest")
	var aura := _make_instance(0, "Wild Growth")
	g.attach_aura_from_anywhere(aura, host, 0)
	assert_eq(_planned_amount(host, Mtg.ManaColor.G), 2)
	assert_eq(_planned_amount(other, Mtg.ManaColor.G), 1)
	assert_eq(ManaPlanner.plan(g, 0, ManaCost.parse("{1}{G}"), 0), [[host, 0]],
		"one tap of the enchanted Forest pays {1}{G}")
	assert_eq(ManaPlanner.plan(g, 0, ManaCost.parse("{G}"), 0), [[other, 0]],
		"a plain Forest for {G}: the bonus would float")


func test_gauntlet_of_might_describes_mountains_only() -> void:
	put_battlefield(1, "Gauntlet of Might")   # "whenever a Mountain is tapped" — anyone's
	var mountain := put_battlefield(0, "Mountain")
	var forest := put_battlefield(0, "Forest")
	assert_eq(_planned_amount(mountain, Mtg.ManaColor.R), 2)
	assert_eq(_planned_amount(forest, Mtg.ManaColor.G), 1)
	assert_eq(ManaPlanner.plan(g, 0, ManaCost.parse("{1}{R}"), 0), [[mountain, 0]])
