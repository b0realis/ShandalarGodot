extends GameTest
## A PAYMENT MADE WHILE A TRIGGER RESOLVES (MtgGame.pay_object_costs,
## 0.70.9: Masticore's discard is the player's choice) — the other cards
## of that shape. A player's seat is held open for every card it names; a
## seat that answers for itself still hears a cost's question, which is
## how the computer knows to give up its least valuable card.

class Recorder extends DecisionAgent:
	var cost_stamps: Array = []
	var prompts: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return true

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		prompts.append(prompt)
		cost_stamps.append(current_choice().is_cost)
		return candidates[-1]


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardPacks.set_enabled("pack-9", true)
	CardPacks.set_enabled("pack-10", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


## The packs go off again: left on, they changed the pool every later
## script of the run read (the 1997 decks' proxies, the ban lists).
func after_each() -> void:
	g = null
	for id in ["pack-8", "pack-9", "pack-10"]:
		CardPacks.set_enabled(id, false)


func _run_until_asked() -> void:
	var guard := 0
	while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1


func test_a_player_names_both_mountains_rathi_dragon_eats() -> void:
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	var lands: Array[CardInstance] = []
	for i in 4:
		lands.append(put_battlefield(0, "Mountain"))
	var dragon := put_battlefield(0, "Rathi Dragon")
	_run_until_asked()
	assert_not_null(g.awaiting_choice, "pay or not is asked")
	if g.awaiting_choice == null:
		return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_ok(g.answer_choice(true))
	for pick in [lands[3], lands[1]]:
		_run_until_asked()
		assert_not_null(g.awaiting_choice, "each Mountain is asked for")
		if g.awaiting_choice == null:
			return
		assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
		assert_false(g.awaiting_choice.is_cost, "a question of the resolution")
		assert_true(g.awaiting_choice.candidates.has(pick))
		assert_eq(lands.map(func(l: CardInstance) -> int: return l.zone),
			[Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD, Mtg.Zone.BATTLEFIELD],
			"nothing is paid before the last answer")
		assert_ok(g.answer_choice(pick.id))
	_run_until_asked()
	assert_null(g.awaiting_choice)
	assert_eq(lands.map(func(l: CardInstance) -> int: return l.zone),
		[Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD, Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD],
		"the two named, and no other")
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.unanswered_choices.is_empty(), "nothing was decided for the player")


func test_a_seat_that_answers_for_itself_still_hears_a_cost() -> void:
	var seat := Recorder.new()
	g.set_agent(0, seat)
	for i in 5:
		put_battlefield(0, "Forest")
	var wizard := put_battlefield(0, "Ovinomancer")
	resolve_stack()
	assert_eq(seat.cost_stamps, [true, true, true],
		"the computer reads the stamp to give up its least valuable")
	assert_eq(seat.prompts.size(), 3)
	assert_eq(wizard.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].hand.size(), 3, "three lands came back")


func test_an_empty_hand_is_not_asked_and_masticore_goes() -> void:
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	var masticore := put_battlefield(0, "Masticore")
	g.players[0].hand.clear()
	advance_to_next_turn()
	advance_to_next_turn()
	_run_until_asked()
	assert_null(g.awaiting_choice, "nothing to choose with no card in hand")
	assert_eq(masticore.zone, Mtg.Zone.GRAVEYARD)
