extends GameTest
## THE SACRIFICE CLAUSES' RULES OPTION (the owner's ruling of 2026-10-13,
## RulesOptions.sacrifice_clauses_wait, Options › Rules "Forced sacrifices
## wait on the chain").
##
## "When you control no Islands, sacrifice this" and its family were checked
## as a state-based action under every preset — the 1997 printings' "Bury
## ... if at any time", no response. That stays the default, under every
## preset. Switched on, each clause is the modern Oracle's state trigger
## (CR 603.8): it triggers once while its condition holds, waits on the
## stack — a Pirate Ship pings once more as its last Island goes — cannot
## trigger again while it waits, and sacrifices on resolution with no
## intervening "if". Base-set cards only; every card of the family, across
## the nine packs, is pinned in tests/cards/test_c2_f_sac_family.gd.


func _start(preset: String, wait := false) -> void:
	before_each()
	g.rules.set_preset(preset)
	g.rules.sacrifice_clauses_wait = wait
	advance_to_step(Mtg.Step.MAIN1)


## The clause triggers waiting for [param card] — on the stack or in the
## cost freeze.
func _clause_items(card: CardInstance) -> int:
	var n := 0
	for item in g.stack + g._waiting_triggers:
		if item.kind == Mtg.StackKind.TRIGGER and item.card == card \
				and g._c2s_clause_triggers.has(item.trigger):
			n += 1
	return n


## A Pirate Ship and its one Island, settled: [ship, island].
func _ship(pid := 0) -> Array:
	var island := put_battlefield(pid, "Island")
	var ship := put_battlefield(pid, "Pirate Ship")
	g.check_state_based_actions()
	assert_eq(ship.zone, Mtg.Zone.BATTLEFIELD, "an Island keeps it afloat")
	return [ship, island]


# ======================================================== the default ==

func test_every_preset_sacrifices_at_once_with_no_stack_item() -> void:
	for preset in ["modern_mana_burn", "modern", "fifth"]:
		_start(preset)
		assert_false(g.rules.sacrifice_clauses_wait, "%s keeps the 1997 answer" % preset)
		var pair := _ship()
		var ship: CardInstance = pair[0]
		g.destroy(pair[1], false)
		g.check_state_based_actions()
		assert_eq(ship.zone, Mtg.Zone.GRAVEYARD, "%s: sacrificed at once" % preset)
		assert_eq(_clause_items(ship), 0, "%s: nothing waits" % preset)
		assert_true(g.stack.is_empty(), "%s: no stack item at all" % preset)


func test_a_fresh_engine_is_the_default_too() -> void:
	# No preset set at all: the engine's own defaults (a Deck Lab worker, a
	# test) play the 1997 answer, exactly as before the option existed.
	before_each()
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(RulesOptions.new().sacrifice_clauses_wait)
	var pair := _ship()
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	assert_eq(pair[0].zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.stack.is_empty())


# =================================================== switched on: waits ==

func test_switched_on_the_ship_pings_once_more_as_its_last_island_goes() -> void:
	_start("modern_mana_burn", true)
	var pair := _ship()
	var ship: CardInstance = pair[0]
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	assert_eq(ship.zone, Mtg.Zone.BATTLEFIELD, "the sacrifice waits on the stack")
	assert_eq(_clause_items(ship), 1)
	assert_eq(g.stack.back().description,
		"Pirate Ship — When you control no Islands, sacrifice Pirate Ship.",
		"the card's own printed line")
	assert_eq(g.stack.back().controller, 0, "its controller's trigger")
	assert_ok(g.activate_ability(0, ship, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19, "one more ping")
	assert_eq(ship.zone, Mtg.Zone.GRAVEYARD, "and then it goes")


func test_switched_on_under_the_1997_preset_too() -> void:
	# A Custom mix: the fork is its own switch whatever the others say.
	_start("fifth", true)
	var pair := _ship()
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	assert_eq(_clause_items(pair[0]), 1)
	resolve_stack()
	assert_eq(pair[0].zone, Mtg.Zone.GRAVEYARD)


func test_an_island_that_comes_back_does_not_save_it() -> void:
	# Modern Oracle: "When you control no Islands, sacrifice Pirate Ship" —
	# no intervening "if" (CR 603.4), so the clause is not asked again.
	_start("modern_mana_burn", true)
	var pair := _ship()
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	put_battlefield(0, "Island")
	g.check_state_based_actions()
	assert_eq(_clause_items(pair[0]), 1, "still waiting")
	resolve_stack()
	assert_eq(pair[0].zone, Mtg.Zone.GRAVEYARD, "sacrificed all the same")


func test_the_clause_triggers_once_while_it_waits() -> void:
	_start("modern_mana_burn", true)
	var pair := _ship()
	var ship: CardInstance = pair[0]
	g.destroy(pair[1], false)
	for k in 3:
		g.check_state_based_actions()
	assert_eq(_clause_items(ship), 1, "CR 603.8: not again while it waits")
	assert_ok(g.pass_priority(g.priority_player))   # one pass: still waiting
	g.check_state_based_actions()
	assert_eq(_clause_items(ship), 1)
	resolve_stack()
	assert_eq(ship.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_clause_items(ship), 0)
	assert_true(g.stack.is_empty(), "and nothing fires after it")


func test_a_dwarf_drives_the_goblins_off_both_ways() -> void:
	for wait in [false, true]:
		_start("modern_mana_burn", wait)
		var goblins := put_battlefield(0, "Goblins of the Flarg")
		g.check_state_based_actions()
		assert_eq(goblins.zone, Mtg.Zone.BATTLEFIELD)
		put_battlefield(1, "Dwarven Warriors")
		g.check_state_based_actions()
		assert_eq(goblins.zone, Mtg.Zone.BATTLEFIELD, "their Dwarf is not yours")
		put_battlefield(0, "Dwarven Warriors")
		g.check_state_based_actions()
		if wait:
			assert_eq(goblins.zone, Mtg.Zone.BATTLEFIELD, "on: it waits")
			assert_eq(_clause_items(goblins), 1)
			assert_string_contains(g.stack.back().description, "When you control a Dwarf")
			resolve_stack()
		else:
			assert_eq(_clause_items(goblins), 0, "off: nothing waits")
		assert_eq(goblins.zone, Mtg.Zone.GRAVEYARD, "wait=%s" % wait)


func test_jihad_goes_when_its_colour_is_gone_both_ways() -> void:
	for wait in [false, true]:
		_start("modern_mana_burn", wait)
		var bears := put_battlefield(1, "Grizzly Bears")
		var jihad := put_battlefield(0, "Jihad")
		var knight := put_battlefield(0, "White Knight")
		g.check_state_based_actions()
		assert_eq(jihad.zone, Mtg.Zone.BATTLEFIELD)
		assert_eq(knight.cur_power, 4, "the anthem holds while green is there")
		g.destroy(bears, false)
		g.check_state_based_actions()
		if wait:
			assert_eq(jihad.zone, Mtg.Zone.BATTLEFIELD)
			assert_eq(_clause_items(jihad), 1)
			resolve_stack()
		else:
			assert_true(g.stack.is_empty())
		assert_eq(jihad.zone, Mtg.Zone.GRAVEYARD, "wait=%s" % wait)


# ======================================== the object, its controller, its zone ==

func test_a_ship_that_left_is_not_sacrificed_and_its_return_triggers_anew() -> void:
	_start("modern_mana_burn", true)
	var pair := _ship()
	var ship: CardInstance = pair[0]
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	assert_eq(_clause_items(ship), 1)
	g.return_to_hand(ship)
	assert_eq(ship.zone, Mtg.Zone.HAND)
	# Back again before the old trigger resolves: a NEW object (CR 400.7),
	# whose own clause triggers at once.
	g._put_on_battlefield(ship, 0)
	ship.summoning_sick = false
	g.check_state_based_actions()
	assert_eq(_clause_items(ship), 2, "the old occurrence and the new object's")
	resolve_stack()
	assert_eq(ship.zone, Mtg.Zone.GRAVEYARD, "the new object's trigger sacrifices it")


func test_a_bounced_ship_stays_in_hand() -> void:
	_start("modern_mana_burn", true)
	var pair := _ship()
	var ship: CardInstance = pair[0]
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	g.return_to_hand(ship)
	resolve_stack()
	assert_eq(ship.zone, Mtg.Zone.HAND, "nothing to sacrifice")


func test_a_ship_stolen_while_its_trigger_waits_is_not_sacrificed() -> void:
	# CR 701.17a: only a permanent's controller can sacrifice it. The new
	# controller has an Island, so the clause does not hold for them.
	_start("modern_mana_burn", true)
	put_battlefield(1, "Island")
	var pair := _ship()
	var ship: CardInstance = pair[0]
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	assert_eq(_clause_items(ship), 1)
	g.change_control(ship, 1)
	resolve_stack()
	assert_eq(ship.zone, Mtg.Zone.BATTLEFIELD, "the trigger's controller no longer controls it")
	assert_eq(ship.controller_id, 1)
	assert_true(g.stack.is_empty(), "and its new controller has an Island")


func test_a_ship_stolen_by_a_player_with_no_island_triggers_for_them() -> void:
	_start("modern_mana_burn", true)
	var pair := _ship()
	var ship: CardInstance = pair[0]
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	g.change_control(ship, 1)
	resolve_stack()
	assert_eq(ship.zone, Mtg.Zone.GRAVEYARD,
		"the first does nothing; the clause then triggers for the new controller")


func test_a_face_down_ship_has_no_clause() -> void:
	for wait in [false, true]:
		_start("modern_mana_burn", wait)
		var ship := put_battlefield(0, "Pirate Ship")
		g.turn_face_down(ship)
		g.check_state_based_actions()
		assert_eq(ship.zone, Mtg.Zone.BATTLEFIELD, "CR 708.2: no abilities face down (wait=%s)" % wait)
		assert_eq(_clause_items(ship), 0)


func test_a_phased_out_ship_is_not_sacrificed_and_triggers_again_when_it_returns() -> void:
	_start("modern_mana_burn", true)
	var pair := _ship()
	var ship: CardInstance = pair[0]
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	assert_true(g.phase_out(ship))
	resolve_stack()
	assert_true(ship.phased_out, "CR 702.26b: a phased-out permanent can't be sacrificed")
	assert_true(g.phase_in(ship))
	g.check_state_based_actions()
	assert_eq(_clause_items(ship), 1, "back, and still no Island")
	resolve_stack()
	assert_eq(ship.zone, Mtg.Zone.GRAVEYARD)


# ======================================================== the search journal ==

func test_a_search_unmakes_the_trigger_and_the_sacrifice() -> void:
	_start("modern_mana_burn", true)
	var pair := _ship()
	var ship: CardInstance = pair[0]
	var island: CardInstance = pair[1]
	var stack_before := g.stack.size()
	var mark := g.make_mark()
	g.destroy(island, false)
	g.check_state_based_actions()
	assert_eq(_clause_items(ship), 1, "the probe sees the trigger")
	assert_true(g.sacrifice_clause_pending(ship))
	g._resolve_top()
	assert_eq(ship.zone, Mtg.Zone.GRAVEYARD, "and the sacrifice")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(ship.zone, Mtg.Zone.BATTLEFIELD, "unmade")
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), stack_before)
	assert_eq(_clause_items(ship), 0)
	# ...and the real game still works afterwards.
	g.destroy(island, false)
	g.check_state_based_actions()
	assert_eq(_clause_items(ship), 1)
	resolve_stack()
	assert_eq(ship.zone, Mtg.Zone.GRAVEYARD)


func test_the_public_readers_name_the_doomed_permanent() -> void:
	_start("modern_mana_burn", true)
	var pair := _ship()
	var ship: CardInstance = pair[0]
	assert_false(g.sacrifice_clause_pending(ship))
	g.destroy(pair[1], false)
	g.check_state_based_actions()
	assert_eq(g.sacrifice_clause_victim(g.stack.back()), ship)
	assert_true(g.sacrifice_clause_pending(ship))
	g.change_control(ship, 1)
	assert_null(g.sacrifice_clause_victim(g.stack.back()), "a stolen ship is not doomed by it")
	assert_false(g.sacrifice_clause_pending(ship))


# ============================================ the 1997 damage window, mixed ==

class WindowAgent extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func test_under_the_1997_damage_window_the_trigger_waits_for_the_death() -> void:
	# A Custom mix: the 1997 damage-prevention step AND the waiting clause.
	# Damage waits in the step; the Island dies only once it has closed,
	# and only then does the clause trigger.
	for wait in [false, true]:
		before_each()
		g.rules.set_preset("fifth")
		g.rules.sacrifice_clauses_wait = wait
		g.set_agent(0, WindowAgent.new())
		g.set_agent(1, WindowAgent.new())
		advance_to_step(Mtg.Step.MAIN1)
		put_battlefield(0, "Kormus Bell")   # Swamps are 1/1 creatures
		var swamp := put_battlefield(0, "Swamp")
		var serpent := put_synthetic(0, CardData.new("Test Swamp Serpent", "{1}",
			Mtg.CardType.CREATURE).pt(5, 5).with_sacrifice_if_no_land("swamp")
			.oracle("When you control no Swamps, sacrifice this creature."))
		give_hand(1, "Grizzly Bears")   # a card in hand: the step opens
		g.check_state_based_actions()
		assert_true(swamp.is_creature(), "precondition: the Bell animates it")
		var bolt := give_hand(0, "Lightning Bolt")
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, bolt, [TargetRef.card(swamp)]))
		assert_ok(g.pass_priority(0))
		assert_ok(g.pass_priority(1))
		assert_true(g.awaiting_damage_prevention, "the 1997 step holds the damage")
		assert_eq(swamp.zone, Mtg.Zone.BATTLEFIELD)
		assert_eq(_clause_items(serpent), 0, "nothing has died yet (wait=%s)" % wait)
		var guard := 0
		while (g.awaiting_damage_prevention or g.awaiting_regeneration) and guard < 8:
			assert_ok(g.pass_priority(g.priority_player))
			guard += 1
		assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD, "the Swamp dies after the step")
		if wait:
			assert_eq(serpent.zone, Mtg.Zone.BATTLEFIELD, "and the clause waits")
			assert_eq(_clause_items(serpent), 1)
			resolve_stack()
		assert_eq(serpent.zone, Mtg.Zone.GRAVEYARD, "wait=%s" % wait)
