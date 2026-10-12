extends GameTest
## Campaign 2026-10-12 (b6-7) — a targeted TRIGGER whose every target slot
## has exactly ONE legal candidate is not a question.
##
## A human seat's trigger is held until a player would receive priority
## (MtgGame._hold_trigger_targets) and its target asked there. With one
## legal target — "target opponent" in a duel, the only creature on the
## board — that was a one-line question with nothing in it, every time:
## each Mogg Maniac hit, Corrosion / Chaos Lord every upkeep. A mandatory
## trigger has no take-back to protect, so the one candidate is now set
## without asking. Two or more candidates are still asked, and a trigger
## whose candidates have all gone by then is still removed (CR 603.3d).


class Beacon:
	static func data() -> CardData:
		return CardData.new("Test Beacon", "{1}", Mtg.CardType.ARTIFACT) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.ENTERS_BATTLEFIELD, Beacon.shoot,
				"When Test Beacon enters, it deals 2 damage to target creature.",
				Beacon.is_self).targeting(TargetSpec.creature(), Callable(),
					"Select a creature."))

	static func is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
		return event.data.get("instance") == source

	static func shoot(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
		var refs: Array = game.current_targets()
		if not refs.is_empty():
			game.deal_damage(source, refs[0], 2)


## Two slots: target opponent AND target creature.
class Twin:
	static func data() -> CardData:
		return CardData.new("Test Twin", "{1}", Mtg.CardType.ARTIFACT) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.ENTERS_BATTLEFIELD, Twin.shoot,
				"When Test Twin enters, it deals 1 damage to target opponent and 1 damage to target creature.",
				Beacon.is_self).targeting(TargetSpec.opponent(), Callable(), "Select an opponent.") \
				.and_targeting(TargetSpec.creature(), Callable(), "Select a creature."))

	static func shoot(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
		for ref in game.current_targets():
			game.deal_damage(source, ref, 1)


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func test_mogg_maniac_s_one_opponent_is_not_asked() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		_human_seat(0)
		var maniac := put_battlefield(0, "Mogg Maniac")
		var bolt := give_hand(0, "Lightning Bolt")
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, bolt, [TargetRef.card(maniac)]))
		var guard := 0
		while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
			if g.awaiting_damage_prevention or g.awaiting_regeneration:
				g.pass_priority(g.priority_player)
			else:
				assert_ok(g.pass_priority(g.priority_player))
			guard += 1
		assert_null(g.awaiting_choice, "no one-answer question is held (%s)" % preset)
		assert_eq(g.players[1].life, 17, "the Maniac hit the one opponent (%s)" % preset)
		assert_true(g.unanswered_choices.is_empty(), "nothing was decided for the player")


func test_one_creature_is_not_asked() -> void:
	_human_seat(0)
	var bears := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, Beacon.data())
	var item: StackItem = g.stack.back()
	g._open_priority()
	assert_null(g.awaiting_choice, "one candidate: nothing to ask")
	assert_false(item.target_held)
	assert_true(item.targets[0].same_object(TargetRef.card(bears)))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


func test_two_creatures_are_still_asked() -> void:
	_human_seat(0)
	var bears := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_synthetic(0, Beacon.data())
	g._open_priority()
	assert_not_null(g.awaiting_choice, "a real choice is asked")
	assert_ok(g.answer_choice("Grizzly Bears"))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


func test_a_lone_candidate_that_has_gone_still_removes_the_trigger() -> void:
	_human_seat(0)
	var bears := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, Beacon.data())
	g.destroy(bears)
	g._open_priority()
	assert_null(g.awaiting_choice)
	assert_true(g.stack.is_empty(), "CR 603.3d: nothing legal, removed")


func test_two_slots_with_one_candidate_each_are_not_asked() -> void:
	_human_seat(0)
	var bears := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, Twin.data())
	g._open_priority()
	assert_null(g.awaiting_choice, "one opponent, one creature: nothing to ask")
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(bears.damage, 1)


func test_two_slots_with_a_real_choice_are_asked() -> void:
	_human_seat(0)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_synthetic(0, Twin.data())
	g._open_priority()
	assert_not_null(g.awaiting_choice, "two creatures: the creature slot is a choice")


# The AI seat is unchanged: it answers on the spot, and the one-answer
# question stays on the record.
func test_an_ai_seat_still_answers_on_the_spot() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	put_synthetic(0, Beacon.data())
	var item: StackItem = g.stack.back()
	assert_false(item.target_held)
	assert_true(item.targets[0].same_object(TargetRef.card(bears)))
