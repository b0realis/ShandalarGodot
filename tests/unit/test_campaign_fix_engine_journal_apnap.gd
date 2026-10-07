extends GameTest
## Campaign fix-engine — two LOW engine findings.
##
## w4-5: the search journal (make_mark / unmake_to, CONTRIBUTING rule 7)
##   did not record the END of a game (_lose, draw_game: game_over, winner,
##   is_draw, has_lost) nor the 1997 damage steps' state (the step flags,
##   the waiting packets, the regeneration candidates and the simultaneous
##   bracket the regeneration step keeps open), so an AI search that
##   explored a game-ending line or a damage step left them behind.
## w4-6: graveyard "at the beginning of the end step / upkeep" triggers were
##   put on the stack in SEAT order, ahead of every battlefield trigger —
##   not APNAP (CR 603.3b): on the second seat's turn the first seat's
##   trigger went on first and so resolved last.


class WindowAgent extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func after_each() -> void:
	CardPacks.set_enabled("pack-5", false)


# ------------------------------------------------------------ w4-5 journal --

func test_the_journal_puts_back_a_game_won_by_a_spell() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.players[1].life = 3
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_true(g.game_over, "precondition: the explored line wins the game")
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[1].life, 3)
	assert_false(g.game_over, "game_over is put back")
	assert_eq(g.winner, -1, "winner is put back")
	assert_false(g.players[1].has_lost, "has_lost is put back")


func test_the_journal_puts_back_a_drawn_game() -> void:
	var mark := g.make_mark()
	g.draw_game("a test")
	assert_true(g.game_over and g.is_draw)
	g.unmake_to(mark)
	g.end_search()
	assert_false(g.game_over)
	assert_false(g.is_draw)


func test_the_journal_puts_back_an_opened_prevention_step() -> void:
	g.rules.set_edition("fifth")
	g.set_agent(0, WindowAgent.new())
	g.set_agent(1, WindowAgent.new())
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(1, "Healing Salve")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_true(g.awaiting_damage_prevention, "precondition: the step is open")
	assert_eq(g.damage_pending.size(), 1)
	g.unmake_to(mark)
	g.end_search()
	assert_false(g.awaiting_damage_prevention, "the step flag is put back")
	assert_eq(g.damage_pending.size(), 0, "and the waiting packet is gone")
	assert_eq(bear.damage, 0)


func test_the_journal_puts_back_an_opened_regeneration_step() -> void:
	g.rules.set_edition("fifth")
	g.set_agent(0, WindowAgent.new())
	g.set_agent(1, WindowAgent.new())
	advance_to_step(Mtg.Step.MAIN1)
	var bones := put_battlefield(1, "Drudge Skeletons")   # a regenerator on the board
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bones)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	var guard := 0
	while g.awaiting_damage_prevention and guard < 4:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_regeneration, "precondition: the Skeletons are about to die")
	g.unmake_to(mark)
	g.end_search()
	assert_false(g.awaiting_regeneration, "the step flag is put back")
	assert_eq(g.regeneration_candidates.size(), 0)
	assert_eq(g._defer_depth, 0, "the simultaneous bracket the step held open is closed again")
	assert_false(g._defer_state_based_actions, "state-based actions are no longer deferred")
	assert_eq(bones.damage, 0)


# -------------------------------------------------------------- w4-6 APNAP --

func _to_grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


func test_graveyard_end_step_triggers_are_apnap_on_the_second_seats_turn() -> void:
	CardPacks.set_enabled("pack-5", true)
	before_each()
	advance_to_next_turn()       # seat 1's turn
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.MAIN2)
	for pid in 2:
		_to_grave(pid, "Krovikan Horror")
		_to_grave(pid, "Grizzly Bears")   # a creature card directly above it
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.current_step(), Mtg.Step.END)
	var order: Array = []
	for item in g.stack:
		order.append(item.controller)
	assert_eq(order, [1, 0],
		"the active player's trigger goes on first, the non-active player's resolves first")


## A graveyard trigger takes its seat's place among the BATTLEFIELD triggers
## of the same event: the active player's battlefield trigger goes on the
## stack before the non-active player's graveyard one.
func test_a_graveyard_trigger_is_ordered_with_its_seats_battlefield_triggers() -> void:
	CardPacks.set_enabled("pack-5", true)
	before_each()
	var bell := CardData.new("End Bell", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _noop,
			"At the beginning of the end step, nothing happens."))
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.active_player, 0)
	put_synthetic(0, bell)
	_to_grave(1, "Krovikan Horror")
	_to_grave(1, "Grizzly Bears")
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.current_step(), Mtg.Step.END)
	var order: Array = []
	for item in g.stack:
		order.append([item.controller, item.card.data.card_name])
	assert_eq(order, [[0, "End Bell"], [1, "Krovikan Horror"]],
		"APNAP across zones: the active seat's battlefield trigger first (bottom)")


static func _noop(_game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
	pass
