extends GameTest
## Pack 9 (the Tempest block), batch B10: the Stronghold instants and
## sorceries in cards/sets/sth/_spells.gd — Bandage, Cannibalize, Crossbow
## Ambush, Death Stroke, Elven Rite, Evacuation, Flame Wave, Leap, Mana Leak,
## Mob Justice, Mogg Infestation, Rebound, Reins of Power, Ruination, Shock,
## Sift, Smite and Temper.

const CLAIMED := ["Bandage", "Cannibalize", "Crossbow Ambush", "Death Stroke", "Elven Rite",
	"Evacuation", "Flame Wave", "Leap", "Mana Leak", "Mob Justice", "Mogg Infestation",
	"Rebound", "Reins of Power", "Ruination", "Shock", "Sift", "Smite", "Temper"]

## A seat that asks for the 1997 damage-prevention window.
class WindowSeat extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true

## Picks the OPTION at [member option] and the card named [member pick].
class Seat extends DecisionAgent:
	var option := -1
	var pick := ""
	func answer_option(g: MtgGame, pid: int, prompt: String, options: Array[String], hint: int) -> int:
		return option if option >= 0 else super(g, pid, prompt, options, hint)
	func answer_card(g: MtgGame, pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		for c in candidates:
			if c.data.card_name == pick: return c
		return super(g, pid, candidates, prompt)

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

func _respond(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# -------------------------------------------------------------------- Bandage --

func test_bandage_prevents_one_and_draws() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var bandage := give_hand(0, "Bandage")
	var bolt := give_hand(0, "Shock")
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, bandage, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "Bandage left, one card drawn")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "1 of Shock's 2 prevented")
	assert_eq(bear.damage, 1)

func test_bandage_on_a_player() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bandage := give_hand(0, "Bandage")
	var shock := give_hand(0, "Shock")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, bandage, [TargetRef.player(1)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, shock, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)

func test_bandage_and_temper_are_prevention_spells_for_the_1997_window() -> void:
	for card_name in ["Bandage", "Temper"]:
		for e in CardRegistry.get_card(card_name).spell_effects:
			assert_true(e.is_damage_prevention, "%s: every effect is of the window's family" % card_name)

func test_1997_window_bandage_saves_the_blocker() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(1, WindowSeat.new())
	var bear := put_battlefield(0, "Grizzly Bears")
	var ogre := put_battlefield(1, "Gray Ogre")
	var bandage := give_hand(1, "Bandage")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {ogre.id: bear.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	_respond(1)
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, bandage, [TargetRef.card(ogre)]))
	_close_window()
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD, "1 of the waiting 2 prevented")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

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


# ---------------------------------------------------------------- Cannibalize --

func test_cannibalize_exiles_one_and_grows_the_other() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(0, "Cannibalize")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear), TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.EXILE, "the hint exiles the opponent's better creature")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(bear.counters.get("+1/+1", 0)), 2)
	assert_eq(_pt(bear), [4, 4])

func test_cannibalize_the_caster_chooses_which_is_exiled() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var seat := Seat.new()
	seat.pick = "Grizzly Bears"
	g.set_agent(0, seat)
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(0, "Cannibalize")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear), TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_eq(int(giant.counters.get("+1/+1", 0)), 2)

func test_cannibalize_needs_two_creatures_of_one_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Hill Giant")
	var spell := give_hand(0, "Cannibalize")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(mine), TargetRef.card(theirs)]), "controller")
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(theirs), TargetRef.card(theirs)]))
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(theirs)]))
	assert_eq(spell.zone, Mtg.Zone.HAND)

func test_cannibalize_with_one_target_gone_still_acts_on_the_other() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var spell := give_hand(0, "Cannibalize")
	var unsummon := give_hand(0, "Unsummon")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear), TargetRef.card(giant)]))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, unsummon, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(bear.zone, Mtg.Zone.EXILE, "the remaining opponent's creature: exile is the hint")

func test_cannibalize_on_own_creatures_keeps_the_better_one() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var spell := give_hand(0, "Cannibalize")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(bear), TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "own creatures: the lesser one is exiled")
	assert_eq(_pt(giant), [5, 5])


# ------------------------------------------------------------ Crossbow Ambush --

func test_crossbow_ambush_gives_reach_to_your_creatures_only() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var theirs := put_battlefield(0, "Gray Ogre")
	var angel := put_battlefield(0, "Serra Angel")
	advance_to_next_turn()   # P1's turn
	var ambush := give_hand(1, "Crossbow Ambush")
	_respond(1)
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, ambush, []))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.REACH))
	assert_false(theirs.has_keyword(Mtg.Keyword.REACH))
	var later := put_battlefield(1, "Hill Giant")
	g.recalculate()
	assert_false(later.has_keyword(Mtg.Keyword.REACH), "fixed as it resolved (CR 611.2c)")
	assert_eq(CombatState.block_illegality(g, bear, angel, 1), "", "a reach creature may block a flier")
	assert_ne(CombatState.block_illegality(g, later, angel, 1), "")
	advance_to_next_turn()
	assert_false(bear.has_keyword(Mtg.Keyword.REACH), "until end of turn")


# ---------------------------------------------------------------- Death Stroke --

func test_death_stroke_destroys_a_tapped_creature_only() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(1, "Grizzly Bears")
	g.tap_permanent(giant)
	var stroke := give_hand(0, "Death Stroke")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, stroke, [TargetRef.card(bear)]), "tapped")
	assert_ok(g.cast_spell(0, stroke, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_death_stroke_fizzles_if_the_creature_untaps() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	g.tap_permanent(giant)
	var stroke := give_hand(0, "Death Stroke")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, stroke, [TargetRef.card(giant)]))
	g.untap_permanent(giant)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "no longer a legal target (CR 608.2b)")


# ----------------------------------------------------------------- Elven Rite --

func test_elven_rite_divides_two_counters() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var ogre := put_battlefield(0, "Gray Ogre")
	var rite := give_hand(0, "Elven Rite")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, rite, [TargetRef.card(bear).with_amount(1), TargetRef.card(ogre).with_amount(1)]))
	resolve_stack()
	assert_eq(_pt(bear), [3, 3])
	assert_eq(_pt(ogre), [3, 3])

func test_elven_rite_both_on_one() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var rite := give_hand(0, "Elven Rite")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, rite, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 2)

func test_elven_rite_refuses_a_bad_division() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var ogre := put_battlefield(0, "Gray Ogre")
	var giant := put_battlefield(0, "Hill Giant")
	var rite := give_hand(0, "Elven Rite")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, rite, [TargetRef.card(bear).with_amount(2), TargetRef.card(ogre).with_amount(1)]))
	assert_refused(g.cast_spell(0, rite, [TargetRef.card(bear), TargetRef.card(ogre), TargetRef.card(giant)]))
	assert_eq(rite.zone, Mtg.Zone.HAND)


# ----------------------------------------------------------------- Evacuation --

func test_evacuation_returns_every_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var crusade := put_battlefield(0, "Crusade")
	var token: CardInstance = g.create_token(1, CardData.new("Goblin", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	var evac := give_hand(0, "Evacuation")
	add_mana(0, Mtg.ManaColor.U, 5)
	assert_ok(g.cast_spell(0, evac, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_true(g.players[1].hand.has(giant), "to its OWNER's hand")
	assert_false(g.players[1].battlefield.has(token))
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD, "not a creature")


# ----------------------------------------------------------------- Flame Wave --

func test_flame_wave_hits_the_player_and_their_creatures() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var wurm := put_battlefield(1, "Shivan Dragon")
	var mine := put_battlefield(0, "Grizzly Bears")
	var wave := give_hand(0, "Flame Wave")
	add_mana(0, Mtg.ManaColor.R, 7)
	assert_refused(g.cast_spell(0, wave, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, wave, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "5/5 survives 4")
	assert_eq(wurm.damage, 4)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 20)


# ----------------------------------------------------------------------- Leap --

func test_leap_grants_flying_and_draws() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var leap := give_hand(0, "Leap")
	var hand := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, leap, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(g.players[0].hand.size(), hand)
	advance_to_next_turn()
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING))

func test_leap_on_a_gone_creature_still_draws_nothing_extra() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var leap := give_hand(0, "Leap")
	var unsummon := give_hand(0, "Unsummon")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(0, leap, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, unsummon, [TargetRef.card(bear)]))
	var hand := g.players[0].hand.size()
	resolve_stack()
	assert_eq(leap.zone, Mtg.Zone.GRAVEYARD, "its only target gone, it is countered (CR 608.2b)")
	assert_eq(g.players[0].hand.size(), hand + 1, "only the Bears came back — no draw")


# ------------------------------------------------------------------ Mana Leak --

func test_mana_leak_counters_unless_its_controller_pays_three() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bears := give_hand(0, "Grizzly Bears")
	var leak := give_hand(1, "Mana Leak")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	_respond(1)
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, leak, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "nothing left to pay with")

func test_mana_leak_paid_lets_the_spell_resolve() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bears := give_hand(0, "Grizzly Bears")
	var leak := give_hand(1, "Mana Leak")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	add_mana(0, Mtg.ManaColor.C, 3)
	_respond(1)
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, leak, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 0, "the {3} was paid")


# ---------------------------------------------------------------- Mob Justice --

func test_mob_justice_counts_your_creatures() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	for name in ["Grizzly Bears", "Gray Ogre", "Hill Giant"]: put_battlefield(0, name)
	put_battlefield(1, "Craw Wurm")
	var mob := give_hand(0, "Mob Justice")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, mob, [TargetRef.card(g.players[1].battlefield[0])]))
	assert_ok(g.cast_spell(0, mob, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)

func test_mob_justice_with_no_creatures_deals_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mob := give_hand(0, "Mob Justice")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, mob, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)


# ----------------------------------------------------------- Mogg Infestation --

func _goblins(pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_token and i.data.card_name == "Goblin": out.append(i)
	return out

func test_mogg_infestation_replaces_the_dead_with_goblins() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var mine := put_battlefield(0, "Gray Ogre")
	var infest := give_hand(0, "Mogg Infestation")
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, infest, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	var goblins := _goblins(1)
	assert_eq(goblins.size(), 4, "two for each creature that died")
	assert_eq(_pt(goblins[0]), [1, 1])
	assert_true((goblins[0].cur_colors & Mtg.ManaColor.R) != 0)
	assert_eq(_goblins(0).size(), 0)

func test_mogg_infestation_a_regenerated_creature_did_not_die() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var skeleton := put_battlefield(1, "Drudge Skeletons")
	skeleton.regeneration_shields = 1   # setup: a shield already up
	var token: CardInstance = g.create_token(1, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	var infest := give_hand(0, "Mogg Infestation")
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, infest, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(skeleton.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_false(g.players[1].battlefield.has(token))
	assert_eq(_goblins(1).size(), 2, "only the token died (a token dies too)")


# -------------------------------------------------------------------- Rebound --

func test_rebound_turns_a_spell_aimed_at_a_player_onto_another_player() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var shock := give_hand(0, "Shock")
	var rebound := give_hand(1, "Rebound")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, shock, [TargetRef.player(1)]))
	_respond(1)
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, rebound, [TargetRef.card(shock)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].life, 18)

func test_rebound_refuses_a_spell_aimed_at_a_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var shock := give_hand(0, "Shock")
	var rebound := give_hand(1, "Rebound")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, shock, [TargetRef.card(bear)]))
	_respond(1)
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_refused(g.cast_spell(1, rebound, [TargetRef.card(shock)]))
	assert_eq(rebound.zone, Mtg.Zone.HAND)

func test_rebound_on_an_untargeted_spell_is_refused() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bears := give_hand(0, "Grizzly Bears")
	var rebound := give_hand(1, "Rebound")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bears, []))
	_respond(1)
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_refused(g.cast_spell(1, rebound, [TargetRef.card(bears)]))


# ------------------------------------------------------------- Reins of Power --

func test_reins_of_power_swaps_the_creatures_until_end_of_turn() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	g.tap_permanent(bear)
	g.tap_permanent(giant)
	var reins := give_hand(0, "Reins of Power")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_refused(g.cast_spell(0, reins, [TargetRef.player(0)]))
	assert_ok(g.cast_spell(0, reins, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(giant.controller_id, 0)
	assert_eq(bear.controller_id, 1)
	assert_false(giant.tapped)
	assert_false(bear.tapped)
	assert_true(giant.has_keyword(Mtg.Keyword.HASTE))
	assert_true(bear.has_keyword(Mtg.Keyword.HASTE))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_next_turn()
	assert_eq(giant.controller_id, 1, "home at cleanup")
	assert_eq(bear.controller_id, 0)

func test_reins_of_power_leaves_later_creatures_alone() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var reins := give_hand(0, "Reins of Power")
	put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, reins, [TargetRef.player(1)]))
	resolve_stack()
	var late := put_battlefield(1, "Gray Ogre")
	g.recalculate()
	assert_eq(late.controller_id, 1)


# ------------------------------------------------------------------ Ruination --

func test_ruination_destroys_only_nonbasic_lands() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var badlands := put_battlefield(0, "Badlands")
	var forest := put_battlefield(0, "Forest")
	var island := put_battlefield(1, "Volcanic Island")
	var mountain := put_battlefield(1, "Mountain")
	var ruin := give_hand(0, "Ruination")
	add_mana(0, Mtg.ManaColor.R, 4)
	assert_ok(g.cast_spell(0, ruin, []))
	resolve_stack()
	assert_eq(badlands.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(island.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(mountain.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------------- Shock --

func test_shock_deals_two_to_any_target() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var a := give_hand(0, "Shock")
	var b := give_hand(0, "Shock")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, a, [TargetRef.card(bear)]))
	assert_ok(g.cast_spell(0, b, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)


# ----------------------------------------------------------------------- Sift --

func test_sift_draws_three_then_discards_one() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var sift := give_hand(0, "Sift")
	var hand := g.players[0].hand.size()
	var library := g.players[0].library.size()
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, sift, []))
	resolve_stack()
	assert_eq(g.players[0].library.size(), library - 3)
	assert_eq(g.players[0].hand.size(), hand - 1 + 3 - 1)
	assert_eq(g.players[0].graveyard.size(), 2, "Sift and the discarded card")


# ---------------------------------------------------------------------- Smite --

func test_smite_destroys_a_blocked_creature_only() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ogre := put_battlefield(0, "Gray Ogre")
	var wall := put_battlefield(1, "Wall of Wood")
	var smite := give_hand(1, "Smite")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, ogre.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: bear.id}))
	_respond(1)
	add_mana(1, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(1, smite, [TargetRef.card(ogre)]), "blocked")
	assert_refused(g.cast_spell(1, smite, [TargetRef.card(wall)]), "blocked")
	assert_ok(g.cast_spell(1, smite, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_smite_is_refused_outside_combat() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var smite := give_hand(0, "Smite")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, smite, [TargetRef.card(bear)]))


# --------------------------------------------------------------------- Temper --

func test_temper_prevents_x_and_grows_a_counter_per_point() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var temper := give_hand(0, "Temper")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.W, 4)
	assert_ok(g.cast_spell(0, temper, [TargetRef.card(bear)], 2))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(bear.counters.get("+1/+1", 0)), 2, "one counter per point prevented")
	assert_eq(bear.damage, 1)
	assert_eq(_pt(bear), [4, 4])

func test_temper_leftover_points_wait_for_more_damage_this_turn() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var temper := give_hand(0, "Temper")
	var shock := give_hand(0, "Shock")
	add_mana(0, Mtg.ManaColor.W, 5)
	assert_ok(g.cast_spell(0, temper, [TargetRef.card(bear)], 3))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, shock, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(int(bear.counters.get("+1/+1", 0)), 2)
	assert_eq(bear.damage, 0)
	assert_eq(g.damage_effects.size(), 1, "one point left this turn")
	advance_to_next_turn()
	assert_eq(g.damage_effects.size(), 0, "this turn only")

func test_temper_with_x_zero_does_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var temper := give_hand(0, "Temper")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, temper, [TargetRef.card(bear)], 0))
	resolve_stack()
	assert_eq(g.damage_effects.size(), 0)

func test_1997_window_temper_soaks_waiting_damage_into_counters() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(1, WindowSeat.new())
	var giant := put_battlefield(0, "Hill Giant")
	var ogre := put_battlefield(1, "Gray Ogre")
	var temper := give_hand(1, "Temper")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {ogre.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	_respond(1)
	add_mana(1, Mtg.ManaColor.W, 4)
	assert_ok(g.cast_spell(1, temper, [TargetRef.card(ogre)], 2))
	_close_window()
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD, "2 of the giant's 3 prevented")
	assert_eq(int(ogre.counters.get("+1/+1", 0)), 2)
