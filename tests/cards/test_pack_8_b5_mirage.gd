extends GameTest
## Pack 8, batch B5 — Mirage triggered permanents (cards/sets/mir/_triggers.gd):
## real stack triggers, intervening-"if" rechecks (CR 603.4), last known
## information for a departed source (CR 603.6 / 608.2h) and whose choice
## each "may"/"unless" is.

## A seat whose answers a test scripts: yes/no (-1 follows the hint), an
## option index (-1 follows the hint) and card names to prefer.
class Seat extends DecisionAgent:
	var yes := -1
	var option := -1
	var prefer: Array = []
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			_options: Array[String], hint: int) -> int:
		asked.append(prompt)
		return hint if option < 0 else option

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


## Pass until [param pid]'s upkeep of a LATER turn, its triggers waiting.
func _to_upkeep(pid: int) -> void:
	var start := g.turn_number
	var guard := 0
	while not g.game_over and guard < 800 and not (g.turn_number > start
			and g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the upkeep")


## Pass until [param pid]'s end step (this turn's when it is still ahead).
func _to_end(pid: int) -> void:
	var guard := 0
	while not g.game_over and guard < 800 and not (g.active_player == pid
			and g.current_step() == Mtg.Step.END):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the end step")


func _counter(i: CardInstance, kind: String) -> int:
	return int(i.counters.get(kind, 0))


# ------------------------------------------------------- Auspicious Ancestor --

func test_auspicious_ancestor_pays_one_for_any_white_spell_and_gains_three_on_death() -> void:
	var ancestor := put_battlefield(0, "Auspicious Ancestor")
	me.yes = 1
	var lions := give_hand(0, "Savannah Lions")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, lions, []))
	assert_eq(g.stack.size(), 2, "the trigger waits above the white spell")
	resolve_stack()
	assert_eq(g.players[0].life, 21, "paid {1}, gained 1")
	# A non-white spell does not trigger.
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	# The OPPONENT's white spell triggers it too; declining gains nothing.
	me.yes = 0
	g.pass_priority(0)
	var salve := give_hand(1, "Healing Salve")
	add_mana(1, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, salve, [TargetRef.player(1)]))
	assert_eq(g.stack.size(), 2)
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	# Dies: you gain 3 — the trigger resolves from the graveyard.
	g.destroy(ancestor)
	resolve_stack()
	assert_eq(ancestor.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 24)


func test_auspicious_ancestor_cannot_pay_without_mana() -> void:
	put_battlefield(0, "Auspicious Ancestor")
	me.yes = 1
	var lions := give_hand(0, "Savannah Lions")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, lions, []))
	resolve_stack()
	assert_eq(g.players[0].life, 20)


# ---------------------------------------------------------- Mangara's Equity --

func test_mangaras_equity_returns_damage_from_a_creature_of_the_chosen_color() -> void:
	me.option = 1   # red
	var equity := put_battlefield(0, "Mangara's Equity")
	assert_eq(int(equity.memory.get("chosen_color")), Mtg.ManaColor.R)
	var giant := put_battlefield(1, "Hill Giant")
	var lions := put_battlefield(0, "Savannah Lions")
	g.deal_damage(giant, TargetRef.player(0), 2)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(giant.damage, 2, "that much damage back to the red creature")
	# Damage to a white creature you control triggers too.
	g.deal_damage(giant, TargetRef.card(lions), 1)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	# A black creature is not of the chosen colour.
	var djinn := put_battlefield(1, "Juzám Djinn")
	g.deal_damage(djinn, TargetRef.player(0), 2)
	assert_true(g.stack.is_empty())
	assert_eq(djinn.damage, 0)


func test_mangaras_equity_ignores_damage_to_nonwhite_or_opposing_creatures() -> void:
	me.option = 0   # black
	put_battlefield(0, "Mangara's Equity")
	var djinn := put_battlefield(1, "Juzám Djinn")
	var bears := put_battlefield(0, "Grizzly Bears")
	var foe_lions := put_battlefield(1, "Savannah Lions")
	g.deal_damage(djinn, TargetRef.card(bears), 1)
	g.deal_damage(djinn, TargetRef.card(foe_lions), 1)
	assert_true(g.stack.is_empty())


func test_mangaras_equity_upkeep_costs_one_white_or_it_goes() -> void:
	var equity := put_battlefield(0, "Mangara's Equity")
	me.yes = 1
	_to_upkeep(0)
	add_mana(0, Mtg.ManaColor.W, 2)
	resolve_stack()
	assert_eq(equity.zone, Mtg.Zone.BATTLEFIELD)
	_to_upkeep(0)
	resolve_stack()   # no mana: cannot pay
	assert_eq(equity.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------------- Sacred Mesa --

func test_sacred_mesa_makes_pegasi_and_eats_one_each_upkeep() -> void:
	var mesa := put_battlefield(0, "Sacred Mesa")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.activate_ability(0, mesa, 0))
	resolve_stack()
	var pegasi: Array = g.players[0].battlefield.filter(func(i: CardInstance) -> bool: return i.has_subtype("pegasus"))
	assert_eq(pegasi.size(), 1)
	var pegasus: CardInstance = pegasi[0]
	assert_true(pegasus.is_token and pegasus.has_keyword(Mtg.Keyword.FLYING))
	assert_eq([pegasus.cur_power, pegasus.cur_toughness], [1, 1])
	me.yes = 1
	_to_upkeep(0)
	resolve_stack()
	assert_eq(mesa.zone, Mtg.Zone.BATTLEFIELD, "the Pegasus was sacrificed instead")
	assert_ne(pegasus.zone, Mtg.Zone.BATTLEFIELD)
	_to_upkeep(0)
	resolve_stack()
	assert_eq(mesa.zone, Mtg.Zone.GRAVEYARD, "no Pegasus left: the Mesa goes")


# -------------------------------------------------------- Wall of Resistance --

func test_wall_of_resistance_grows_only_after_being_dealt_damage() -> void:
	var wall := put_battlefield(0, "Wall of Resistance")
	var bolt := give_hand(1, "Lightning Bolt")
	_to_end(0)
	assert_true(g.stack.is_empty(), "undamaged: the intervening if fails")
	advance_to_next_turn()
	g.deal_damage(bolt, TargetRef.card(wall), 2)
	_to_end(1)
	assert_eq(g.stack.size(), 1, "each end step, the opponent's too")
	resolve_stack()
	assert_eq(_counter(wall, "+0/+1"), 1)
	assert_eq(wall.cur_toughness, 4)
	_to_end(0)
	assert_true(g.stack.is_empty(), "last turn's damage does not count")


# ------------------------------------------------------------- Energy Vortex --

func test_energy_vortex_bills_the_chosen_opponent_per_counter() -> void:
	var vortex := put_battlefield(0, "Energy Vortex")
	assert_eq(int(vortex.memory.get("chosen_player")), 1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, vortex, 0, [], 2))
	_to_upkeep(0)
	resolve_stack()
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, vortex, 0, [], 2))
	resolve_stack()
	assert_eq(_counter(vortex, "vortex"), 2)
	# The chosen player's upkeep: pays {2}, takes nothing.
	foe.yes = 1
	_to_upkeep(1)
	add_mana(1, Mtg.ManaColor.C, 2)
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	# Your upkeep clears the counters.
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(vortex, "vortex"), 0)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, vortex, 0, [], 1))
	resolve_stack()
	foe.yes = 0
	_to_upkeep(1)
	add_mana(1, Mtg.ManaColor.C, 2)
	resolve_stack()
	assert_eq(g.players[1].life, 17, "declined: 3 damage")


func test_energy_vortex_with_no_counters_costs_nothing() -> void:
	put_battlefield(0, "Energy Vortex")
	foe.yes = 0
	_to_upkeep(1)
	resolve_stack()
	assert_eq(g.players[1].life, 20, "{0} is always paid")


# ----------------------------------------------------------------- Floodgate --

func test_floodgate_leaving_damages_nonblue_ground_creatures_by_half_your_islands() -> void:
	var gate := put_battlefield(0, "Floodgate")
	for n in 5: put_battlefield(0, "Island")
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var angel := put_battlefield(1, "Serra Angel")
	var merfolk := put_battlefield(0, "Merfolk of the Pearl Trident")
	g.destroy(gate)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "2 damage (5 Islands / 2)")
	assert_eq(giant.damage, 2)
	assert_eq(angel.damage, 0, "flying")
	assert_eq(merfolk.damage, 0, "blue")


func test_floodgate_is_sacrificed_when_it_has_flying() -> void:
	var gate := put_battlefield(0, "Floodgate")
	put_battlefield(0, "Island")
	g.continuous.add_until_eot_keywords(gate.id, [Mtg.Keyword.FLYING])
	g.recalculate()
	g.check_state_based_actions()
	assert_eq(g.stack.size(), 1, "a state trigger (CR 603.8)")
	resolve_stack()
	assert_eq(gate.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------------- Merfolk Seer --

func test_merfolk_seer_may_pay_to_draw_when_it_dies() -> void:
	var seer := put_battlefield(0, "Merfolk Seer")
	var hand := g.players[0].hand.size()
	me.yes = 1
	g.destroy(seer)
	add_mana(0, Mtg.ManaColor.U, 2)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	var second := put_battlefield(0, "Merfolk Seer")
	me.yes = 0
	g.destroy(second)
	add_mana(0, Mtg.ManaColor.U, 2)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "declined")


# -------------------------------------------------------- Harbinger of Night --

func test_harbinger_of_night_shrinks_every_creature_itself_included() -> void:
	var harbinger := put_battlefield(0, "Harbinger of Night")
	var lions := put_battlefield(1, "Savannah Lions")
	var bears := put_battlefield(0, "Grizzly Bears")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(harbinger, "-1/-1"), 1)
	assert_eq(harbinger.cur_toughness, 2)
	assert_eq(bears.cur_power, 1)
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------- Purraj of Urborg --

func test_purraj_has_first_strike_only_while_attacking() -> void:
	var purraj := put_battlefield(0, "Purraj of Urborg")
	assert_false(purraj.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [purraj.id]))
	assert_true(purraj.has_keyword(Mtg.Keyword.FIRST_STRIKE))


func test_purraj_buys_a_counter_with_black_mana_on_any_black_spell() -> void:
	var purraj := put_battlefield(0, "Purraj of Urborg")
	me.yes = 1
	var ritual := give_hand(0, "Dark Ritual")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, ritual, []))
	resolve_stack()
	assert_eq(_counter(purraj, "+1/+1"), 1)
	assert_eq(purraj.cur_power, 3)
	# Purraj gone before the trigger resolves: nothing is offered.
	var second := give_hand(0, "Dark Ritual")
	assert_ok(g.cast_spell(0, second, []))
	var asked := me.asked.size()
	g.destroy(purraj)
	resolve_stack()
	assert_eq(me.asked.size(), asked)


# ---------------------------------------------------------- Ravenous Vampire --

func test_ravenous_vampire_eats_a_creature_or_taps() -> void:
	var vampire := put_battlefield(0, "Ravenous Vampire")
	var bears := put_battlefield(0, "Grizzly Bears")
	var ornithopter := put_battlefield(0, "Ornithopter")
	me.yes = 1
	_to_upkeep(0)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "nonartifact creature eaten")
	assert_eq(ornithopter.zone, Mtg.Zone.BATTLEFIELD, "an artifact creature is not food")
	assert_eq(_counter(vampire, "+1/+1"), 1)
	assert_false(vampire.tapped)
	me.yes = 0
	_to_upkeep(0)
	resolve_stack()
	assert_true(vampire.tapped)


# --------------------------------------------------------- Shauku, Endbringer --

func test_shauku_bleeds_its_controller_and_cannot_attack_beside_another_creature() -> void:
	var shauku := put_battlefield(0, "Shauku, Endbringer")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [shauku.id]))
	assert_ok(g.declare_attackers(0, []))
	_to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, shauku, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.EXILE)
	assert_eq(_counter(shauku, "+1/+1"), 1)


func test_shauku_alone_may_attack() -> void:
	var shauku := put_battlefield(0, "Shauku, Endbringer")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [shauku.id]))


# ---------------------------------------------------------------- Zombie Mob --

func test_zombie_mob_counts_then_exiles_your_creature_cards() -> void:
	var dead: Array = [give_hand(0, "Grizzly Bears"), give_hand(0, "Savannah Lions")]
	var land := give_hand(0, "Forest")
	var foes_dead := give_hand(1, "Hill Giant")
	g.discard_cards(0, dead + [land])
	g.discard_cards(1, [foes_dead])
	var mob := put_battlefield(0, "Zombie Mob")
	assert_eq(_counter(mob, "+1/+1"), 2)
	resolve_stack()
	for c in dead: assert_eq(c.zone, Mtg.Zone.EXILE)
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(foes_dead.zone, Mtg.Zone.GRAVEYARD, "only YOUR graveyard")
	assert_eq(mob.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([mob.cur_power, mob.cur_toughness], [4, 2])


func test_zombie_mob_with_an_empty_graveyard_is_a_zero_toughness_body() -> void:
	var mob := put_battlefield(0, "Zombie Mob")
	g.check_state_based_actions()
	assert_eq(mob.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------- Emberwilde Djinn --

func test_emberwilde_djinn_goes_to_whoever_pays_on_their_upkeep() -> void:
	var djinn := put_battlefield(0, "Emberwilde Djinn")
	foe.option = 0   # P1 has no mana: the only payment offered is 2 life
	_to_upkeep(1)
	resolve_stack()
	assert_eq(djinn.controller_id, 1)
	assert_eq(g.players[1].life, 18)
	# On P0's upkeep, P0 declines; the Djinn stays put.
	me.option = 2
	_to_upkeep(0)
	add_mana(0, Mtg.ManaColor.R, 2)
	resolve_stack()
	assert_eq(djinn.controller_id, 1)
	assert_eq(g.players[0].life, 20)


func test_emberwilde_djinn_can_be_bought_back_with_red_mana() -> void:
	var djinn := put_battlefield(1, "Emberwilde Djinn")
	me.option = 0   # Pay {R}{R}
	_to_upkeep(0)
	add_mana(0, Mtg.ManaColor.R, 2)
	resolve_stack()
	assert_eq(djinn.controller_id, 0)
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 0)


# --------------------------------------------------------------- Afiya Grove --

func test_afiya_grove_hands_out_its_counters_then_leaves() -> void:
	var grove := put_battlefield(0, "Afiya Grove")
	assert_eq(_counter(grove, "+1/+1"), 3)
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(bears, "+1/+1"), 1, "your own creature is the heuristic's target")
	assert_eq(_counter(grove, "+1/+1"), 2)
	g.remove_counters(grove, "+1/+1", 1)
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_counter(bears, "+1/+1"), 2)
	assert_eq(grove.zone, Mtg.Zone.GRAVEYARD, "no counters left: sacrificed (state trigger)")


# --------------------------------------------- Nettletooth Djinn, Benthic Djinn --

func test_nettletooth_and_benthic_djinn_upkeep_costs() -> void:
	put_battlefield(0, "Nettletooth Djinn")
	var benthic := put_battlefield(0, "Benthic Djinn")
	assert_true(benthic.cur_landwalk.has("island"))
	_to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].life, 17, "1 damage and 2 life lost")


func test_nettletooth_djinn_bites_even_after_leaving() -> void:
	var djinn := put_battlefield(0, "Nettletooth Djinn")
	_to_upkeep(0)
	g.return_to_hand(djinn)
	resolve_stack()
	assert_eq(g.players[0].life, 19, "CR 603.6: the trigger exists apart from its source")


# ------------------------------------------------------- Preferred Selection --

func _stack_top(pid: int, names: Array) -> Array:
	var out: Array = []
	for name in names:
		var c := give_hand(pid, name)
		g.put_from_hand_on_top_of_library(c)
		out.append(c)
	return out


func test_preferred_selection_buries_one_of_the_top_two_when_not_paid() -> void:
	put_battlefield(0, "Preferred Selection")
	var top := _stack_top(0, ["Lightning Bolt", "Grizzly Bears"])
	me.yes = 0
	me.prefer = ["Lightning Bolt"]
	_to_upkeep(0)
	resolve_stack()
	var library := g.players[0].library
	assert_eq(library[0], top[0], "the chosen card is on the bottom")
	assert_eq(library.back(), top[1])


func test_preferred_selection_paid_puts_a_card_into_hand() -> void:
	var sel := put_battlefield(0, "Preferred Selection")
	var top := _stack_top(0, ["Lightning Bolt", "Grizzly Bears"])
	me.yes = 1
	me.prefer = ["Lightning Bolt"]
	_to_upkeep(0)
	add_mana(0, Mtg.ManaColor.G, 4)
	resolve_stack()
	assert_eq(sel.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(top[0].zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].library.back(), top[1])


# ------------------------------------------------------------- Roots of Life --

func test_roots_of_life_feeds_on_opposing_lands_of_the_chosen_type() -> void:
	me.option = 1   # Swamp
	var roots := put_battlefield(0, "Roots of Life")
	assert_eq(String(roots.memory.get("land_type")), "swamp")
	var swamp := put_battlefield(1, "Swamp")
	var island := put_battlefield(1, "Island")
	var own := put_battlefield(0, "Swamp")
	g.tap_permanent(swamp)
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	g.tap_permanent(island)
	g.tap_permanent(own)
	assert_true(g.stack.is_empty())
	assert_eq(g.players[0].life, 21)


# --------------------------------------------------------- Discordant Spirit --

func test_discordant_spirit_grows_on_opponents_turns_and_sheds_on_yours() -> void:
	var spirit := put_battlefield(0, "Discordant Spirit")
	var bolt := give_hand(1, "Lightning Bolt")
	g.deal_damage(bolt, TargetRef.player(0), 2)
	_to_end(0)
	resolve_stack()
	assert_eq(_counter(spirit, "+1/+1"), 0, "your own turn: the intervening if fails")
	_to_end(1)
	assert_eq(g.stack.size(), 1)
	g.deal_damage(bolt, TargetRef.player(0), 3)
	resolve_stack()
	assert_eq(_counter(spirit, "+1/+1"), 3, "counted on resolution")
	_to_end(0)
	resolve_stack()
	assert_eq(_counter(spirit, "+1/+1"), 0)


# --------------------------------------------------------- Emberwilde Caliph --

func test_emberwilde_caliph_must_attack_and_costs_its_damage_in_life() -> void:
	var caliph := put_battlefield(0, "Emberwilde Caliph")
	assert_true(caliph.has_keyword(Mtg.Keyword.MUST_ATTACK))
	run_combat([caliph.id])
	resolve_stack()
	assert_eq(g.players[1].life, 16)
	assert_eq(g.players[0].life, 16)


# -------------------------------------------------------------- Zebra Unicorn --

func test_zebra_unicorn_gains_the_damage_it_deals() -> void:
	var zebra := put_battlefield(0, "Zebra Unicorn")
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(zebra, TargetRef.card(giant), 2)
	resolve_stack()
	assert_eq(g.players[0].life, 22)


func test_damage_triggers_read_the_same_under_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	var caliph := put_battlefield(0, "Emberwilde Caliph")
	var zebra := put_battlefield(0, "Zebra Unicorn")
	run_combat([caliph.id, zebra.id])
	resolve_stack()
	assert_eq(g.players[1].life, 14)
	assert_eq(g.players[0].life, 18, "lost 4 to the Caliph, gained 2 from the Unicorn")


# ---------------------------------------------------------------- Grim Feast --

func test_grim_feast_drinks_opposing_creatures_toughness() -> void:
	put_battlefield(0, "Grim Feast")
	var giant := put_battlefield(1, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.destroy(giant)
	resolve_stack()
	assert_eq(g.players[0].life, 23)
	g.destroy(bears)
	assert_true(g.stack.is_empty(), "your own creature feeds nothing")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(g.players[0].life, 22)


func test_grim_feast_reads_last_known_toughness() -> void:
	put_battlefield(0, "Grim Feast")
	var giant := put_battlefield(1, "Hill Giant")
	g.continuous.add_until_eot_pump(giant.id, 0, 2)
	g.recalculate()
	g.destroy(giant)
	resolve_stack()
	assert_eq(g.players[0].life, 25)


# ----------------------------------------------------------------- Purgatory --

func test_purgatory_exiles_your_dead_and_sells_them_back() -> void:
	put_battlefield(0, "Purgatory")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	g.destroy(bears)
	g.destroy(giant)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.EXILE)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "not your graveyard")
	me.yes = 1
	_to_upkeep(0)
	add_mana(0, Mtg.ManaColor.C, 4)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bears.controller_id, 0)
	assert_eq(g.players[0].life, 18)


func test_purgatory_cannot_be_paid_without_two_life_or_four_mana() -> void:
	put_battlefield(0, "Purgatory")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.destroy(bears)
	resolve_stack()
	me.yes = 1
	_to_upkeep(0)
	resolve_stack()   # no mana
	assert_eq(bears.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].life, 20)


# --------------------------------------------------------------- Reparations --

func test_reparations_draws_when_an_opponent_targets_you_or_your_creature() -> void:
	put_battlefield(0, "Reparations")
	var bears := put_battlefield(0, "Grizzly Bears")
	var foe_bears := put_battlefield(1, "Grizzly Bears")
	me.yes = 1
	var hand := g.players[0].hand.size()
	g.pass_priority(0)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bears)]))
	assert_eq(g.stack.size(), 2)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	g.pass_priority(0)
	var second := give_hand(1, "Lightning Bolt")
	assert_ok(g.cast_spell(1, second, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 2)
	g.pass_priority(0)
	var third := give_hand(1, "Lightning Bolt")
	assert_ok(g.cast_spell(1, third, [TargetRef.card(foe_bears)]))
	assert_eq(g.stack.size(), 1, "targets only the caster's own creature")
	resolve_stack()


func test_reparations_ignores_your_own_spells() -> void:
	put_battlefield(0, "Reparations")
	var bears := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bears)]))
	assert_eq(g.stack.size(), 1)
	resolve_stack()


# ----------------------------------------------------- Phyrexian Dreadnought --

func test_phyrexian_dreadnought_alone_is_sacrificed() -> void:
	var dread := put_battlefield(0, "Phyrexian Dreadnought")
	resolve_stack()
	assert_eq(dread.zone, Mtg.Zone.GRAVEYARD)


func test_phyrexian_dreadnought_keeps_for_twelve_power_of_creatures() -> void:
	var wurms := [put_battlefield(0, "Craw Wurm"), put_battlefield(0, "Craw Wurm")]
	var bears := put_battlefield(0, "Grizzly Bears")
	me.yes = 1
	var dread := put_battlefield(0, "Phyrexian Dreadnought")
	resolve_stack()
	assert_eq(dread.zone, Mtg.Zone.BATTLEFIELD)
	for w in wurms: assert_eq(w.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "12 reached: no more needed")


func test_phyrexian_dreadnought_declined_or_short_goes() -> void:
	var wurm := put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Craw Wurm")
	me.yes = 0
	var dread := put_battlefield(0, "Phyrexian Dreadnought")
	resolve_stack()
	assert_eq(dread.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	g.destroy(wurm)
	me.yes = 1
	var second := put_battlefield(0, "Phyrexian Dreadnought")
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "6 power is not 12")


# ---------------------------------------------------------------- Sand Golem --

func test_sand_golem_discarded_by_an_opponent_returns_at_the_next_end_step() -> void:
	var golem := give_hand(0, "Sand Golem")
	var scepter := put_battlefield(1, "Disrupting Scepter")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(1, scepter, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD)
	_to_end(1)
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(golem.controller_id, 0)
	assert_eq(_counter(golem, "+1/+1"), 1)
	assert_eq(golem.cur_power, 4)


func test_sand_golem_discarded_by_its_owner_stays_in_the_graveyard() -> void:
	var golem := give_hand(0, "Sand Golem")
	var scepter := put_battlefield(0, "Disrupting Scepter")
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, scepter, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD)
	_to_end(0)
	resolve_stack()
	assert_eq(golem.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------ Skulking Ghost --

func test_skulking_ghost_is_sacrificed_when_an_opposing_spell_targets_it() -> void:
	var ghost := put_battlefield(0, "Skulking Ghost")
	g.pass_priority(0)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(ghost)]))
	assert_eq(g.stack.size(), 2, "the trigger waits above the spell (CR 601.2c)")
	resolve_stack()
	assert_eq(ghost.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ghost.damage, 0, "sacrificed before the Bolt resolved")
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "the Bolt fizzled")


func test_skulking_ghost_dies_to_its_controllers_own_ability_too() -> void:
	var ghost := put_battlefield(0, "Skulking Ghost")
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.card(ghost)]))
	assert_eq(g.stack.size(), 2)
	resolve_stack()
	assert_eq(ghost.zone, Mtg.Zone.GRAVEYARD)


func test_skulking_ghost_triggers_once_for_one_object_naming_it_twice() -> void:
	var ghost := put_battlefield(0, "Skulking Ghost")
	var twin := put_synthetic(0, CardData.new("Twin Lens", "", Mtg.CardType.ARTIFACT)
		.activated(ActivatedAbility.new("", false, [PumpEffect.new(1, 0), PumpEffect.new(0, 1)],
			"Target creature gets +1/+0 and target creature gets +0/+1.")))
	assert_ok(g.activate_ability(0, twin, 0, [TargetRef.card(ghost), TargetRef.card(ghost)]))
	assert_eq(g.stack.size(), 2, "one ability, one trigger")
	resolve_stack()
	assert_eq(ghost.zone, Mtg.Zone.GRAVEYARD)


func test_skulking_ghost_ignores_untargeted_effects() -> void:
	var ghost := put_battlefield(1, "Skulking Ghost")
	put_battlefield(0, "Aku Djinn")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(ghost.zone, Mtg.Zone.BATTLEFIELD, "a counter on each opposing creature targets nothing")
	assert_eq(_counter(ghost, "+1/+1"), 1)


# ------------------------------------------------------ Asmira, Holy Avenger --

func test_asmira_counts_creatures_put_into_your_graveyard_this_turn() -> void:
	var asmira := put_battlefield(0, "Asmira, Holy Avenger")
	assert_true(asmira.has_keyword(Mtg.Keyword.FLYING))
	var mine := [put_battlefield(0, "Grizzly Bears"), put_battlefield(0, "Savannah Lions")]
	var theirs := put_battlefield(1, "Hill Giant")
	for i in mine + [theirs]: g.destroy(i)
	_to_end(0)
	resolve_stack()
	assert_eq(_counter(asmira, "+1/+1"), 2, "only YOUR graveyard")
	_to_end(1)
	resolve_stack()
	assert_eq(_counter(asmira, "+1/+1"), 2, "a new turn: nothing died")
	advance_to_next_turn()
	var bears := put_battlefield(0, "Grizzly Bears")
	g.destroy(bears)
	_to_end(0)
	resolve_stack()
	assert_eq(_counter(asmira, "+1/+1"), 3, "each end step, counted on resolution")

