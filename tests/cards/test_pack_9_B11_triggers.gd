extends GameTest
## Pack 9 (the Tempest block), batch B11: the Exodus triggers of
## cards/sets/exo/_triggers.gd — each card's trigger, its condition (the
## intervening "if"s rechecked), the "may"s answered both ways, targets
## chosen as the trigger goes on the stack, and the source leaving.
## Pandemonium uses engine package E7 (TriggeredAbility.chosen_by).

const CLAIMED := ["Anarchist", "Avenging Druid", "Carnophage", "Cartographer", "Convalescence",
	"Equilibrium", "Grollub", "Jackalope Herd", "Mana Breach", "Manabond", "Mind Maggots",
	"Mirozel", "Onslaught", "Pandemonium", "Pit Spawn", "Ravenous Baboons", "School of Piranha",
	"Scrivener", "Soul Warden", "Spellshock", "Treasure Hunter", "Welkin Hawk", "Zealots en-Dal"]

## Answers every yes/no with [member yes] and every number/option with
## [member option] (-1 = the hint); remembers the prompts.
class Seat extends DecisionAgent:
	var yes := true
	var option := -1
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes
	func answer_option(_g: MtgGame, _pid: int, prompt: String, _options: Array[String], hint: int) -> int:
		asked.append(prompt)
		return hint if option < 0 else option

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)

func _seat(pid: int, yes := true) -> Seat:
	var s := Seat.new()
	s.yes = yes
	g.set_agent(pid, s)
	return s

## [param pid]'s next upkeep, with its triggers on the stack.
func _to_upkeep_of(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)

func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card

func _hand_of(pid: int, names: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for n in names: out.append(give_hand(pid, n))
	return out

func _cast_bears(pid: int, extra := 0) -> CardInstance:
	var bears := give_hand(pid, "Grizzly Bears")
	add_mana(pid, Mtg.ManaColor.G, 2 + extra)
	assert_ok(g.cast_spell(pid, bears))
	return bears

## P0 attacks with [param attacker]; P1 blocks with [param blocker] (or not).
func _combat(attacker: CardInstance, blocker: CardInstance = null) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {} if blocker == null else {blocker.id: attacker.id}))
	resolve_stack()

func _count(pid: int, card_name: String) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: n += 1
	return n


func test_claimed_cards_are_no_longer_pending() -> void:
	for name in CLAIMED:
		var c := CardRegistry.get_card(name)
		assert_not_null(c, name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", name)
		assert_false(c.triggered_abilities.is_empty(), "%s has its trigger" % name)


# --- Anarchist, Cartographer, Scrivener, Treasure Hunter ----------------------

func test_salvagers_return_their_kind_of_card() -> void:
	var rows := [["Anarchist", "Wrath of God"], ["Cartographer", "Forest"],
		["Scrivener", "Lightning Bolt"], ["Treasure Hunter", "Sol Ring"]]
	for row in rows:
		var wanted := _to_graveyard(0, row[1])
		var other := _to_graveyard(0, "Grizzly Bears")
		put_battlefield(0, row[0])
		assert_eq(g.stack.size(), 1, "%s triggers" % row[0])
		var item: StackItem = g.stack.back()
		assert_eq(item.targets[0].instance_id, wanted.id, row[0])
		resolve_stack()
		assert_eq(wanted.zone, Mtg.Zone.HAND, row[0])
		assert_eq(other.zone, Mtg.Zone.GRAVEYARD, row[0])

func test_salvager_without_a_legal_card_does_not_trigger() -> void:
	_to_graveyard(0, "Grizzly Bears")
	_to_graveyard(1, "Wrath of God")   # an opponent's graveyard is not "your graveyard"
	put_battlefield(0, "Anarchist")
	assert_true(g.stack.is_empty())

func test_salvager_may_decline() -> void:
	var seat := _seat(0, false)
	var bolt := _to_graveyard(0, "Lightning Bolt")
	put_battlefield(0, "Scrivener")
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(seat.asked.size(), 1)

func test_salvager_target_gone_by_resolution_fizzles() -> void:
	var land := _to_graveyard(0, "Forest")
	put_battlefield(0, "Cartographer")
	g.exile_from_graveyard(land)
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.EXILE)


# --- Avenging Druid ---------------------------------------------------------------

func test_avenging_druid_digs_to_a_land_when_it_hits_an_opponent() -> void:
	var druid := put_battlefield(0, "Avenging Druid")
	var bears := give_hand(0, "Grizzly Bears")
	g.put_from_hand_on_top_of_library(bears)
	var bolt := give_hand(0, "Lightning Bolt")
	g.put_from_hand_on_top_of_library(bolt)
	var seen: Array = []
	g.information_revealed.connect(func(viewer: int, _title: String, names: Array) -> void:
		seen.append([viewer, names.duplicate()]))
	_combat(druid)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 19)
	assert_eq(seen, [[-1, ["Lightning Bolt", "Grizzly Bears", "Forest"]]], "revealed to everyone")
	assert_eq(_count(0, "Forest"), 1, "the land entered")
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)

func test_avenging_druid_may_decline_and_ignores_blocked_damage() -> void:
	var seat := _seat(0, false)
	var druid := put_battlefield(0, "Avenging Druid")
	var library := g.players[0].library.size()
	_combat(druid)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(seat.asked.size(), 1)
	assert_eq(g.players[0].library.size(), library, "declined: nothing revealed")
	advance_to_next_turn()
	advance_to_next_turn()
	var wall := put_battlefield(1, "Wall of Wood")
	seat.asked.clear()
	_combat(druid, wall)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(seat.asked.size(), 0, "damage to a creature does not trigger it")


# --- Carnophage -----------------------------------------------------------------

func test_carnophage_pays_a_life_or_taps() -> void:
	var seat := _seat(0, true)
	var phage := put_battlefield(0, "Carnophage")
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	assert_false(phage.tapped)
	seat.yes = false
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	assert_true(phage.tapped)

func test_carnophage_heuristic_keeps_low_life() -> void:
	var phage := put_battlefield(0, "Carnophage")
	g.players[0].life = 4
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(g.players[0].life, 4)
	assert_true(phage.tapped)


# --- Convalescence --------------------------------------------------------------

func test_convalescence_gains_one_at_ten_or_less() -> void:
	put_battlefield(0, "Convalescence")
	g.players[0].life = 10
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(g.players[0].life, 11)
	_to_upkeep_of(0)
	assert_true(g.stack.is_empty(), "eleven life: no trigger")

func test_convalescence_rechecks_its_if_on_resolution() -> void:
	put_battlefield(0, "Convalescence")
	g.players[0].life = 9
	_to_upkeep_of(0)
	assert_eq(g.stack.size(), 1)
	g.adjust_life(0, 3)
	resolve_stack()
	assert_eq(g.players[0].life, 12, "the intervening if failed on resolution (CR 603.4)")


# --- Equilibrium ----------------------------------------------------------------

func test_equilibrium_pays_one_to_bounce_on_a_creature_spell() -> void:
	put_battlefield(0, "Equilibrium")
	var wurm := put_battlefield(1, "Craw Wurm")
	var bears := _cast_bears(0, 1)
	assert_eq(g.stack.size(), 2, "the trigger waits above the creature spell")
	var item: StackItem = g.stack.back()
	assert_eq(item.targets[0].instance_id, wurm.id, "an opposing creature first")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.HAND)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)

func test_equilibrium_cannot_pay_and_ignores_other_spells() -> void:
	put_battlefield(0, "Equilibrium")
	var wurm := put_battlefield(1, "Craw Wurm")
	_cast_bears(0)   # no mana left for the {1}
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(g.stack.size(), 1, "a noncreature spell does not trigger it")
	resolve_stack()
	advance_to_next_turn()   # P1's main phase
	var theirs := give_hand(1, "Grizzly Bears")
	add_mana(1, Mtg.ManaColor.G, 3)
	assert_ok(g.cast_spell(1, theirs))
	assert_eq(g.stack.size(), 1, "an opponent's creature spell does not trigger it")
	resolve_stack()


# --- Grollub ----------------------------------------------------------------------

func test_grollub_feeds_its_opponents_the_damage() -> void:
	var grollub := put_battlefield(0, "Grollub")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(grollub)]))
	resolve_stack()
	assert_eq(grollub.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 23, "the trigger resolves after Grollub died")
	assert_eq(g.players[0].life, 20)


# --- Jackalope Herd --------------------------------------------------------------

func test_jackalope_herd_goes_home_when_you_cast_a_spell() -> void:
	var herd := put_battlefield(0, "Jackalope Herd")
	var theirs := put_battlefield(1, "Jackalope Herd")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(herd.zone, Mtg.Zone.HAND)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD, "only its controller's spells")
	assert_eq(g.players[1].life, 17)


# --- Mana Breach ------------------------------------------------------------------

func test_mana_breach_returns_a_land_of_the_caster() -> void:
	put_battlefield(1, "Mana Breach")
	var tapped := put_battlefield(0, "Forest")
	var untapped := put_battlefield(0, "Forest")
	tapped.tapped = true
	_cast_bears(0)
	resolve_stack()
	assert_eq(tapped.zone, Mtg.Zone.HAND, "the caster's heuristic returns the tapped land")
	assert_eq(untapped.zone, Mtg.Zone.BATTLEFIELD)

func test_mana_breach_with_no_land_does_nothing() -> void:
	put_battlefield(0, "Mana Breach")
	var theirs := put_battlefield(1, "Forest")
	_cast_bears(0)
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD, "only the caster returns a land")


# --- Manabond -----------------------------------------------------------------------

func test_manabond_drops_a_hand_of_lands() -> void:
	put_battlefield(0, "Manabond")
	var lands := _hand_of(0, ["Forest", "Forest"])
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	for land in lands: assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].hand.size(), 0)

func test_manabond_heuristic_keeps_a_mixed_hand_and_a_yes_discards_the_rest() -> void:
	put_battlefield(0, "Manabond")
	var cards := _hand_of(0, ["Forest", "Grizzly Bears"])
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(cards[0].zone, Mtg.Zone.HAND, "the hint declines a mixed hand")
	advance_to_next_turn()
	advance_to_next_turn()
	_seat(0, true)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(cards[0].zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD, "then discard the hand")

func test_manabond_only_at_its_controllers_end_step() -> void:
	put_battlefield(1, "Manabond")
	give_hand(1, "Forest")
	advance_to_step(Mtg.Step.END)
	assert_true(g.stack.is_empty())


# --- Mind Maggots -------------------------------------------------------------------

func test_mind_maggots_eats_creature_cards_for_counters() -> void:
	var cards := _hand_of(0, ["Craw Wurm", "Grizzly Bears", "Forest"])
	var maggots := put_battlefield(0, "Mind Maggots")
	resolve_stack()
	assert_eq(cards[0].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(cards[1].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(cards[2].zone, Mtg.Zone.HAND, "only creature cards")
	assert_eq(int(maggots.counters.get("+1/+1", 0)), 4)
	assert_eq([maggots.cur_power, maggots.cur_toughness], [6, 6])

func test_mind_maggots_any_number_includes_none() -> void:
	var seat := _seat(0)
	seat.option = 0
	var bears := give_hand(0, "Grizzly Bears")
	var maggots := put_battlefield(0, "Mind Maggots")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(int(maggots.counters.get("+1/+1", 0)), 0)


# --- Mirozel -------------------------------------------------------------------------

func test_mirozel_returns_when_targeted_and_the_spell_fizzles() -> void:
	var mirozel := put_battlefield(0, "Mirozel")
	assert_true(mirozel.has_keyword(Mtg.Keyword.FLYING))
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))   # P1 receives priority in P0's main phase
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(mirozel)]))
	assert_eq(g.stack.size(), 2, "the trigger waits above the Bolt")
	resolve_stack()
	assert_eq(mirozel.zone, Mtg.Zone.HAND)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "the Bolt fizzled")
	assert_eq(g.players[0].life, 20)


# --- Onslaught -----------------------------------------------------------------------

func test_onslaught_taps_a_creature_when_you_cast_a_creature_spell() -> void:
	put_battlefield(0, "Onslaught")
	var mine := put_battlefield(0, "Hill Giant")
	var theirs := put_battlefield(1, "Craw Wurm")
	_cast_bears(0)
	resolve_stack()
	assert_true(theirs.tapped, "an untapped opposing creature first")
	assert_false(mine.tapped)

func test_onslaught_needs_a_creature_to_target() -> void:
	put_battlefield(0, "Onslaught")
	_cast_bears(0)
	assert_eq(g.stack.size(), 1, "no creature on the battlefield: the trigger is removed (CR 603.3d)")
	resolve_stack()


# --- Pandemonium ---------------------------------------------------------------------

func test_pandemonium_the_entering_creatures_controller_aims_it() -> void:
	put_battlefield(0, "Pandemonium")
	put_battlefield(1, "Hill Giant")
	assert_eq(g.stack.size(), 1)
	var item: StackItem = g.stack.back()
	assert_eq(item.controller, 0, "Pandemonium's controller controls the trigger")
	assert_eq(g.trigger_chooser(item), 1, "the creature's controller chooses")
	assert_true(item.targets[0].is_player and item.targets[0].player_id == 0)
	resolve_stack()
	assert_eq(g.players[0].life, 17, "the Giant's 3 power")

func test_pandemonium_may_is_the_choosers() -> void:
	var mine := _seat(0, true)
	var theirs := _seat(1, false)
	put_battlefield(0, "Pandemonium")
	put_battlefield(1, "Hill Giant")
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the chooser declined")
	assert_eq(mine.asked.size(), 0, "Pandemonium's controller is asked nothing")
	assert_eq(theirs.asked.size(), 2, "the chooser names the target, then answers the may")
	assert_string_contains(theirs.asked.back(), "Pandemonium: have Hill Giant deal 3 damage")

func test_pandemonium_uses_last_known_power_and_skips_zero() -> void:
	put_battlefield(0, "Pandemonium")
	var giant := put_battlefield(0, "Hill Giant")
	assert_eq(g.stack.size(), 1)
	g.continuous.add_until_eot_pump(giant.id, 2, 0, [])
	g.recalculate()
	g.destroy(giant)
	resolve_stack()
	assert_eq(g.players[1].life, 15, "five: its power as it last existed (CR 608.2h)")
	put_battlefield(0, "Wall of Wood")
	resolve_stack()
	assert_eq(g.players[1].life, 15, "a 0-power creature deals nothing")

func test_pandemonium_ai_chooser_names_a_target() -> void:
	put_battlefield(0, "Pandemonium")
	g.agents[1] = AiPlayer.new(1)
	put_battlefield(1, "Hill Giant")
	assert_eq(g.stack.size(), 1)
	var ref: TargetRef = g.stack.back().targets[0]
	assert_true(ref.is_player and ref.player_id == 0, "the AI aims at its opponent first")


# --- Pit Spawn -----------------------------------------------------------------------

func test_pit_spawn_upkeep_costs_two_black() -> void:
	var spawn := put_battlefield(0, "Pit Spawn")
	assert_true(spawn.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	_to_upkeep_of(0)
	add_mana(0, Mtg.ManaColor.B, 2)
	resolve_stack()
	assert_eq(spawn.zone, Mtg.Zone.BATTLEFIELD)
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(spawn.zone, Mtg.Zone.GRAVEYARD, "unpaid: sacrificed")

func test_pit_spawn_exiles_a_creature_it_damaged() -> void:
	var spawn := put_battlefield(0, "Pit Spawn")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	skeletons.regeneration_shields = 1
	_combat(spawn, skeletons)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(skeletons.zone, Mtg.Zone.EXILE, "regenerated, then exiled by the trigger")

func test_pit_spawn_a_creature_that_died_stays_in_the_graveyard() -> void:
	var spawn := put_battlefield(0, "Pit Spawn")
	var bears := put_battlefield(1, "Grizzly Bears")
	_combat(spawn, bears)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_true(CardRegistry.get_card("Pit Spawn").triggered_abilities[1].forecast_safe)


# --- Ravenous Baboons ----------------------------------------------------------------

func test_ravenous_baboons_destroy_a_nonbasic_land() -> void:
	var city := put_battlefield(1, "City of Traitors")
	var forest := put_battlefield(1, "Forest")
	put_battlefield(0, "Ravenous Baboons")
	resolve_stack()
	assert_eq(city.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)

func test_ravenous_baboons_basics_only_no_trigger_and_own_nonbasic_is_forced() -> void:
	put_battlefield(1, "Forest")
	put_battlefield(0, "Ravenous Baboons")
	assert_true(g.stack.is_empty(), "no nonbasic land: no target")
	var mine := put_battlefield(0, "City of Traitors")
	put_battlefield(0, "Ravenous Baboons")
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "mandatory: its own is the only target")


# --- School of Piranha ---------------------------------------------------------------

func test_school_of_piranha_upkeep() -> void:
	var school := put_battlefield(0, "School of Piranha")
	_to_upkeep_of(0)
	add_mana(0, Mtg.ManaColor.U, 2)
	resolve_stack()
	assert_eq(school.zone, Mtg.Zone.BATTLEFIELD)
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(school.zone, Mtg.Zone.GRAVEYARD)


# --- Soul Warden ---------------------------------------------------------------------

func test_soul_warden_gains_for_each_other_creature() -> void:
	put_battlefield(0, "Soul Warden")
	assert_true(g.stack.is_empty(), "not for itself")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	resolve_stack()
	assert_eq(g.players[0].life, 22)
	assert_eq(g.players[1].life, 20)


# --- Spellshock ---------------------------------------------------------------------

func test_spellshock_burns_each_caster() -> void:
	put_battlefield(1, "Spellshock")
	_cast_bears(0)
	resolve_stack()
	assert_eq(g.players[0].life, 18)
	var bolt := give_hand(1, "Lightning Bolt")
	assert_ok(g.pass_priority(0))   # P1 receives priority
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "its own controller too")
	assert_eq(g.players[0].life, 15)


# --- Welkin Hawk ---------------------------------------------------------------------

func test_welkin_hawk_fetches_another_hawk_when_it_dies() -> void:
	_seat(0, true)
	var next := give_hand(0, "Welkin Hawk")
	g.put_from_hand_on_top_of_library(next)
	var seen: Array = []
	g.information_revealed.connect(func(viewer: int, _title: String, names: Array) -> void:
		seen.append([viewer, names.duplicate()]))
	var hawk := put_battlefield(0, "Welkin Hawk")
	g.destroy(hawk)
	resolve_stack()
	assert_eq(next.zone, Mtg.Zone.HAND)
	assert_eq(seen, [[-1, ["Welkin Hawk"]]], "revealed")

func test_welkin_hawk_hint_reads_the_decklist_only() -> void:
	# The test decklist is thirty Forests: no other Welkin Hawk is
	# unaccounted for, so the heuristic does not search — whatever the
	# hidden library holds (fair information, docs/fair-play.md).
	var next := give_hand(0, "Welkin Hawk")
	g.put_from_hand_on_top_of_library(next)
	var hawk := put_battlefield(0, "Welkin Hawk")
	g.destroy(hawk)
	resolve_stack()
	assert_eq(next.zone, Mtg.Zone.LIBRARY)
	for n in 3: g.players[0].deck_names.append("Welkin Hawk")
	hawk = put_battlefield(0, "Welkin Hawk")
	g.destroy(hawk)
	resolve_stack()
	assert_eq(next.zone, Mtg.Zone.HAND, "three in the list, two seen in the graveyard: one unaccounted for")

func test_welkin_hawk_may_decline() -> void:
	_seat(0, false)
	var next := give_hand(0, "Welkin Hawk")
	g.put_from_hand_on_top_of_library(next)
	var hawk := put_battlefield(0, "Welkin Hawk")
	g.destroy(hawk)
	resolve_stack()
	assert_eq(next.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), next, "no search, no shuffle")


# --- Zealots en-Dal ------------------------------------------------------------------

func test_zealots_en_dal_gains_while_all_nonland_permanents_are_white() -> void:
	put_battlefield(0, "Zealots en-Dal")
	put_battlefield(0, "Forest")
	_to_upkeep_of(0)
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	put_battlefield(0, "Grizzly Bears")
	_to_upkeep_of(0)
	assert_true(g.stack.is_empty(), "a green permanent: no trigger")

func test_zealots_en_dal_rechecks_its_if_on_resolution() -> void:
	put_battlefield(0, "Zealots en-Dal")
	_to_upkeep_of(0)
	assert_eq(g.stack.size(), 1)
	put_battlefield(0, "Grizzly Bears")   # in response
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the intervening if failed on resolution (CR 603.4)")
