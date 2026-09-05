extends GameTest
## Wave-65 tests: the CHOICE-HEAVY cards the ROADMAP had parked behind "the
## missing await-based human prompt" — Balance, Juxtapose, Gauntlets of
## Chaos, Nebuchadnezzar and Season of the Witch — plus the two engine
## pieces they wanted: MtgGame.exchange_control (CR 701.10) and
## MtgGame.current_targets (a sibling target slot). The engine tests for
## both live in tests/unit/test_engine_additions.gd.


## Answers a CARD question by name, so a test can say which permanent a
## player gives up. Falls back to the first candidate.
class PickByName extends DecisionAgent:
	var wanted := ""

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null if candidates.is_empty() else candidates[0]


## Picks an OPTION by its label (the named card), else the first.
class NameSaying extends DecisionAgent:
	var says := ""

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], _hint: int) -> int:
		var i := options.find(says)
		return i if i >= 0 else 0


## Always says no to a yes/no question (declines the upkeep rent).
class Skinflint extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return false


func _pick(pid: int, card_name: String) -> PickByName:
	var agent := PickByName.new()
	agent.wanted = card_name
	g.set_agent(pid, agent)
	return agent


func test_registry_loaded_wave65() -> void:
	for name in ["Balance", "Juxtapose", "Gauntlets of Chaos",
			"Nebuchadnezzar", "Season of the Witch"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ------------------------------------------------------------- Balance --

func test_balance_levels_lands_down_to_the_smallest_board() -> void:
	for _i in 3:
		put_battlefield(0, "Forest")
	put_battlefield(1, "Forest")
	var balance := give_hand(0, "Balance")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, balance, []))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 1, "down to the fewest lands")
	assert_eq(g.players[1].battlefield.size(), 1, "the smallest board is untouched")


func test_balance_levels_creatures_and_hands_too() -> void:
	for _i in 2:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	for _i in 3:
		give_hand(0, "Forest")
	give_hand(1, "Forest")
	var balance := give_hand(0, "Balance")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, balance, []))
	resolve_stack()
	var mine := 0
	for inst in g.players[0].battlefield:
		if inst.is_creature():
			mine += 1
	assert_eq(mine, 1, "creatures levelled to the fewest")
	# Balance left p0's hand as it went on the stack: 3 Forests vs 1.
	assert_eq(g.players[0].hand.size(), 1, "hands levelled to the smallest")
	assert_eq(g.players[1].hand.size(), 1)


func test_balance_lets_the_player_choose_what_goes() -> void:
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	_pick(0, "Serra Angel")
	var balance := give_hand(0, "Balance")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, balance, []))
	resolve_stack()
	assert_not_null(g.find_on_battlefield(0, "Grizzly Bears"),
		"the seat kept what it chose to keep")
	assert_null(g.find_on_battlefield(0, "Serra Angel"))


func test_balance_sacrifice_beats_regeneration() -> void:
	# Sacrifice is not destruction (CR 701.17) — a shield does not save it.
	var troll := put_battlefield(0, "Uthden Troll")
	put_battlefield(0, "Grizzly Bears")
	troll.regeneration_shields = 1
	var balance := give_hand(0, "Balance")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, balance, []))
	resolve_stack()
	var left := 0
	for inst in g.players[0].battlefield:
		if inst.is_creature():
			left += 1
	assert_eq(left, 0, "both go: the opponent has no creatures at all")


# ----------------------------------------------------------- Juxtapose --

func test_juxtapose_trades_the_biggest_creature_each_way() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")        # {1}{G}
	var theirs := put_battlefield(1, "Serra Angel")        # {3}{W}{W}
	var jux := give_hand(0, "Juxtapose")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, jux, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(mine.controller_id, 1, "your bear crosses the table")
	assert_eq(theirs.controller_id, 0, "their angel comes back")


func test_juxtapose_also_trades_artifacts() -> void:
	var my_ring := put_battlefield(0, "Sol Ring")          # {1}
	var their_disk := put_battlefield(1, "Nevinyrral's Disk")   # {4}
	var jux := give_hand(0, "Juxtapose")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, jux, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(my_ring.controller_id, 1)
	assert_eq(their_disk.controller_id, 0)


func test_juxtapose_needs_both_halves() -> void:
	# CR 701.10c: no creature on one side means no creature trade at all.
	var mine := put_battlefield(0, "Grizzly Bears")
	var jux := give_hand(0, "Juxtapose")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, jux, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(mine.controller_id, 0, "nothing to trade it for")


func test_juxtapose_tie_is_broken_by_that_permanents_controller() -> void:
	# Two {G} one-drops are tied for greatest, so p0 picks which one goes.
	var elves := put_battlefield(0, "Llanowar Elves")      # {G}, 1/1
	var sprites := put_battlefield(0, "Scryb Sprites")     # {G}, 1/1
	assert_eq(elves.data.cost.mana_value(), sprites.data.cost.mana_value())
	var theirs := put_battlefield(1, "Serra Angel")
	_pick(0, "Scryb Sprites")
	var jux := give_hand(0, "Juxtapose")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, jux, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(sprites.controller_id, 1, "the seat's own tie-break went across")
	assert_eq(elves.controller_id, 0)
	assert_eq(theirs.controller_id, 0, "Serra Angel came back to p0")


# --------------------------------------------------- Gauntlets of Chaos --

func _gauntlets_swap(mine: CardInstance, theirs: CardInstance) -> String:
	var gauntlets := put_battlefield(0, "Gauntlets of Chaos")
	add_mana(0, Mtg.ManaColor.C, 5)
	return g.activate_ability(0, gauntlets, 0,
		[TargetRef.card(mine), TargetRef.card(theirs)])


func test_gauntlets_exchanges_two_creatures() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Serra Angel")
	assert_ok(_gauntlets_swap(mine, theirs))
	resolve_stack()
	assert_eq(mine.controller_id, 1)
	assert_eq(theirs.controller_id, 0)


func test_gauntlets_pays_by_sacrificing_itself() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Serra Angel")
	assert_ok(_gauntlets_swap(mine, theirs))
	assert_null(g.find_on_battlefield(0, "Gauntlets of Chaos"),
		"the artifact is sacrificed as part of the cost")


func test_gauntlets_refuses_a_permanent_you_do_not_control() -> void:
	var theirs := put_battlefield(1, "Serra Angel")
	var also_theirs := put_battlefield(1, "Grizzly Bears")
	assert_refused(_gauntlets_swap(theirs, also_theirs), "Illegal target")


func test_gauntlets_destroys_the_auras_on_both_traded_permanents() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Serra Angel")
	var strength := put_battlefield(0, "Holy Strength")
	g.attach_aura_from_anywhere(strength, mine, 0)
	var weakness := put_battlefield(1, "Holy Strength")
	g.attach_aura_from_anywhere(weakness, theirs, 1)
	assert_ok(_gauntlets_swap(mine, theirs))
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "Auras on both go")
	assert_eq(weakness.zone, Mtg.Zone.GRAVEYARD)


func test_gauntlets_refuses_a_pair_that_shares_no_type() -> void:
	# "That shares one of those types with it" is a targeting requirement
	# (lifted 2026-09-02: TargetSpec.sibling_filter).
	var my_land := put_battlefield(0, "Forest")
	var their_bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_gauntlets_swap(my_land, their_bear), "Illegal target (type).")
	assert_eq(my_land.controller_id, 0, "no shared type, no trade")
	assert_eq(their_bear.controller_id, 1)


func test_gauntlets_fizzles_when_one_target_leaves() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Serra Angel")
	assert_ok(_gauntlets_swap(mine, theirs))
	g.destroy(theirs)
	resolve_stack()
	assert_eq(mine.controller_id, 0, "the exchange is all or nothing")


# ------------------------------------------------------ Nebuchadnezzar --

func test_nebuchadnezzar_discards_every_copy_it_names() -> void:
	var neb := put_battlefield(0, "Nebuchadnezzar")
	for _i in 3:
		give_hand(1, "Grizzly Bears")
	# The name has to be findable in the opponent's VISIBLE deck.
	put_battlefield(1, "Grizzly Bears")
	var agent := NameSaying.new()
	agent.says = "Grizzly Bears"
	g.set_agent(0, agent)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, neb, 0, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 0, "all three revealed and discarded")
	assert_eq(g.players[1].graveyard.size(), 3)


func test_nebuchadnezzar_reveals_only_x_cards() -> void:
	var neb := put_battlefield(0, "Nebuchadnezzar")
	for _i in 4:
		give_hand(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var agent := NameSaying.new()
	agent.says = "Grizzly Bears"
	g.set_agent(0, agent)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, neb, 0, [TargetRef.player(1)], 1))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 3, "only one card was revealed")


func test_nebuchadnezzar_leaves_a_hand_of_other_cards_alone() -> void:
	var neb := put_battlefield(0, "Nebuchadnezzar")
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Lightning Bolt")
	put_battlefield(1, "Grizzly Bears")
	var agent := NameSaying.new()
	agent.says = "Grizzly Bears"
	g.set_agent(0, agent)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, neb, 0, [TargetRef.player(1)], 2))
	resolve_stack()
	assert_eq(g.players[1].hand.size(), 2, "nothing named was revealed")


func test_nebuchadnezzar_is_your_turn_only() -> void:
	var neb := put_battlefield(0, "Nebuchadnezzar")
	advance_to_next_turn()          # now player 1's turn
	assert_ok(g.pass_priority(1))   # ...and p0 holds priority in it
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, neb, 0, [TargetRef.player(1)], 1),
		"only during your turn")


# -------------------------------------------------- Season of the Witch --

func test_season_reaps_the_creature_that_stayed_home() -> void:
	put_battlefield(0, "Season of the Witch")
	var attacker := put_battlefield(0, "Grizzly Bears")
	var slacker := put_battlefield(0, "Grizzly Bears")
	run_combat([attacker.id])
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(slacker.zone, Mtg.Zone.GRAVEYARD, "it could have attacked")
	assert_eq(attacker.zone, Mtg.Zone.BATTLEFIELD, "it did attack")


func test_season_spares_a_creature_that_could_not_attack() -> void:
	put_battlefield(0, "Season of the Witch")
	var wall := put_battlefield(0, "Wall of Wood")
	var sick := put_battlefield(0, "Grizzly Bears", true)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "defender couldn't attack")
	assert_eq(sick.zone, Mtg.Zone.BATTLEFIELD, "summoning sickness")


func test_season_spares_the_non_active_players_army() -> void:
	# CR 508.1a: only the active player declares attackers, so nobody
	# else's creatures "could have attacked".
	put_battlefield(0, "Season of the Witch")
	var theirs := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)


func test_season_spares_a_tapped_creature() -> void:
	put_battlefield(0, "Season of the Witch")
	var tapped := put_battlefield(0, "Grizzly Bears")
	g.tap_permanent(tapped)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(tapped.zone, Mtg.Zone.BATTLEFIELD, "only UNTAPPED creatures go")


func test_season_charges_two_life_at_your_upkeep() -> void:
	put_battlefield(0, "Season of the Witch")
	var before := g.players[0].life
	advance_to_next_turn()   # p1's upkeep — no rent
	assert_eq(g.players[0].life, before)
	advance_to_next_turn()   # back to p0
	assert_eq(g.players[0].life, before - 2)
	assert_not_null(g.find_on_battlefield(0, "Season of the Witch"))


func test_season_is_sacrificed_when_the_rent_is_declined() -> void:
	g.set_agent(0, Skinflint.new())
	put_battlefield(0, "Season of the Witch")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_null(g.find_on_battlefield(0, "Season of the Witch"))
	assert_eq(g.players[0].life, 20, "no life is paid when it is let go")


# ------------------------ Guardian Beast's third clause (simplification lifted) --

func test_guardian_beast_stops_an_artifact_changing_controllers() -> void:
	var beast := put_battlefield(0, "Guardian Beast")
	var ring := put_battlefield(0, "Sol Ring")
	var theirs := put_battlefield(1, "Nevinyrral's Disk")
	assert_true(ring.cur_cant_change_control)
	assert_ok(_gauntlets_swap(ring, theirs))
	resolve_stack()
	assert_eq(ring.controller_id, 0, "other players can't gain control of it")
	assert_eq(theirs.controller_id, 1, "so the exchange does not happen at all")
	assert_eq(beast.controller_id, 0)


func test_guardian_beast_lets_go_when_it_taps() -> void:
	var beast := put_battlefield(0, "Guardian Beast")
	var ring := put_battlefield(0, "Sol Ring")
	var theirs := put_battlefield(1, "Nevinyrral's Disk")
	g.tap_permanent(beast)
	assert_false(ring.cur_cant_change_control)
	assert_ok(_gauntlets_swap(ring, theirs))
	resolve_stack()
	assert_eq(ring.controller_id, 1)
	assert_eq(theirs.controller_id, 0)
