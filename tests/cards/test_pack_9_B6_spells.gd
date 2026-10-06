extends GameTest
## Pack 9 (the Tempest block), batch B6: the Tempest instants and sorceries
## in cards/sets/tmp/_spells.gd — every card claimed, its main effect, a
## refused or illegal case, and the interactions its text implies (the
## second slot judged against the first, a target gone in response, the
## life a fizzled spell does not cost, both rules presets).

const CLAIMED := ["Aftershock", "Apocalypse", "Blood Frenzy", "Boil", "Deadshot", "Diabolic Edict",
	"Dismiss", "Dregs of Sorrow", "Gallantry", "Interdict", "Kindle", "Legerdemain", "Lightning Blast",
	"Meditate", "Overrun", "Perish", "Reanimate", "Reckless Spite", "Repentance", "Respite",
	"Rolling Thunder", "Serene Offering", "Stun", "Sudden Impact", "Time Warp", "Twitch", "Verdigris",
	"Winds of Rath"]


## Scripted answers: yes/no from [member says], a card by name from
## [member picks] (else the first candidate), an option by label from
## [member labels] (else the hint). Remembers every prompt.
class Seat extends DecisionAgent:
	var says := true
	var picks: Array[String] = []
	var labels: Array[String] = []
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return says
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		while not picks.is_empty():
			var want: String = picks.pop_front()
			for c in candidates:
				if c.data.card_name == want: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(prompt)
		while not labels.is_empty():
			var at := options.find(labels.pop_front())
			if at >= 0: return at
		return hint


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

## Exactly the mana [param card_name] costs (X extra generic), as colorless
## for the generic part — nothing is left over to burn.
func _pay(pid: int, card_name: String, x := 0) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)

## Give [param pid] the spell, its mana and priority; return the cast's verdict.
func _try(pid: int, card_name: String, targets: Array = [], x := 0) -> String:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name, x)
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	return g.cast_spell(pid, card, targets, x)

func _cast(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	assert_ok(_try(pid, card_name, targets, x))

func _cast_resolve(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	_cast(pid, card_name, targets, x)
	resolve_stack()

func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst

func _enchant(pid: int, aura_name: String, host: CardInstance) -> CardInstance:
	var aura := give_hand(pid, aura_name)
	_pay(pid, aura_name)
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	return aura

## P0 attacks with [param attackers]; P1 blocks with [param blocks]
## (blocker id -> attacker id). Leaves the game in the declare-blockers
## step with P0 holding priority.
func _attack(attackers: Array[CardInstance], blocks := {}) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# --------------------------------------------------------------- Aftershock --

func test_aftershock_destroys_an_artifact_creature_or_land_and_burns_its_caster() -> void:
	var icy := put_battlefield(1, "Icy Manipulator")
	_cast_resolve(0, "Aftershock", [TargetRef.card(icy)])
	assert_eq(icy.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 17)
	var land := put_battlefield(1, "Forest")
	_cast_resolve(0, "Aftershock", [TargetRef.card(land)])
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 14)

func test_aftershock_refuses_an_enchantment_and_costs_nothing_when_it_fizzles() -> void:
	var pest := put_battlefield(1, "Pestilence")
	assert_refused(_try(0, "Aftershock", [TargetRef.card(pest)]))
	var bear := put_battlefield(1, "Grizzly Bears")
	var shock := give_hand(0, "Aftershock")
	_pay(0, "Aftershock")
	assert_ok(g.cast_spell(0, shock, [TargetRef.card(bear)]))
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "a fizzled Aftershock deals no damage (CR 608.2b)")


# --------------------------------------------------------------- Apocalypse --

func test_apocalypse_exiles_every_permanent_and_its_caster_discards_their_hand() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var land := put_battlefield(0, "Mountain")
	var theirs := put_battlefield(1, "Icy Manipulator")
	var pest := put_battlefield(1, "Pestilence")
	var kept := give_hand(0, "Lightning Bolt")
	var their_card := give_hand(1, "Lightning Bolt")
	_cast_resolve(0, "Apocalypse")
	for i in [mine, land, theirs, pest]:
		assert_eq(i.zone, Mtg.Zone.EXILE, i.data.card_name)
	assert_true(g.all_battlefield().is_empty())
	assert_eq(kept.zone, Mtg.Zone.GRAVEYARD, "you discard your hand")
	assert_eq(g.players[0].hand.size(), 0)
	assert_eq(their_card.zone, Mtg.Zone.HAND, "only the caster discards")
	assert_eq(g.players[0].graveyard.size(), 2, "the discarded card and Apocalypse itself")


# ------------------------------------------------------------- Blood Frenzy --

func test_blood_frenzy_pumps_an_attacker_and_destroys_it_at_the_end_step() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([bear])
	_cast_resolve(0, "Blood Frenzy", [TargetRef.card(bear)])
	assert_eq(bear.cur_power, 6)
	assert_eq(bear.cur_toughness, 2)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 14)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "destroyed at the beginning of the next end step")

func test_blood_frenzy_kills_a_blocker_too_and_needs_a_creature_in_combat() -> void:
	var idle := put_battlefield(0, "Hill Giant")
	assert_refused(_try(0, "Blood Frenzy", [TargetRef.card(idle)]), "attacking")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	_attack([bear], {wall.id: bear.id})
	_cast_resolve(0, "Blood Frenzy", [TargetRef.card(wall)])
	assert_eq(wall.cur_power, 4)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "a blocking creature qualifies")

func test_blood_frenzy_is_refused_once_combat_damage_has_begun() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_attack([bear])
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_refused(_try(0, "Blood Frenzy", [TargetRef.card(bear)]), "before the combat damage step")


# --------------------------------------------------------------------- Boil --

func test_boil_destroys_every_island_and_nothing_else() -> void:
	var a := put_battlefield(0, "Island")
	var b := put_battlefield(1, "Island")
	var c := put_battlefield(1, "Island")
	var forest := put_battlefield(1, "Forest")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Boil")
	for i in [a, b, c]:
		assert_eq(i.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_boil_is_an_instant() -> void:
	var island := put_battlefield(0, "Island")
	advance_to_next_turn()   # P1's turn: P0 casts it with priority
	_cast_resolve(0, "Boil")
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------------------- Deadshot --

func test_deadshot_taps_the_first_and_shoots_the_second_with_its_power() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Deadshot", [TargetRef.card(giant), TargetRef.card(bear)])
	assert_true(giant.tapped)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "3 damage from the Giant")

func test_deadshot_needs_another_creature() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	assert_refused(_try(0, "Deadshot", [TargetRef.card(giant), TargetRef.card(giant)]))

func test_deadshot_with_the_first_target_gone_deals_no_damage() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast(0, "Deadshot", [TargetRef.card(giant), TargetRef.card(bear)])
	g.return_to_hand(giant)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.damage, 0)

func test_deadshot_with_the_second_target_gone_still_taps_the_first() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast(0, "Deadshot", [TargetRef.card(giant), TargetRef.card(bear)])
	g.return_to_hand(bear)
	resolve_stack()
	assert_true(giant.tapped)
	assert_eq(giant.damage, 0)


# ----------------------------------------------------------- Diabolic Edict --

func test_diabolic_edict_target_player_sacrifices_a_creature_of_their_choice() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	var seat := _seat(1)
	seat.picks = ["Craw Wurm"]
	_cast_resolve(0, "Diabolic Edict", [TargetRef.player(1)])
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "their choice, not the caster's")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_diabolic_edict_offers_the_weakest_first_and_does_nothing_to_an_empty_board() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	_cast_resolve(0, "Diabolic Edict", [TargetRef.player(1)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the heuristic seat gives up its weakest")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	var mine := put_battlefield(0, "Grizzly Bears")
	g.sacrifice_permanent(wurm)
	_cast_resolve(0, "Diabolic Edict", [TargetRef.player(1)])
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "nothing of the caster's is touched")


# ------------------------------------------------------------------ Dismiss --

func test_dismiss_counters_a_spell_and_draws_a_card() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_next_turn()
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	var hand := g.players[0].hand.size()
	_cast_resolve(0, "Dismiss", [TargetRef.card(bolt)])
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[0].hand.size(), hand + 1, "Dismiss left the hand, a card came in")

func test_dismiss_needs_a_spell() -> void:
	assert_refused(_try(0, "Dismiss", []))


# --------------------------------------------------------- Dregs of Sorrow --

func test_dregs_of_sorrow_destroys_x_nonblack_creatures_and_draws_x() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var hand := g.players[0].hand.size()
	_cast_resolve(0, "Dregs of Sorrow", [TargetRef.card(a), TargetRef.card(b)], 2)
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand + 2)

func test_dregs_of_sorrow_refuses_a_black_creature_and_draws_nothing_when_it_fizzles() -> void:
	var zombie := put_battlefield(1, "Scathe Zombies")
	assert_refused(_try(0, "Dregs of Sorrow", [TargetRef.card(zombie)], 1))
	var bear := put_battlefield(1, "Grizzly Bears")
	var dregs := give_hand(0, "Dregs of Sorrow")
	_pay(0, "Dregs of Sorrow", 1)
	assert_ok(g.cast_spell(0, dregs, [TargetRef.card(bear)], 1))
	g.return_to_hand(bear)
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "every target illegal: countered, no draw")


# ---------------------------------------------------------------- Gallantry --

func test_gallantry_pumps_a_blocker_and_draws() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack([giant], {bear.id: giant.id})
	var hand := g.players[1].hand.size()
	_cast_resolve(1, "Gallantry", [TargetRef.card(bear)])
	assert_eq(bear.cur_power, 6)
	assert_eq(bear.cur_toughness, 6)
	assert_eq(g.players[1].hand.size(), hand + 1)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_gallantry_refuses_a_creature_that_is_not_blocking() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(_try(0, "Gallantry", [TargetRef.card(bear)]), "blocking")


# ----------------------------------------------------------------- Interdict --

func _pump_on_stack() -> CardInstance:
	var dragon := put_battlefield(0, "Shivan Dragon")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, dragon, 0))
	return dragon

func test_interdict_counters_the_ability_bans_that_permanent_and_draws() -> void:
	var dragon := _pump_on_stack()
	var other := put_battlefield(0, "Shivan Dragon")
	var hand := g.players[1].hand.size()
	_cast_resolve(1, "Interdict", [TargetRef.ability(g.stack[0])])
	assert_eq(dragon.cur_power, 5, "the pump was countered")
	assert_eq(g.players[1].hand.size(), hand + 1)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.activate_ability(0, dragon, 0))
	assert_ok(g.activate_ability(0, other, 0))
	resolve_stack()
	assert_eq(other.cur_power, 6, "another permanent is not banned")
	var a: ActivatedAbility = dragon.cur_activated_abilities[0]
	assert_ne(g.activation_ban_reason(0, dragon, a, true), "", "mana abilities are activated abilities too")
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.R)
	assert_eq(g.activate_ability(0, dragon, 0), "", "the ban ends with the turn")

func test_interdict_targets_artifact_abilities_but_not_spells() -> void:
	var icy := put_battlefield(0, "Icy Manipulator")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(bear)]))
	_cast_resolve(1, "Interdict", [TargetRef.ability(g.stack[0])])
	assert_false(bear.tapped)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_refused(_try(1, "Interdict", [TargetRef.card(bolt)]))


# ------------------------------------------------------------------- Kindle --

func test_kindle_counts_every_kindle_in_every_graveyard() -> void:
	_cast_resolve(0, "Kindle", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 18, "2 plus none: this one was still on the stack")
	_grave(1, "Kindle")
	_cast_resolve(0, "Kindle", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 14, "2 plus the first one and the opponent's")

func test_kindle_kills_a_creature() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	_grave(0, "Kindle")
	_cast_resolve(0, "Kindle", [TargetRef.card(giant)])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------------- Legerdemain --

func test_legerdemain_exchanges_two_creatures_indefinitely() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	_cast_resolve(0, "Legerdemain", [TargetRef.card(bear), TargetRef.card(wurm)])
	assert_eq(bear.controller_id, 1)
	assert_eq(wurm.controller_id, 0)
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(wurm.controller_id, 0, "it lasts indefinitely")

func test_legerdemain_second_target_must_share_artifact_or_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(1, "Forest")
	var icy := put_battlefield(1, "Icy Manipulator")
	assert_refused(_try(0, "Legerdemain", [TargetRef.card(bear), TargetRef.card(forest)]))
	assert_refused(_try(0, "Legerdemain", [TargetRef.card(bear), TargetRef.card(icy)]), "type")
	assert_refused(_try(0, "Legerdemain", [TargetRef.card(bear), TargetRef.card(bear)]))
	var thopter := put_battlefield(0, "Ornithopter")
	_cast_resolve(0, "Legerdemain", [TargetRef.card(thopter), TargetRef.card(icy)])
	assert_eq(icy.controller_id, 0, "an artifact creature shares artifact with an artifact")
	assert_eq(thopter.controller_id, 1)

func test_legerdemain_does_nothing_when_either_target_is_gone() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	_cast(0, "Legerdemain", [TargetRef.card(bear), TargetRef.card(wurm)])
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(wurm.controller_id, 1)


# ---------------------------------------------------------- Lightning Blast --

func test_lightning_blast_deals_four_to_any_target() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")
	_cast_resolve(0, "Lightning Blast", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 16)
	_cast_resolve(0, "Lightning Blast", [TargetRef.card(wurm)])
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "4 damage to a 6/4")


# ----------------------------------------------------------------- Meditate --

func test_meditate_draws_four_and_skips_the_casters_next_turn() -> void:
	var hand := g.players[0].hand.size()
	_cast_resolve(0, "Meditate")
	assert_eq(g.players[0].hand.size(), hand + 4)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1, "P0's next turn is skipped")
	advance_to_next_turn()
	assert_eq(g.active_player, 0)


# ------------------------------------------------------------------ Overrun --

func test_overrun_pumps_and_tramples_only_your_creatures() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Overrun")
	assert_eq(mine.cur_power, 5)
	assert_eq(mine.cur_toughness, 5)
	assert_true(mine.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_eq(theirs.cur_power, 2)
	assert_false(theirs.has_keyword(Mtg.Keyword.TRAMPLE))
	advance_to_next_turn()
	assert_eq(mine.cur_power, 2, "until end of turn")


# ------------------------------------------------------------------- Perish --

func test_perish_destroys_green_creatures_without_regeneration() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(0, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	var forest := put_battlefield(1, "Forest")
	bear.regeneration_shields = 1
	_cast_resolve(0, "Perish")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "they can't be regenerated")
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "the caster's own too")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "a green-producing land is colorless")


# ---------------------------------------------------------------- Reanimate --

func test_reanimate_takes_any_graveyards_creature_and_costs_its_mana_value() -> void:
	var wurm := _grave(1, "Craw Wurm")
	_cast_resolve(0, "Reanimate", [TargetRef.card(wurm)])
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.controller_id, 0)
	assert_eq(g.players[0].life, 14, "Craw Wurm's mana value is 6")

func test_reanimate_refuses_a_noncreature_card_and_a_fizzle_costs_no_life() -> void:
	var bolt := _grave(1, "Lightning Bolt")
	assert_refused(_try(0, "Reanimate", [TargetRef.card(bolt)]))
	var bear := _grave(0, "Grizzly Bears")
	var spell := give_hand(0, "Reanimate")
	_pay(0, "Reanimate")
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear)]))
	g.exile_from_graveyard(bear)
	resolve_stack()
	assert_eq(g.players[0].life, 20)


# ----------------------------------------------------------- Reckless Spite --

func test_reckless_spite_destroys_two_nonblack_creatures_and_costs_five_life() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	_cast_resolve(0, "Reckless Spite", [TargetRef.card(a), TargetRef.card(b)])
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 15)

func test_reckless_spite_needs_two_different_nonblack_targets() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var zombie := put_battlefield(1, "Scathe Zombies")
	assert_refused(_try(0, "Reckless Spite", [TargetRef.card(a)]))
	assert_refused(_try(0, "Reckless Spite", [TargetRef.card(a), TargetRef.card(a)]))
	assert_refused(_try(0, "Reckless Spite", [TargetRef.card(a), TargetRef.card(zombie)]))

func test_reckless_spite_with_one_target_left_still_costs_the_life() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	_cast(0, "Reckless Spite", [TargetRef.card(a), TargetRef.card(b)])
	g.return_to_hand(a)
	resolve_stack()
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 15)
	var c := put_battlefield(1, "Grizzly Bears")
	var d := put_battlefield(1, "Hill Giant")
	_cast(0, "Reckless Spite", [TargetRef.card(c), TargetRef.card(d)])
	g.return_to_hand(c)
	g.return_to_hand(d)
	resolve_stack()
	assert_eq(g.players[0].life, 15, "both gone: countered, no life lost")


# --------------------------------------------------------------- Repentance --

func test_repentance_makes_a_creature_deal_its_power_to_itself() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	_cast_resolve(0, "Repentance", [TargetRef.card(giant)])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	var minotaur := put_battlefield(1, "Hurloon Minotaur")
	_cast_resolve(0, "Repentance", [TargetRef.card(minotaur)])
	assert_eq(minotaur.zone, Mtg.Zone.BATTLEFIELD, "a 2/3 survives its own 2")
	assert_eq(minotaur.damage, 2)

func test_repentance_on_a_zero_power_wall_and_protection() -> void:
	var wall := put_battlefield(1, "Wall of Stone")
	_cast_resolve(0, "Repentance", [TargetRef.card(wall)])
	assert_eq(wall.damage, 0)
	var knight := put_battlefield(1, "Black Knight")
	assert_refused(_try(0, "Repentance", [TargetRef.card(knight)]))


# ------------------------------------------------------------------ Respite --

func test_respite_fogs_combat_and_gains_a_life_per_attacker() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Hill Giant")
	_attack([a, b])
	_cast_resolve(1, "Respite")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 22)

## The 1997 damage-prevention window admits a spell whose every effect
## prevents, heals or redirects damage: Respite is a Fog with a rider.
func test_respite_is_one_of_the_damage_prevention_family() -> void:
	var effects := CardRegistry.get_card("Respite").spell_effects
	assert_eq(effects.size(), 2)
	for e in effects:
		assert_true(e.is_damage_prevention)

func test_respite_outside_combat_gains_nothing() -> void:
	_cast_resolve(0, "Respite")
	assert_eq(g.players[0].life, 20)


# ---------------------------------------------------------- Rolling Thunder --

func test_rolling_thunder_divides_x_among_any_number_of_targets() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_cast_resolve(0, "Rolling Thunder",
		[TargetRef.card(bear, 2), TargetRef.card(giant, 3), TargetRef.player(1, 1)], 6)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 19)

func test_rolling_thunder_refuses_a_division_that_does_not_add_up() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_try(0, "Rolling Thunder", [TargetRef.card(bear, 2), TargetRef.player(1, 2)], 5))


# ---------------------------------------------------------- Serene Offering --

func test_serene_offering_destroys_an_enchantment_for_its_mana_value_in_life() -> void:
	var pest := put_battlefield(1, "Pestilence")
	_cast_resolve(0, "Serene Offering", [TargetRef.card(pest)])
	assert_eq(pest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 24)

func test_serene_offering_refuses_an_artifact() -> void:
	var icy := put_battlefield(1, "Icy Manipulator")
	assert_refused(_try(0, "Serene Offering", [TargetRef.card(icy)]))


# --------------------------------------------------------------------- Stun --

func test_stun_stops_a_creature_blocking_this_turn_and_draws() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	var hand := g.players[0].hand.size()
	_cast_resolve(0, "Stun", [TargetRef.card(bear)])
	assert_eq(g.players[0].hand.size(), hand + 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: giant.id}))
	assert_ok(g.declare_blockers(1, {}))
	advance_to_next_turn()
	advance_to_next_turn()
	assert_false(bear.cur_cant_block_filter.is_valid(), "only this turn")


# ------------------------------------------------------------ Sudden Impact --

func test_sudden_impact_counts_the_target_players_hand() -> void:
	for n in 3: give_hand(1, "Forest")
	_cast_resolve(0, "Sudden Impact", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 17)
	g.discard_hand(1)
	_cast_resolve(0, "Sudden Impact", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 17, "an empty hand: no damage")

func test_sudden_impact_targets_only_a_player() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_try(0, "Sudden Impact", [TargetRef.card(bear)]))


# ---------------------------------------------------------------- Time Warp --

func test_time_warp_gives_the_target_player_the_next_turn() -> void:
	_cast_resolve(0, "Time Warp", [TargetRef.player(0)])
	advance_to_next_turn()
	assert_eq(g.active_player, 0, "the caster's extra turn")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)

func test_time_warp_can_give_the_turn_to_the_opponent() -> void:
	_cast_resolve(0, "Time Warp", [TargetRef.player(1)])
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1, "their extra turn, then their own")
	advance_to_next_turn()
	assert_eq(g.active_player, 0)


# ------------------------------------------------------------------- Twitch --

func test_twitch_untaps_or_taps_its_target_or_leaves_it_and_draws() -> void:
	var land := put_battlefield(0, "Forest")
	g.tap_permanent(land)
	var seat := _seat(0)
	var hand := g.players[0].hand.size()
	_cast_resolve(0, "Twitch", [TargetRef.card(land)])
	assert_false(land.tapped, "the hint untaps our own tapped land")
	assert_eq(g.players[0].hand.size(), hand + 1)
	var bear := put_battlefield(1, "Grizzly Bears")
	seat.labels = ["Leave it as it is"]
	_cast_resolve(0, "Twitch", [TargetRef.card(bear)])
	assert_false(bear.tapped, "\"you may\": leaving it is an answer")
	seat.labels = ["Tap it"]
	_cast_resolve(0, "Twitch", [TargetRef.card(bear)])
	assert_true(bear.tapped)

func test_twitch_refuses_an_enchantment() -> void:
	var pest := put_battlefield(1, "Pestilence")
	assert_refused(_try(0, "Twitch", [TargetRef.card(pest)]))


# ---------------------------------------------------------------- Verdigris --

func test_verdigris_destroys_an_artifact_only() -> void:
	var icy := put_battlefield(1, "Icy Manipulator")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_try(0, "Verdigris", [TargetRef.card(bear)]))
	_cast_resolve(0, "Verdigris", [TargetRef.card(icy)])
	assert_eq(icy.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------ Winds of Rath --

func test_winds_of_rath_spares_enchanted_creatures_and_forbids_regeneration() -> void:
	var dressed := put_battlefield(0, "Grizzly Bears")
	var strength := _enchant(0, "Holy Strength", dressed)
	var bare := put_battlefield(1, "Hill Giant")
	var shielded := put_battlefield(1, "Grizzly Bears")
	shielded.regeneration_shields = 1
	_cast_resolve(0, "Winds of Rath")
	assert_eq(dressed.zone, Mtg.Zone.BATTLEFIELD, "an enchanted creature survives")
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bare.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(shielded.zone, Mtg.Zone.GRAVEYARD, "they can't be regenerated")


# ------------------------------------------------------------------ timing --

func test_the_sorceries_wait_for_their_casters_main_phase() -> void:
	var land := put_battlefield(1, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var dead := _grave(1, "Craw Wurm")
	advance_to_next_turn()   # P1's turn
	var cases := {"Aftershock": [TargetRef.card(land)], "Apocalypse": [],
		"Deadshot": [TargetRef.card(giant), TargetRef.card(bear)], "Dregs of Sorrow": [],
		"Legerdemain": [TargetRef.card(bear), TargetRef.card(giant)], "Overrun": [], "Perish": [],
		"Reanimate": [TargetRef.card(dead)], "Repentance": [TargetRef.card(giant)],
		"Rolling Thunder": [TargetRef.player(1)], "Time Warp": [TargetRef.player(0)],
		"Winds of Rath": []}
	for card_name in cases:
		var x := 1 if card_name == "Rolling Thunder" else 0
		assert_ne(_try(0, card_name, cases[card_name], x), "", "%s is a sorcery" % card_name)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)

func test_the_instants_answer_in_the_opponents_turn() -> void:
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Hill Giant")
	var c := put_battlefield(1, "Llanowar Elves")
	for n in 2: give_hand(1, "Forest")
	advance_to_next_turn()   # P1's turn
	_cast_resolve(0, "Reckless Spite", [TargetRef.card(a), TargetRef.card(b)])
	_cast_resolve(0, "Diabolic Edict", [TargetRef.player(1)])
	assert_eq(c.zone, Mtg.Zone.GRAVEYARD)
	var life := g.players[1].life
	var cards := g.players[1].hand.size()
	_cast_resolve(0, "Sudden Impact", [TargetRef.player(1)])
	_cast_resolve(0, "Kindle", [TargetRef.player(1)])
	_cast_resolve(0, "Lightning Blast", [TargetRef.player(1)])
	assert_eq(g.players[1].life, life - cards - 2 - 4)
	var hand := g.players[0].hand.size()
	_cast_resolve(0, "Meditate")
	assert_eq(g.players[0].hand.size(), hand + 4)


# ------------------------------------------------------ both rules presets --

## The 1997 profile ("fifth") and the modern one agree on every spell here:
## none reads a fork. Run a sample of them under each.
func test_spells_behave_the_same_under_both_rules_presets() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		var a := put_battlefield(1, "Grizzly Bears")
		var b := put_battlefield(1, "Hill Giant")
		_cast_resolve(0, "Reckless Spite", [TargetRef.card(a), TargetRef.card(b)])
		assert_eq(b.zone, Mtg.Zone.GRAVEYARD, preset)
		assert_eq(g.players[0].life, 15, preset)
		var wurm := _grave(1, "Craw Wurm")
		_cast_resolve(0, "Reanimate", [TargetRef.card(wurm)])
		assert_eq(wurm.controller_id, 0, preset)
		assert_eq(g.players[0].life, 9, preset)
		_cast_resolve(0, "Kindle", [TargetRef.player(1)])
		assert_eq(g.players[1].life, 18, preset)
		var icy := put_battlefield(1, "Icy Manipulator")
		_cast_resolve(0, "Aftershock", [TargetRef.card(icy)])
		assert_eq(g.players[0].life, 6, preset)
		assert_false(g.game_over, preset)
