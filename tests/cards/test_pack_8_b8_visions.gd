extends GameTest
## Pack 8 (the Mirage block), batch B8: the Visions cost cards of
## cards/sets/vis/_costs.gd — return-to-hand costs (of the card itself and
## of lands), X object costs, "sacrifice all and discard your hand", the
## alternative cost, and the cumulative upkeeps.

const CLAIMED := ["Gossamer Chains", "Flooded Shoreline", "Ovinomancer", "Infernal Harvest",
	"Kaervek's Spite", "Wicked Reward", "Fireblast", "Quirion Ranger", "Corrosion",
	"Firestorm Hellkite"]


class Scripted extends DecisionAgent:
	var answers: Array = []   # bool
	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _own_upkeep() -> void:
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)

## P1 attacks P0 with [param attacker]; P0 blocks with [param blocker] (or
## not); P0 then holds priority in the declare-blockers step.
func _p1_attacks(attacker: CardInstance, blocker: CardInstance = null) -> void:
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {} if blocker == null else {blocker.id: attacker.id}))
	resolve_stack()
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func test_claimed_cards_are_no_longer_pending() -> void:
	for name in CLAIMED:
		var c := CardRegistry.get_card(name)
		assert_not_null(c, name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", name)


# --- Gossamer Chains ----------------------------------------------------------

func test_chains_returns_itself_and_prevents_an_unblocked_attackers_damage() -> void:
	var chains := put_battlefield(0, "Gossamer Chains")
	var giant := put_battlefield(1, "Hill Giant")
	_p1_attacks(giant)
	assert_ok(g.activate_ability(0, chains, 0, [TargetRef.card(giant)]))
	assert_eq(chains.zone, Mtg.Zone.HAND, "returning the enchantment is the cost")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)

func test_chains_refuses_a_blocked_creature() -> void:
	var chains := put_battlefield(0, "Gossamer Chains")
	var giant := put_battlefield(1, "Hill Giant")
	var wall := put_battlefield(0, "Wall of Stone")
	_p1_attacks(giant, wall)
	assert_refused(g.activate_ability(0, chains, 0, [TargetRef.card(giant)]))
	assert_eq(chains.zone, Mtg.Zone.BATTLEFIELD)

func test_chains_refuses_before_blockers_are_declared() -> void:
	var chains := put_battlefield(0, "Gossamer Chains")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	resolve_stack()
	assert_ok(g.pass_priority(1))
	assert_refused(g.activate_ability(0, chains, 0, [TargetRef.card(giant)]))


# --- Flooded Shoreline --------------------------------------------------------

func test_shoreline_returns_two_islands_and_bounces_a_creature() -> void:
	var shore := put_battlefield(0, "Flooded Shoreline")
	var i1 := put_battlefield(0, "Island")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.activate_ability(0, shore, 0, [TargetRef.card(bear)]))
	assert_eq(i1.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2, "a refused cost pays nothing")
	var i2 := put_battlefield(0, "Island")
	assert_ok(g.activate_ability(0, shore, 0, [TargetRef.card(bear)]))
	assert_eq(i1.zone, Mtg.Zone.HAND)
	assert_eq(i2.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)

func test_shoreline_cost_is_undone_by_the_journal() -> void:
	var shore := put_battlefield(0, "Flooded Shoreline")
	var i1 := put_battlefield(0, "Island")
	var i2 := put_battlefield(0, "Island")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.U, 2)
	var mark := g.make_mark()
	assert_ok(g.activate_ability(0, shore, 0, [TargetRef.card(bear)]))
	g.unmake_to(mark)
	g.end_search()
	assert_eq(i1.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(i2.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.players[0].hand.has(i1))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2)
	assert_true(g.stack.is_empty())


# --- Ovinomancer --------------------------------------------------------------

func test_ovinomancer_stays_when_three_basic_lands_return() -> void:
	var lands: Array = []
	for i in 3: lands.append(put_battlefield(0, "Island"))
	var seat := Scripted.new()
	seat.answers = [true]   # the default keeps its three lands (it has only three)
	g.agents[0] = seat
	var wizard := give_hand(0, "Ovinomancer")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, wizard, []))
	resolve_stack()
	assert_eq(wizard.zone, Mtg.Zone.BATTLEFIELD)
	for land in lands: assert_eq(land.zone, Mtg.Zone.HAND)

func test_ovinomancer_is_sacrificed_without_three_basic_lands_or_when_declined() -> void:
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	var wizard := give_hand(0, "Ovinomancer")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, wizard, []))
	resolve_stack()
	assert_eq(wizard.zone, Mtg.Zone.GRAVEYARD, "two lands cannot pay for three")
	# Declined with the lands in hand: sacrificed, the lands stay.
	var third := put_battlefield(0, "Island")
	var seat := Scripted.new()
	seat.answers = [false]
	g.agents[0] = seat
	var again := give_hand(0, "Ovinomancer")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, again, []))
	resolve_stack()
	assert_eq(again.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(third.zone, Mtg.Zone.BATTLEFIELD)

func test_ovinomancer_sheeps_a_creature_and_returns_to_hand() -> void:
	var wizard := put_battlefield(0, "Ovinomancer")
	var troll := put_battlefield(1, "Uthden Troll")
	troll.regeneration_shields = 1
	assert_ok(g.activate_ability(0, wizard, 0, [TargetRef.card(troll)]))
	assert_eq(wizard.zone, Mtg.Zone.HAND, "{T}, return this creature: the cost")
	resolve_stack()
	assert_eq(troll.zone, Mtg.Zone.GRAVEYARD, "it can't be regenerated")
	var sheep: CardInstance = null
	for i in g.players[1].battlefield:
		if i.data.card_name == "Sheep": sheep = i
	assert_not_null(sheep, "the creature's controller gets the Sheep")
	assert_eq(sheep.cur_power, 0)
	assert_eq(sheep.cur_toughness, 1)
	assert_true(sheep.has_color(Mtg.ManaColor.G))

func test_ovinomancer_tap_cost_obeys_summoning_sickness() -> void:
	var wizard := put_battlefield(0, "Ovinomancer", true)
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, wizard, 0, [TargetRef.card(bear)]))
	assert_eq(wizard.zone, Mtg.Zone.BATTLEFIELD)


# --- Infernal Harvest ---------------------------------------------------------

func test_harvest_returns_x_swamps_and_divides_x_damage() -> void:
	var s1 := put_battlefield(0, "Swamp")
	var s2 := put_battlefield(0, "Swamp")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	var harvest := give_hand(0, "Infernal Harvest")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, harvest, [TargetRef.card(a)], 3), "")
	assert_eq(s1.zone, Mtg.Zone.BATTLEFIELD, "X = 3 with two Swamps: refused, nothing moves")
	assert_eq(harvest.zone, Mtg.Zone.HAND)
	assert_ok(g.cast_spell(0, harvest, [TargetRef.card(a, 1), TargetRef.card(b, 1)], 2))
	assert_eq(s1.zone, Mtg.Zone.HAND)
	assert_eq(s2.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq(a.damage, 1)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)

func test_harvest_with_x_zero_returns_nothing_and_needs_no_target() -> void:
	var swamp := put_battlefield(0, "Swamp")
	var harvest := give_hand(0, "Infernal Harvest")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, harvest, [], 0))
	resolve_stack()
	assert_eq(swamp.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(harvest.zone, Mtg.Zone.GRAVEYARD)


# --- Kaervek's Spite ----------------------------------------------------------

func test_spite_sacrifices_everything_discards_the_hand_and_drains_five() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var swamp := put_battlefield(0, "Swamp")
	var kept := give_hand(0, "Lightning Bolt")
	var their := put_battlefield(1, "Hill Giant")
	var spite := give_hand(0, "Kaervek's Spite")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, spite, [TargetRef.player(1)]))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(kept.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].battlefield.is_empty())
	assert_eq(their.zone, Mtg.Zone.BATTLEFIELD, "only YOUR permanents")
	resolve_stack()
	assert_eq(g.players[1].life, 15)

func test_spite_with_nothing_to_give_still_casts() -> void:
	var spite := give_hand(0, "Kaervek's Spite")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.cast_spell(0, spite, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 15)


# --- Wicked Reward ------------------------------------------------------------

func test_wicked_reward_sacrifices_a_creature_for_plus_four_plus_two() -> void:
	var fodder := put_battlefield(0, "Llanowar Elves")
	var bear := put_battlefield(0, "Grizzly Bears")
	var reward := give_hand(0, "Wicked Reward")
	add_mana(0, Mtg.ManaColor.B, 2)
	var seat := HumanAgent.new()
	g.agents[0] = seat
	g.interactive_choices = true
	assert_ok(g.cast_spell(0, reward, [TargetRef.card(bear)]))
	assert_not_null(g.awaiting_choice, "the payer chooses the creature")
	assert_eq(fodder.zone, Mtg.Zone.BATTLEFIELD)
	assert_ok(g.answer_choice(fodder.id))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	g.interactive_choices = false
	g.agents[0] = DecisionAgent.new()
	resolve_stack()
	assert_eq(bear.cur_power, 6)
	assert_eq(bear.cur_toughness, 4)

func test_wicked_reward_refused_without_a_creature_to_sacrifice() -> void:
	var reward := give_hand(0, "Wicked Reward")
	var their := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, reward, [TargetRef.card(their)]))
	assert_eq(reward.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 2)


# --- Fireblast ------------------------------------------------------------------

func test_fireblast_sacrifices_two_mountains_instead_of_its_mana_cost() -> void:
	var blast := give_hand(0, "Fireblast")
	assert_eq(blast.data.cost.mana_value(), 6, "CR 118.9: the mana value is unchanged")
	var m1 := put_battlefield(0, "Mountain")
	assert_refused(g.cast_spell(0, blast, [TargetRef.player(1)], 0, 1))
	assert_eq(m1.zone, Mtg.Zone.BATTLEFIELD)
	var m2 := put_battlefield(0, "Mountain")
	assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)], 0, 1))
	assert_eq(m1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(m2.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 16)

func test_fireblast_printed_row_pays_mana_and_keeps_the_mountains() -> void:
	var blast := give_hand(0, "Fireblast")
	var m1 := put_battlefield(0, "Mountain")
	var m2 := put_battlefield(0, "Mountain")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.R, 6)
	assert_ok(g.cast_spell(0, blast, [TargetRef.card(bear)], 0, 0))
	assert_eq(m1.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(m2.zone, Mtg.Zone.BATTLEFIELD)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_fireblast_ai_row_mana_when_payable_mountains_when_short_and_it_matters() -> void:
	var data := CardRegistry.get_card("Fireblast")
	assert_true(data.ai_mode_picker.is_valid())
	for i in 2: put_battlefield(0, "Mountain")
	# Short of mana, nothing worth 4 damage: keep the lands.
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 0)
	# The opponent is in range: the Mountains go.
	g.players[1].life = 4
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 1)
	# A real threat dies to it.
	g.players[1].life = 20
	put_battlefield(1, "Hill Giant")
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 1)
	# With {4}{R}{R} payable the printed cost is used.
	for i in 4: put_battlefield(0, "Mountain")
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 0)


# --- Quirion Ranger -------------------------------------------------------------

func test_ranger_returns_a_forest_to_untap_a_creature_once_a_turn() -> void:
	var ranger := put_battlefield(0, "Quirion Ranger")
	var forest := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	bear.tapped = true
	assert_ok(g.tap_for_mana(0, forest))
	assert_ok(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]))
	assert_eq(forest.zone, Mtg.Zone.HAND, "a tapped Forest still pays")
	resolve_stack()
	assert_false(bear.tapped)
	put_battlefield(0, "Forest")
	bear.tapped = true
	assert_refused(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]), "once")

func test_ranger_refuses_without_a_forest_of_your_own() -> void:
	var ranger := put_battlefield(0, "Quirion Ranger")
	put_battlefield(1, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, ranger, 0, [TargetRef.card(bear)]))


# --- Corrosion ------------------------------------------------------------------

func test_corrosion_rusts_and_destroys_artifacts_and_its_departure_clears_rust() -> void:
	var corrosion := put_battlefield(0, "Corrosion")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var ring := put_battlefield(1, "Sol Ring")
	var orb := put_battlefield(1, "Winter Orb")
	var thopter := put_battlefield(0, "Ornithopter")
	_own_upkeep()
	resolve_stack()
	assert_eq(int(corrosion.counters.get("age", 0)), 1)
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD, "mana value 1 <= 1 rust counter")
	assert_eq(orb.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(orb.counters.get("rust", 0)), 1)
	assert_eq(thopter.zone, Mtg.Zone.GRAVEYARD, "EACH artifact: a mana value 0 one of yours too")
	# It leaves: every rust counter goes.
	g.destroy(corrosion)
	resolve_stack()
	assert_eq(int(orb.counters.get("rust", 0)), 0)


# --- Firestorm Hellkite ---------------------------------------------------------

func test_hellkite_cumulative_upkeep_is_u_r_per_age_counter() -> void:
	var kite := put_battlefield(0, "Firestorm Hellkite")
	assert_true(kite.has_keyword(Mtg.Keyword.FLYING))
	assert_true(kite.has_keyword(Mtg.Keyword.TRAMPLE))
	put_battlefield(0, "Island")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Island")
	_own_upkeep()
	resolve_stack()
	assert_eq(kite.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(kite.counters.get("age", 0)), 1)
	# Age 2 wants {U}{R}{U}{R}: two Islands and one Mountain cannot.
	_own_upkeep()
	resolve_stack()
	assert_eq(kite.zone, Mtg.Zone.GRAVEYARD)
