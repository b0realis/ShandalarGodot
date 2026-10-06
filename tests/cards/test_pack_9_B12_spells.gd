extends GameTest
## Pack 9 (the Tempest block), batch B12: the Exodus instants and sorceries
## in cards/sets/exo/_spells.gd — Death's Duet, Fade Away, Fighting Chance,
## Fugue, Kor Chant, Nausea, Price of Progress, Reclaim, Resuscitate and
## Scare Tactics.

const CLAIMED := ["Death's Duet", "Fade Away", "Fighting Chance", "Fugue", "Kor Chant",
	"Nausea", "Price of Progress", "Reclaim", "Resuscitate", "Scare Tactics"]

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card

## Rig the game's next coin flips to come out as [param wins] for the
## flipper (MtgGame.flip_coin: `rng.randi() % 2 == 0` wins) by spending
## throwaway draws of the seeded RNG — setup only.
func _rig_flips(wins: Array) -> void:
	for n in 512:
		var probe := RandomNumberGenerator.new()
		probe.seed = g.rng.seed
		probe.state = g.rng.state
		var ok := true
		for w in wins:
			if ((probe.randi() % 2) == 0) != bool(w):
				ok = false
				break
		if ok: return
		g.rng.randi()
	fail_test("could not rig the flips")

func _nonbasic(pid: int) -> CardInstance:
	return put_synthetic(pid, CardData.new("Test Nonbasic Land", "", Mtg.CardType.LAND))


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------------- Death's Duet --

func test_deaths_duet_returns_two_creature_cards() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var a := _to_graveyard(0, "Grizzly Bears")
	var b := _to_graveyard(0, "Hill Giant")
	var land := _to_graveyard(0, "Forest")
	var duet := give_hand(0, "Death's Duet")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, duet, [TargetRef.card(a), TargetRef.card(land)]), "")
	assert_refused(g.cast_spell(0, duet, [TargetRef.card(a), TargetRef.card(a)]), "")
	assert_ok(g.cast_spell(0, duet, [TargetRef.card(a), TargetRef.card(b)]))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.HAND)
	assert_eq(b.zone, Mtg.Zone.HAND)
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)

func test_deaths_duet_needs_two_targets() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var a := _to_graveyard(0, "Grizzly Bears")
	_to_graveyard(1, "Hill Giant")
	var duet := give_hand(0, "Death's Duet")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.cast_spell(0, duet, [TargetRef.card(a)]), "")
	assert_eq(duet.zone, Mtg.Zone.HAND)


# ---------------------------------------------------------------- Fade Away --

func test_fade_away_taxes_each_creature_in_mana_or_a_permanent() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var crusade := put_battlefield(0, "Crusade")
	var wurm := put_battlefield(1, "Craw Wurm")
	var fade := give_hand(0, "Fade Away")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, fade, []))
	add_mana(1, Mtg.ManaColor.C)
	resolve_stack()
	# P0 has nothing left to pay with: two creatures, two permanents, the
	# cheapest first by the hint.
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "P1 paid {1} for its one creature")
	assert_eq(g.players[1].mana_pool.total(), 0)

func test_fade_away_with_no_creatures_does_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var crusade := put_battlefield(0, "Crusade")
	var fade := give_hand(0, "Fade Away")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(0, fade, []))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- Fighting Chance --

func test_fighting_chance_flips_once_per_blocker() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var ogre := put_battlefield(1, "Gray Ogre")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bear.id, ogre.id: bear.id}))
	var chance := give_hand(0, "Fighting Chance")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, chance, []))
	_rig_flips([true, false])
	resolve_stack()
	# Blockers in battlefield order: the Giant's flip won, the Ogre's lost.
	assert_true(giant.cur_prevent_combat_damage_dealt)
	assert_false(ogre.cur_prevent_combat_damage_dealt)
	assert_false(bear.cur_prevent_combat_damage_dealt, "only blocking creatures")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the Ogre's 2 still kill it")
	assert_true(chance.data.spell_effects[0].is_damage_prevention, "legal in the 1997 window")

func test_fighting_chance_with_no_blockers_flips_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var chance := give_hand(0, "Fighting Chance")
	add_mana(0, Mtg.ManaColor.R)
	var state := g.rng.state
	assert_ok(g.cast_spell(0, chance, []))
	resolve_stack()
	assert_eq(g.rng.state, state, "no coin flipped")


# -------------------------------------------------------------------- Fugue --

func test_fugue_makes_the_target_player_discard_three() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	for n in ["Forest", "Lightning Bolt", "Hill Giant", "Craw Wurm"]: give_hand(1, n)
	var fugue := give_hand(0, "Fugue")
	add_mana(0, Mtg.ManaColor.B, 5)
	assert_ok(g.cast_spell(0, fugue, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(g.players[1].graveyard.size(), 3)

func test_fugue_on_a_short_hand_takes_what_there_is() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(1, "Forest")
	var fugue := give_hand(0, "Fugue")
	add_mana(0, Mtg.ManaColor.B, 5)
	assert_ok(g.cast_spell(0, fugue, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0)
	assert_eq(g.players[1].graveyard.size(), 1)


# ---------------------------------------------------------------- Kor Chant --

func test_kor_chant_sends_a_bolt_on_to_another_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(1))
	var chant := give_hand(0, "Kor Chant")
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_refused(g.cast_spell(0, chant, [TargetRef.card(giant), TargetRef.card(bear)]), "")
	assert_refused(g.cast_spell(0, chant, [TargetRef.card(bear), TargetRef.card(bear)]), "")
	assert_ok(g.cast_spell(0, chant, [TargetRef.card(bear), TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the Bolt's damage went elsewhere")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "3 damage to the Giant")

func test_kor_chant_turns_an_attackers_damage_on_itself() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	assert_ok(g.pass_priority(0))
	var chant := give_hand(1, "Kor Chant")
	add_mana(1, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(1, chant, [TargetRef.card(bear), TargetRef.card(giant)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "all of the Giant's damage to the Bear this turn")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "3 of its own damage and the Bear's 2")

func test_kor_chant_without_its_second_target_does_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var ogre := put_battlefield(1, "Gray Ogre")
	var chant := give_hand(0, "Kor Chant")
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, chant, [TargetRef.card(bear), TargetRef.card(ogre)]))
	g.return_to_hand(ogre)
	resolve_stack()
	assert_true(g.damage_effects.is_empty(), "no redirection registered")
	assert_true(chant.data.spell_effects[0].is_damage_prevention and chant.data.spell_effects[1].is_damage_prevention)


# ------------------------------------------------------------------- Nausea --

func test_nausea_shrinks_every_creature_until_end_of_turn() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var elf := put_battlefield(0, "Llanowar Elves")
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var nausea := give_hand(0, "Nausea")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, nausea, []))
	resolve_stack()
	assert_eq(elf.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_pt(bear), [1, 1])
	assert_eq(_pt(theirs), [2, 2])
	advance_to_next_turn()
	assert_eq(_pt(theirs), [3, 3])


# -------------------------------------------------------- Price of Progress --

func test_price_of_progress_charges_two_per_nonbasic_land() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_nonbasic(0)
	_nonbasic(0)
	put_battlefield(0, "Mountain")
	_nonbasic(1)
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	var price := give_hand(0, "Price of Progress")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, price, []))
	resolve_stack()
	assert_eq(g.players[0].life, 16)
	assert_eq(g.players[1].life, 18)

func test_price_of_progress_spares_basics_only_decks() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Forest")
	var price := give_hand(0, "Price of Progress")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, price, []))
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 20)


# ------------------------------------------------------------------ Reclaim --

func test_reclaim_puts_a_card_from_your_graveyard_on_top() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bolt := _to_graveyard(0, "Lightning Bolt")
	var theirs := _to_graveyard(1, "Hill Giant")
	var reclaim := give_hand(0, "Reclaim")
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, reclaim, [TargetRef.card(theirs)]), "")
	assert_ok(g.cast_spell(0, reclaim, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), bolt)


# -------------------------------------------------------------- Resuscitate --

func test_resuscitate_gives_your_creatures_regeneration_for_the_turn() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var res := give_hand(0, "Resuscitate")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, res, []))
	resolve_stack()
	assert_eq(bear.cur_activated_abilities.size(), 1)
	assert_eq(theirs.cur_activated_abilities.size(), 0, "only creatures you control")
	var late := put_battlefield(0, "Llanowar Elves")
	g.recalculate()
	assert_eq(late.cur_activated_abilities.size(), 0, "fixed as it resolves")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, bear, 0))
	resolve_stack()
	assert_eq(bear.regeneration_shields, 1)
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	assert_eq(bear.cur_activated_abilities.size(), 0, "until end of turn")


# ------------------------------------------------------------ Scare Tactics --

func test_scare_tactics_pumps_only_your_creatures() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var scare := give_hand(0, "Scare Tactics")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, scare, []))
	resolve_stack()
	assert_eq(_pt(bear), [3, 2])
	assert_eq(_pt(theirs), [3, 3])
	advance_to_next_turn()
	assert_eq(_pt(bear), [2, 2])


# ------------------------------------------- the 1997 damage-prevention window --

## A seat that asks for the 1997 damage-prevention window.
class WindowSeat extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true

func _window_priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_damage_prevention)
	assert_eq(g.priority_player, pid)

func _close_window() -> void:
	var guard := 0
	while (g.awaiting_damage_prevention or g.awaiting_regeneration or not g.stack.is_empty()) \
			and guard < 20:
		if g.stack.is_empty():
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 20)

func test_1997_window_kor_chant_redirects_waiting_combat_damage() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(1, WindowSeat.new())
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var chant := give_hand(1, "Kor Chant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the 1997 damage prevention step is open")
	_window_priority(1)
	add_mana(1, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(1, chant, [TargetRef.card(bear), TargetRef.card(giant)]))
	_close_window()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the waiting damage to the Bear lands on the Giant")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)

func test_1997_window_fighting_chance_stops_waiting_blocker_damage() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(0, WindowSeat.new())
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var ogre := put_battlefield(1, "Gray Ogre")
	var chance := give_hand(0, "Fighting Chance")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: bear.id, ogre.id: bear.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	_window_priority(0)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, chance, []))
	_rig_flips([true, true])
	_close_window()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "both blockers' waiting damage prevented")
