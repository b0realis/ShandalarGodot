extends GameTest
## Pack 8 (the Mirage block), batch B8: the Weatherlight cost cards of
## cards/sets/wth/_costs.gd — graveyard exile costs (positional and chosen),
## X object costs, the alternative cost, cost taxes, and the cumulative
## upkeeps: mana, life, "draw a card", "-1/-1 counter", the "wasn't paid"
## trigger, age counters that accumulate and a payment that is all or none.

const CLAIMED := ["Alms", "Aura of Silence", "Inner Sanctum", "Revered Unicorn",
	"Volunteer Reserves", "Abjure", "Ancestral Knowledge", "Psychic Vortex", "Gallowbraid",
	"Haunting Misery", "Morinfen", "Necratog", "Spinning Darkness", "Tendrils of Despair",
	"Wave of Terror", "Zombie Scavengers", "Firestorm", "Heart of Bogardan", "Aboroth",
	"Arctic Wolves", "Mwonvuli Ooze", "Uktabi Efreet"]


class Scripted extends DecisionAgent:
	var answers: Array = []   # bool
	var picks: Array = []     # CardInstance
	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint
	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		if not picks.is_empty():
			var want: Variant = picks.pop_front()
			for c in candidates:
				if c == want: return c
		return null if candidates.is_empty() else candidates[0]


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

func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst

func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst


func test_claimed_cards_are_no_longer_pending() -> void:
	for name in CLAIMED:
		var c := CardRegistry.get_card(name)
		assert_not_null(c, name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", name)


# --- Alms -------------------------------------------------------------------------

func test_alms_exiles_the_top_graveyard_card_to_prevent_one_damage() -> void:
	var alms := put_battlefield(0, "Alms")
	var giant := put_battlefield(0, "Hill Giant")
	var under := _in_graveyard(0, "Grizzly Bears")
	var top := _in_graveyard(0, "Dark Ritual")
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, alms, 0, [TargetRef.card(giant)]))
	assert_null(g.awaiting_choice, "the top card is positional: nobody is asked")
	assert_eq(top.zone, Mtg.Zone.EXILE)
	assert_eq(under.zone, Mtg.Zone.GRAVEYARD)
	g.interactive_choices = false
	g.agents[0] = DecisionAgent.new()
	resolve_stack()
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "3 damage less the 1 prevented")
	assert_eq(giant.damage, 2)

func test_alms_refused_with_an_empty_graveyard() -> void:
	var alms := put_battlefield(0, "Alms")
	var giant := put_battlefield(0, "Hill Giant")
	_in_graveyard(1, "Grizzly Bears")   # not YOUR graveyard
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, alms, 0, [TargetRef.card(giant)]))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 1)


# --- Aura of Silence ----------------------------------------------------------------

func test_aura_of_silence_taxes_opponents_artifacts_and_enchantments_only() -> void:
	put_battlefield(0, "Aura of Silence")
	assert_eq(g.spell_surcharge(1, CardRegistry.get_card("Sol Ring")), 2)
	assert_eq(g.spell_surcharge(1, CardRegistry.get_card("Holy Strength")), 2)
	assert_eq(g.spell_surcharge(1, CardRegistry.get_card("Grizzly Bears")), 0)
	assert_eq(g.spell_surcharge(0, CardRegistry.get_card("Sol Ring")), 0, "your own are not taxed")

func test_aura_of_silence_sacrifices_to_destroy_an_artifact_or_enchantment() -> void:
	var aura := put_battlefield(0, "Aura of Silence")
	var orb := put_battlefield(1, "Winter Orb")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(g.activate_ability(0, aura, 0, [TargetRef.card(bear)]))
	assert_ok(g.activate_ability(0, aura, 0, [TargetRef.card(orb)]))
	assert_eq(aura.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(orb.zone, Mtg.Zone.GRAVEYARD)


# --- Inner Sanctum ----------------------------------------------------------------

func test_inner_sanctum_prevents_damage_to_your_creatures_and_costs_life_per_age() -> void:
	var sanctum := put_battlefield(0, "Inner Sanctum")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.damage, 0)
	var bolt2 := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt2, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "only creatures YOU control")
	_own_upkeep()
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	_own_upkeep()
	resolve_stack()
	assert_eq(int(sanctum.counters.get("age", 0)), 2)
	assert_eq(g.players[0].life, 14, "2 life per age counter: 4 more")

func test_inner_sanctum_unaffordable_life_upkeep_pays_nothing() -> void:
	var sanctum := put_battlefield(0, "Inner Sanctum")
	g.players[0].life = 1
	_own_upkeep()
	resolve_stack()
	assert_eq(sanctum.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 1)


# --- Revered Unicorn ----------------------------------------------------------------

func test_unicorn_gains_its_age_counters_in_life_when_it_leaves() -> void:
	var unicorn := put_battlefield(0, "Revered Unicorn")
	put_battlefield(0, "Plains")
	_own_upkeep()
	resolve_stack()
	assert_eq(int(unicorn.counters.get("age", 0)), 1)
	_own_upkeep()   # {2} for two age counters, one Plains: sacrificed
	resolve_stack()
	assert_eq(unicorn.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 22, "two age counters")


# --- Volunteer Reserves -----------------------------------------------------------

func test_volunteer_reserves_band_and_pay_one_per_age() -> void:
	var reserves := put_battlefield(0, "Volunteer Reserves")
	assert_true(reserves.has_keyword(Mtg.Keyword.BANDING))
	var plains := put_battlefield(0, "Plains")
	_own_upkeep()
	resolve_stack()
	assert_eq(reserves.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(plains.tapped)


# --- Abjure ---------------------------------------------------------------------------

func test_abjure_sacrifices_a_blue_permanent_to_counter_a_spell() -> void:
	advance_to_next_turn()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	var abjure := give_hand(0, "Abjure")
	var island := put_battlefield(0, "Island")   # colorless: not blue
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, abjure, [TargetRef.card(bolt)]))
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	var merfolk := put_battlefield(0, "Merfolk of the Pearl Trident")
	assert_ok(g.cast_spell(0, abjure, [TargetRef.card(bolt)]))
	assert_eq(merfolk.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


# --- Ancestral Knowledge ----------------------------------------------------------

func test_ancestral_knowledge_exiles_what_you_choose_from_the_top_ten() -> void:
	var a := _on_library_top(0, "Grizzly Bears")
	var b := _on_library_top(0, "Lightning Bolt")
	var c := _on_library_top(0, "Dark Ritual")   # the top card
	var seat := Scripted.new()
	seat.answers = [true, false, true]   # top first: Ritual, Bolt, Bears
	for i in 7: seat.answers.append(false)
	g.agents[0] = seat
	var knowledge := put_battlefield(0, "Ancestral Knowledge")
	resolve_stack()
	assert_eq(c.zone, Mtg.Zone.EXILE)
	assert_eq(a.zone, Mtg.Zone.EXILE)
	assert_eq(b.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), b, "the kept card is back on top")
	# When it leaves, the library is shuffled.
	var before: Array = g.players[0].library.duplicate()
	for i in 4: _on_library_top(0, "Island")
	before = g.players[0].library.duplicate()
	g.destroy(knowledge)
	resolve_stack()
	assert_ne(g.players[0].library, before, "shuffled")
	assert_eq(g.players[0].library.size(), before.size())

func test_ancestral_knowledge_puts_the_rest_back_in_the_chosen_order() -> void:
	var a := _on_library_top(0, "Grizzly Bears")
	var b := _on_library_top(0, "Lightning Bolt")   # top
	var seat := Scripted.new()
	for i in 10: seat.answers.append(false)
	# Order: the first chosen ends on top — choose the Bears first.
	seat.picks = [a]
	g.agents[0] = seat
	put_battlefield(0, "Ancestral Knowledge")
	resolve_stack()
	assert_eq(g.players[0].library.back(), a)
	assert_eq(g.players[0].library[g.players[0].library.size() - 2], b)


# --- Psychic Vortex ---------------------------------------------------------------

func test_vortex_upkeep_draws_and_its_end_step_takes_a_land_and_the_hand() -> void:
	var vortex := put_battlefield(0, "Psychic Vortex")
	var land := put_battlefield(0, "Island")
	_own_upkeep()
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(int(vortex.counters.get("age", 0)), 1)
	assert_eq(g.players[0].hand.size(), hand + 1, "draw a card per age counter")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].hand.is_empty())

func test_vortex_declined_is_sacrificed() -> void:
	var vortex := put_battlefield(0, "Psychic Vortex")
	var seat := Scripted.new()
	seat.answers = [false]
	g.agents[0] = seat
	_own_upkeep()
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(vortex.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand)


# --- Gallowbraid / Morinfen -----------------------------------------------------------

func test_gallowbraid_and_morinfen_pay_one_life_per_age_counter() -> void:
	var braid := put_battlefield(0, "Gallowbraid")
	var morinfen := put_battlefield(0, "Morinfen")
	assert_true(braid.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_true(morinfen.has_keyword(Mtg.Keyword.FLYING))
	_own_upkeep()
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	_own_upkeep()
	resolve_stack()
	assert_eq(g.players[0].life, 14, "two each for two age counters")
	assert_eq(braid.zone, Mtg.Zone.BATTLEFIELD)


# --- Haunting Misery --------------------------------------------------------------------

func test_haunting_misery_exiles_x_creature_cards_for_x_damage() -> void:
	var a := _in_graveyard(0, "Grizzly Bears")
	var b := _in_graveyard(0, "Hill Giant")
	var bolt := _in_graveyard(0, "Lightning Bolt")
	var misery := give_hand(0, "Haunting Misery")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, misery, [TargetRef.player(1)], 3))
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD, "two creature cards cannot pay X = 3")
	assert_ok(g.cast_spell(0, misery, [TargetRef.player(1)], 2))
	assert_eq(a.zone, Mtg.Zone.EXILE)
	assert_eq(b.zone, Mtg.Zone.EXILE)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 18)

func test_haunting_misery_the_payer_chooses_which_cards() -> void:
	var a := _in_graveyard(0, "Grizzly Bears")
	var b := _in_graveyard(0, "Hill Giant")
	var misery := give_hand(0, "Haunting Misery")
	add_mana(0, Mtg.ManaColor.B, 3)
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	assert_ok(g.cast_spell(0, misery, [TargetRef.player(1)], 1))
	assert_not_null(g.awaiting_choice)
	assert_eq(misery.zone, Mtg.Zone.HAND, "nothing moves while the payer is asked")
	assert_ok(g.answer_choice(b.id))
	assert_eq(b.zone, Mtg.Zone.EXILE)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)


# --- Necratog / Zombie Scavengers ------------------------------------------------------

func test_necratog_exiles_the_top_creature_card_for_plus_two() -> void:
	var tog := put_battlefield(0, "Necratog")
	var lower := _in_graveyard(0, "Grizzly Bears")
	var upper := _in_graveyard(0, "Hill Giant")
	var top := _in_graveyard(0, "Lightning Bolt")
	assert_ok(g.activate_ability(0, tog, 0))
	assert_eq(upper.zone, Mtg.Zone.EXILE, "the topmost CREATURE card")
	assert_eq(top.zone, Mtg.Zone.GRAVEYARD)
	assert_ok(g.activate_ability(0, tog, 0))
	assert_eq(lower.zone, Mtg.Zone.EXILE)
	assert_refused(g.activate_ability(0, tog, 0))
	resolve_stack()
	assert_eq(tog.cur_power, 5)
	assert_eq(tog.cur_toughness, 6)

func test_zombie_scavengers_regenerate_by_exiling_a_creature_card() -> void:
	var zombie := put_battlefield(0, "Zombie Scavengers")
	assert_refused(g.activate_ability(0, zombie, 0))
	var bear := _in_graveyard(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, zombie, 0))
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	resolve_stack()
	g.destroy(zombie)
	assert_eq(zombie.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(zombie.tapped)


# --- Spinning Darkness -----------------------------------------------------------------

func test_spinning_darkness_alternative_cost_exiles_the_top_three_black_cards() -> void:
	var deep := _in_graveyard(0, "Dark Ritual")
	var b1 := _in_graveyard(0, "Terror")
	var red := _in_graveyard(0, "Lightning Bolt")
	var b2 := _in_graveyard(0, "Dark Ritual")
	var b3 := _in_graveyard(0, "Drain Life")
	var bear := put_battlefield(1, "Grizzly Bears")
	var darkness := give_hand(0, "Spinning Darkness")
	assert_eq(darkness.data.cost.mana_value(), 6)
	assert_ok(g.cast_spell(0, darkness, [TargetRef.card(bear)], 0, 1))
	for c in [b1, b2, b3]: assert_eq(c.zone, Mtg.Zone.EXILE)
	assert_eq(deep.zone, Mtg.Zone.GRAVEYARD, "only the TOP three black cards")
	assert_eq(red.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 23)

func test_spinning_darkness_refuses_a_black_creature_and_two_black_cards() -> void:
	_in_graveyard(0, "Dark Ritual")
	_in_graveyard(0, "Terror")
	var knight := put_battlefield(1, "Black Knight")
	var bear := put_battlefield(1, "Grizzly Bears")
	var darkness := give_hand(0, "Spinning Darkness")
	assert_refused(g.cast_spell(0, darkness, [TargetRef.card(bear)], 0, 1))
	_in_graveyard(0, "Terror")
	assert_refused(g.cast_spell(0, darkness, [TargetRef.card(knight)], 0, 1))
	assert_eq(darkness.zone, Mtg.Zone.HAND)

func test_spinning_darkness_ai_row_uses_the_graveyard_when_it_can() -> void:
	var data := CardRegistry.get_card("Spinning Darkness")
	assert_true(data.ai_mode_picker.is_valid())
	_in_graveyard(0, "Dark Ritual")
	_in_graveyard(0, "Terror")
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 0, "two black cards: pay the mana")
	_in_graveyard(0, "Terror")
	assert_eq(int(data.ai_mode_picker.call(g, 0)), 1)


# --- Tendrils of Despair ------------------------------------------------------------------

func test_tendrils_sacrifices_a_creature_and_the_opponent_discards_two() -> void:
	var fodder := put_battlefield(0, "Llanowar Elves")
	for n in ["Grizzly Bears", "Hill Giant", "Lightning Bolt"]: give_hand(1, n)
	var tendrils := give_hand(0, "Tendrils of Despair")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, tendrils, [TargetRef.player(1)]))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(g.players[1].graveyard.size(), 2)

func test_tendrils_targets_only_an_opponent_and_needs_a_creature() -> void:
	var tendrils := give_hand(0, "Tendrils of Despair")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.cast_spell(0, tendrils, [TargetRef.player(1)]))
	put_battlefield(0, "Llanowar Elves")
	assert_refused(g.cast_spell(0, tendrils, [TargetRef.player(0)]))


# --- Wave of Terror -------------------------------------------------------------------------

func test_wave_of_terror_destroys_creatures_whose_mana_value_is_its_age() -> void:
	var wave := put_battlefield(0, "Wave of Terror")
	put_battlefield(0, "Swamp")
	var elves := put_battlefield(1, "Llanowar Elves")   # mana value 1
	var bear := put_battlefield(1, "Grizzly Bears")     # mana value 2
	var troll := put_battlefield(0, "Uthden Troll")     # mana value 3
	_own_upkeep()
	resolve_stack()
	assert_eq(int(wave.counters.get("age", 0)), 1)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD)


# --- Firestorm ---------------------------------------------------------------------------------

func test_firestorm_discards_x_and_deals_x_to_each_of_x_targets() -> void:
	var c1 := give_hand(0, "Grizzly Bears")
	var c2 := give_hand(0, "Hill Giant")
	var giant := put_battlefield(1, "Hill Giant")
	var storm := give_hand(0, "Firestorm")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, storm, [TargetRef.player(1), TargetRef.card(giant), TargetRef.player(0)], 3))
	assert_eq(c1.zone, Mtg.Zone.HAND, "two cards cannot pay X = 3")
	assert_ok(g.cast_spell(0, storm, [TargetRef.player(1), TargetRef.card(giant)], 2))
	assert_eq(c1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(c2.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(giant.damage, 2)


# --- Heart of Bogardan -------------------------------------------------------------------------

func test_heart_of_bogardan_blasts_a_player_and_their_creatures_when_unpaid() -> void:
	var heart := put_battlefield(0, "Heart of Bogardan")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var mine := put_battlefield(0, "Grizzly Bears")
	_own_upkeep()
	resolve_stack()
	assert_eq(heart.zone, Mtg.Zone.BATTLEFIELD, "{2} paid")
	_own_upkeep()   # {4}: two Mountains cannot
	resolve_stack()
	assert_eq(heart.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18, "X = 2 x 2 - 2")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 2)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "only the target player's creatures")
	assert_eq(g.players[0].life, 20)

func test_heart_of_bogardan_unpaid_at_one_age_counter_deals_nothing() -> void:
	var heart := put_battlefield(0, "Heart of Bogardan")
	var seat := Scripted.new()
	seat.answers = [false]
	g.agents[0] = seat
	_own_upkeep()
	resolve_stack()
	assert_eq(heart.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)


# --- Aboroth --------------------------------------------------------------------------------------

func test_aboroth_pays_its_upkeep_in_minus_one_counters() -> void:
	var aboroth := put_battlefield(0, "Aboroth")
	_own_upkeep()
	resolve_stack()
	assert_eq(int(aboroth.counters.get("-1/-1", 0)), 1)
	_own_upkeep()
	resolve_stack()
	assert_eq(int(aboroth.counters.get("age", 0)), 2)
	assert_eq(int(aboroth.counters.get("-1/-1", 0)), 3)
	assert_eq(aboroth.cur_power, 6)


# --- Arctic Wolves ----------------------------------------------------------------------------------

func test_arctic_wolves_draw_on_entering_and_pay_two_per_age() -> void:
	var hand := g.players[0].hand.size()
	var wolves := put_battlefield(0, "Arctic Wolves")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	put_battlefield(0, "Forest")
	_own_upkeep()
	resolve_stack()
	assert_eq(wolves.zone, Mtg.Zone.GRAVEYARD, "{2} with one Forest: unpaid")


# --- Mwonvuli Ooze ----------------------------------------------------------------------------------

func test_ooze_grows_two_per_age_counter() -> void:
	var ooze := put_battlefield(0, "Mwonvuli Ooze")
	assert_eq(ooze.cur_power, 1)
	for i in 3: put_battlefield(0, "Forest")
	_own_upkeep()
	resolve_stack()
	assert_eq(int(ooze.counters.get("age", 0)), 1)
	assert_eq(ooze.cur_power, 3)
	assert_eq(ooze.cur_toughness, 3)


# --- Uktabi Efreet ---------------------------------------------------------------------------------

func test_uktabi_efreet_pays_green_per_age() -> void:
	var efreet := put_battlefield(0, "Uktabi Efreet")
	put_battlefield(0, "Mountain")
	_own_upkeep()
	resolve_stack()
	assert_eq(efreet.zone, Mtg.Zone.GRAVEYARD, "{G} cannot be paid with red mana")
