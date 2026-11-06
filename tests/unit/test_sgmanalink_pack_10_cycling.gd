extends GameTest
## Pack 10 engine package E2 — CYCLING ACROSS THE REFEREE BOUNDARY. A hand
## ability (cycling, CR 702.29a) is offered by the referee's action list
## (`SgDuelActions.options`) as the existing "ability" action of a HAND
## card — to the card's OWNER only, never to the other seat — and the
## announcement (`prepare`), the payment and the submit run the engine's
## own activation. No new action kind crosses the wire.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func referee() -> SgPracticeMatch:
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	g.interactive_choices = true
	duel.view(0)
	return duel


static func _is_enchantment(c: CardInstance) -> bool:
	return c.is_type(Mtg.CardType.ENCHANTMENT)


static func _clear() -> CardData:
	return CardData.new("Test Clear", "{1}{W}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment",
			_is_enchantment))) \
		.with_cycling()


static func _landscape() -> CardData:
	return CardData.new("Test Landscape", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1)) \
		.with_cycling()


static func _abilities(options: Array) -> Array:
	return options.filter(func(option: Dictionary) -> bool: return option.kind == "ability")


static func _cycling_index(inst: CardInstance) -> int:
	for i in inst.cur_activated_abilities.size():
		if inst.cur_activated_abilities[i].is_cycling:
			return i
	return -1


func test_the_owner_is_offered_cycling_and_the_other_seat_is_not() -> void:
	var clear := give_synthetic(0, _clear())
	add_mana(0, Mtg.ManaColor.C, 2)
	var duel := referee()
	var mine := _abilities(SgDuelActions.options(clear, 0, g))
	assert_eq(mine.size(), 1, "the owner's hand card offers its cycling")
	assert_eq(int(mine[0].index), _cycling_index(clear))
	assert_string_contains(String(mine[0].label), "Cycling {2}")
	assert_false(bool(mine[0].x))
	assert_true(_abilities(SgDuelActions.options(clear, 1, g)).is_empty(), "never the other seat")
	# The projection's own reading (no referee at hand) asks the owner too.
	assert_eq(_abilities(SgDuelActions.options(clear, 0)).size(), 1)
	assert_true(_abilities(SgDuelActions.options(clear, 1)).is_empty())
	# The option rides the existing DTO: a valid view at both seats.
	assert_true(SgViewProtocol.game(duel.view(0)))
	assert_true(SgViewProtocol.game(duel.view(1)))


func test_cycling_is_announced_paid_and_submitted_through_the_referee() -> void:
	var clear := give_synthetic(0, _clear())
	add_mana(0, Mtg.ManaColor.C, 2)
	var duel := referee()
	var hand_before := g.players[0].hand.size()
	assert_ok(duel.act(0, {"op": "prepare", "card": duel._handle(0, clear),
		"kind": "ability", "index": _cycling_index(clear), "x": 0, "mode": 0}))
	assert_ok(duel.act(0, {"op": "submit", "targets": []}))
	assert_eq(clear.zone, Mtg.Zone.GRAVEYARD, "discarded as the cost, by the engine")
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand_before, "one out, one drawn")


func test_the_other_seat_cannot_announce_my_cycling() -> void:
	var clear := give_synthetic(0, _clear())
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 2)
	var duel := referee()
	var error := duel.act(1, {"op": "prepare", "card": duel._handle(1, clear),
		"kind": "ability", "index": _cycling_index(clear), "x": 0, "mode": 0})
	assert_ne(error, "", "refused")
	assert_eq(clear.zone, Mtg.Zone.HAND)


func test_a_cycling_land_offers_cycling_in_hand_and_only_mana_on_the_table() -> void:
	var land := give_synthetic(0, _landscape())
	add_mana(0, Mtg.ManaColor.C, 2)
	referee()
	var options := SgDuelActions.options(land, 0, g)
	assert_eq(_abilities(options).size(), 1)
	assert_true(options.filter(func(option: Dictionary) -> bool: return option.kind == "spell").is_empty(),
		"a land is played, not cast")
	var placed := put_synthetic(0, _landscape())
	var table := SgDuelActions.options(placed, 0, g)
	assert_true(_abilities(table).is_empty(), "no cycling from the battlefield")
	assert_eq(table.filter(func(option: Dictionary) -> bool: return option.kind == "mana").size(), 1)


func test_cycling_is_not_offered_without_reachable_mana() -> void:
	var clear := give_synthetic(0, _clear())
	referee()
	assert_true(_abilities(SgDuelActions.options(clear, 0, g)).is_empty(),
		"an option is never a payment the submit refuses")
	put_synthetic(0, _landscape())
	put_synthetic(0, _landscape())
	assert_eq(_abilities(SgDuelActions.options(clear, 0, g)).size(), 1, "two lands to tap")
