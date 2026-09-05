extends GameTest
## TARGETED TRIGGERS (CR 603.3d): a triggered ability built with
## TriggeredAbility.targeting chooses its target as it goes on the stack,
## is removed instead when nothing is legal, and fizzles on resolution when
## the target has become illegal (CR 608.2b). The choice is the trigger's
## controller's: a heuristic or AI seat answers as the trigger goes on
## (the card's own ranking, PlayerChoice.ordered), a human seat is HELD on
## the question the moment a player would receive priority (CR 603.3 —
## MtgGame._hold_trigger_targets, riding the cost hold's record-and-replay).
##
## Two synthetic cards pin the mechanism rather than any card in the pool:
## - Test Beacon, an artifact whose ETB deals 2 damage to target creature
##   (ranked: the opponent's biggest first, then everything else);
## - Test Reaper, a creature that shoots target player for 1 whenever a
##   creature dies (ranked: the opponent first) — a "target player" trigger
##   asks an OPTION question, since a player is not a card.


class Beacon:
	static func data() -> CardData:
		return CardData.new("Test Beacon", "{1}", Mtg.CardType.ARTIFACT) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.ENTERS_BATTLEFIELD, Beacon.shoot,
				"When Test Beacon enters, it deals 2 damage to target creature.",
				Beacon.is_self) \
				.targeting(TargetSpec.creature(), Beacon.enemy_biggest_first,
					"Select a creature."))

	static func is_self(_game: MtgGame, source: CardInstance,
			event: GameEvent) -> bool:
		return event.data.get("instance") == source

	static func shoot(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
		var refs: Array = game.current_targets()
		if refs.is_empty():
			return
		game.deal_damage(source, refs[0], 2)

	static func enemy_biggest_first(game: MtgGame, source: CardInstance,
			a: TargetRef, b: TargetRef) -> bool:
		var ia := game.find_instance(a.instance_id)
		var ib := game.find_instance(b.instance_id)
		var a_enemy := ia.controller_id != source.controller_id
		var b_enemy := ib.controller_id != source.controller_id
		if a_enemy != b_enemy:
			return a_enemy
		var va := ia.cur_power + ia.cur_toughness
		var vb := ib.cur_power + ib.cur_toughness
		if va != vb:
			return va > vb
		return ia.id < ib.id


class Reaper:
	static func data() -> CardData:
		return CardData.new("Test Reaper", "{1}{B}", Mtg.CardType.CREATURE) \
			.pt(1, 1) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.DIES, Reaper.reap,
				"Whenever a creature dies, Test Reaper deals 1 damage to target player.",
				Reaper.a_creature_died) \
				.targeting(TargetSpec.player(), Reaper.opponent_first,
					"Select target player."))

	static func a_creature_died(_game: MtgGame, _source: CardInstance,
			event: GameEvent) -> bool:
		var dead: CardInstance = event.data.get("instance")
		return dead != null and (dead.last_types & Mtg.CardType.CREATURE) != 0

	static func reap(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
		var refs: Array = game.current_targets()
		if refs.is_empty():
			return
		game.deal_damage(source, refs[0], 1)

	static func opponent_first(_game: MtgGame, source: CardInstance,
			a: TargetRef, b: TargetRef) -> bool:
		var a_enemy := a.player_id != source.controller_id
		var b_enemy := b.player_id != source.controller_id
		if a_enemy != b_enemy:
			return a_enemy
		return a.player_id < b.player_id


## Picks named cards, in order; records what it was offered.
class ListSeat extends DecisionAgent:
	var picks: Array = []
	var offered: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		var names: Array = []
		for inst in candidates:
			names.append(inst.data.card_name)
		offered.append(names)
		if picks.is_empty():
			return null
		var wanted := String(picks.pop_front())
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func _top() -> StackItem:
	return g.stack.back()


# ------------------------------------------------ choosing as it goes on --

func test_the_target_is_chosen_as_the_trigger_goes_on_the_stack() -> void:
	put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	put_synthetic(0, Beacon.data())
	assert_eq(g.stack.size(), 1, "the trigger is on the stack")
	var item := _top()
	assert_eq(item.targets.size(), 1, "with its target already chosen")
	assert_true(item.targets[0].same_object(TargetRef.card(giant)),
		"the ranked list's first entry — the opponent's biggest")
	assert_true(item.description.contains("targeting Hill Giant"))
	assert_false(item.target_held, "a seat that answers on the spot is not held")
	resolve_stack()
	assert_eq(giant.damage, 2)


func test_the_seat_s_own_answer_is_the_target() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var seat := ListSeat.new()
	seat.picks = ["Grizzly Bears"]
	g.set_agent(0, seat)
	put_synthetic(0, Beacon.data())
	resolve_stack()
	assert_eq(seat.offered, [["Hill Giant", "Grizzly Bears"]],
		"offered the whole ranked list")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the seat named the Bears")
	assert_eq(giant.damage, 0)


func test_a_declined_answer_falls_back_to_the_ranked_first() -> void:
	put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	g.set_agent(0, ListSeat.new())   # answers null
	put_synthetic(0, Beacon.data())
	resolve_stack()
	assert_eq(giant.damage, 2)


func test_the_ai_takes_the_card_s_ranking() -> void:
	# Left to its tutor instinct the AI would take the most VALUABLE card;
	# a targeted trigger's list is ranked for it (PlayerChoice.ordered).
	var angel := put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.set_agent(0, AiPlayer.new(0))
	put_synthetic(0, Beacon.data())
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the opponent's creature, not its own Angel")
	assert_eq(angel.damage, 0)


func test_the_question_is_on_the_record_with_its_ranking() -> void:
	put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, Beacon.data())
	var asked: PlayerChoice = g.choice_log.back()
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_eq(asked.source, "Test Beacon")
	assert_eq(asked.prompt, "Select a creature.")
	assert_true(asked.ordered)
	assert_eq(asked.pid, 0)


# ------------------------------------------------------- CR 603.3d, 608.2b --

func test_no_legal_target_means_no_trigger_on_the_stack() -> void:
	put_synthetic(0, Beacon.data())
	assert_true(g.stack.is_empty(), "removed rather than put on the stack")


func test_a_creature_with_shroud_is_not_a_candidate() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	g.attach_aura_from_anywhere(give_hand(1, "Spectral Cloak"), giant, 1)
	g.recalculate()
	assert_true(giant.cur_shroud)
	put_synthetic(0, Beacon.data())
	assert_true(_top().targets[0].same_object(TargetRef.card(bears)),
		"the Giant is on nobody's list")


func test_the_trigger_fizzles_when_its_target_has_left() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, Beacon.data())
	assert_true(_top().targets[0].same_object(TargetRef.card(giant)))
	# In response: the Giant is gone.
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.damage, 0, "the trigger fizzled rather than find a new victim")
	assert_true(String(g.log_lines[g.log_lines.size() - 1]).contains("fizzles"))


func test_a_context_only_trigger_is_untouched() -> void:
	# Ankh of Mishra: no target, no question, no fizzle check.
	put_battlefield(0, "Ankh of Mishra")
	var log_before := g.choice_log.size()
	put_battlefield(1, "Forest")
	assert_eq(g.stack.size(), 1)
	assert_true(_top().targets.is_empty())
	assert_eq(g.choice_log.size(), log_before)
	resolve_stack()
	assert_eq(g.players[1].life, 18)


# --------------------------------------------------- "target player" --

func test_a_player_target_is_an_option_question() -> void:
	put_synthetic(0, Reaper.data())
	var bears := put_battlefield(1, "Grizzly Bears")
	g.destroy(bears)
	assert_eq(g.stack.size(), 1)
	assert_true(_top().targets[0].is_player)
	assert_eq(_top().targets[0].player_id, 1, "the opponent, ranked first")
	var asked: PlayerChoice = g.choice_log.back()
	assert_eq(asked.kind, PlayerChoice.Kind.OPTION)
	assert_eq(asked.options, ["P1", "P0"])
	resolve_stack()
	assert_eq(g.players[1].life, 19)


# ------------------------------------------------------- the human hold --

func test_a_human_seat_is_held_on_the_question_at_priority() -> void:
	_human_seat(0)
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	put_synthetic(0, Beacon.data())
	var item := _top()
	assert_true(item.target_held, "the seat has still to answer")
	assert_null(g.awaiting_choice, "nothing asked inside the mutation")
	g._open_priority()   # what every real path does next
	assert_not_null(g.awaiting_choice)
	var q: PlayerChoice = g.awaiting_choice
	assert_eq(q.kind, PlayerChoice.Kind.CARD)
	assert_eq(q.source, "Test Beacon")
	assert_eq(q.prompt, "Select a creature.")
	assert_eq(q.candidates, [giant, bears])
	assert_refused(g.pass_priority(0), "waiting for a choice")
	assert_ok(g.answer_choice("Grizzly Bears"))
	assert_null(g.awaiting_choice)
	assert_false(item.target_held)
	assert_true(item.targets[0].same_object(TargetRef.card(bears)),
		"the player's own answer replaced the provisional pick")
	assert_true(g.unanswered_choices.is_empty(), "nothing was decided for them")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 0)


func test_two_held_triggers_are_asked_in_turn() -> void:
	_human_seat(0)
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	put_synthetic(0, Beacon.data())
	put_synthetic(0, Beacon.data())
	var first: StackItem = g.stack[0]
	var second: StackItem = g.stack[1]
	g._open_priority()
	assert_not_null(g.awaiting_choice)
	assert_ok(g.answer_choice("Grizzly Bears"))
	assert_not_null(g.awaiting_choice, "the second trigger's question follows")
	assert_ok(g.answer_choice("Hill Giant"))
	assert_null(g.awaiting_choice)
	assert_true(first.targets[0].same_object(TargetRef.card(bears)))
	assert_true(second.targets[0].same_object(TargetRef.card(giant)),
		"each answer went to its own trigger")


func test_a_held_trigger_whose_target_vanished_is_removed() -> void:
	_human_seat(0)
	var bears := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, Beacon.data())
	assert_eq(g.stack.size(), 1)
	g.destroy(bears)   # gone before anyone would receive priority
	g._open_priority()
	assert_null(g.awaiting_choice)
	assert_true(g.stack.is_empty(), "CR 603.3d: nothing legal, removed")


func test_a_player_target_holds_on_an_option_question() -> void:
	_human_seat(0)
	put_synthetic(0, Reaper.data())
	var bears := put_battlefield(1, "Grizzly Bears")
	g.destroy(bears)
	g._open_priority()
	var q: PlayerChoice = g.awaiting_choice
	assert_not_null(q)
	assert_eq(q.kind, PlayerChoice.Kind.OPTION)
	assert_eq(q.options, ["P1", "P0"])
	assert_ok(g.answer_choice(1))   # themselves, perversely
	assert_eq(_top().targets[0].player_id, 0)
	resolve_stack()
	assert_eq(g.players[0].life, 19)


func test_the_pre_flight_does_not_ask_and_the_hold_does() -> void:
	# The trigger fires INSIDE a resolution the pre-flight probes. The probe
	# must not put the question on the resolution's list (that would hold
	# the Bolt open on a question the trigger's own hold is about to ask);
	# the hold asks once the Bolt has resolved.
	_human_seat(0)
	put_synthetic(0, Reaper.data())
	var bears := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bears)]))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the Bolt resolved")
	var q: PlayerChoice = g.awaiting_choice
	assert_not_null(q, "held on the Reaper's question")
	assert_eq(q.source, "Test Reaper")
	assert_eq(q.kind, PlayerChoice.Kind.OPTION)
	assert_ok(g.answer_choice(0))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_true(g.unanswered_choices.is_empty())
