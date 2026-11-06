extends GameTest
## Pack 10 engine package E8 (part 2) — QUESTIONS A MANA ABILITY ASKS AS IT
## IS ACTIVATED, held open for a human seat by the cost hold
## ([method MtgGame._hold_cost_choice]) and replayed with the answers
## (CR 605.3a: a mana ability never uses the stack, so its activation is
## the only moment the duel can wait for an answer).
##
##  * REVEAL TO PAY (Metalworker: "{T}: Reveal any number of artifact cards
##    in your hand. Add {C}{C} for each card revealed this way." — CR
##    605.1a, 701.16a). [method ManaAbility.with_reveal_from_hand]: how
##    many (an OPTION "0".."N", hint N), then which (a CARD question per
##    card, only when fewer than all are revealed); the cards are revealed
##    to everyone ([method MtgGame.reveal_information], viewer -1) and the
##    ability adds [member ManaAbility.reveal_per_card] × N. The planner
##    counts the seat's own maximum (its own hand — fair).
##  * A MANA TRIGGER'S COLOUR, ASKED BEFORE THE TAP IS PAID (CR 605.1b,
##    106.1, 605.3b). Fertile Ground's "one mana of any color" and Mana
##    Flare's "any type that land produced" used to ask from inside the
##    trigger, after the land was tapped, where a human seat could only get
##    the heuristic. [method MtgGame.tap_for_mana] now finds the mana
##    triggers the tap will fire ([method ManaPlanner.bonus_color_questions]),
##    asks each one's question first and hands the answers to the trigger
##    in the TAPPED_FOR_MANA event's `bonus_colors` ({source id: colour}).
##    A descriptor whose [member TriggeredAbility.mana_bonus_color] is a
##    MASK of several colours (ManaPlanner.BONUS_ANY_COLOR) asks the land's
##    controller a COLOR question; colour 0 ("a type that land produced")
##    asks the tapping player an OPTION among the types the tap made, only
##    when it made more than one.


var revealed: Array = []
var tapped_events: Array = []


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)
	revealed.clear()
	tapped_events.clear()
	g.information_revealed.connect(_on_revealed)
	g.event_occurred.connect(_on_event)


func _on_revealed(viewer: int, title: String, names: Array) -> void:
	revealed.append([viewer, title, names.duplicate()])


func _on_event(event: GameEvent) -> void:
	if event.type == Mtg.EventType.TAPPED_FOR_MANA:
		tapped_events.append(event.data.duplicate())


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


# ----------------------------------------------------------------- cards --

static func _artifact_card(card: CardInstance) -> bool:
	return card.data.is_type(Mtg.CardType.ARTIFACT)


static func _metalworker() -> CardData:
	return CardData.new("Test Metalworker", "{3}", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE).pt(1, 2) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 0).with_reveal_from_hand(_artifact_card, "artifact", 2)) \
		.oracle("{T}: Reveal any number of artifact cards in your hand. Add {C}{C} for each card revealed this way.")


static func _host_tapped(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var land: CardInstance = e.data.get("instance")
	return land != null and land.id == s.attached_to


## Fertile Ground's shape: "its controller adds an additional one mana of
## any color" — the answer the engine took rides the event.
static func _fertile() -> CardData:
	var bonus := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _fertile_mana,
		"Whenever enchanted land is tapped for mana, its controller adds an additional one mana of any color.",
		_host_tapped).as_mana_trigger()
	bonus.mana_bonus_subtype = ManaPlanner.BONUS_ENCHANTED_LAND
	bonus.mana_bonus_color = ManaPlanner.BONUS_ANY_COLOR
	bonus.mana_bonus_amount = 1
	return CardData.new("Test Fertile", "{1}{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)) \
		.triggered(bonus) \
		.oracle("Enchant land\nWhenever enchanted land is tapped for mana, its controller adds an additional one mana of any color.")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


static func _fertile_mana(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var pid := int(e.data.get("controller", -1))
	var color := int((e.data.get("bonus_colors", {}) as Dictionary).get(s.id, -1))
	if not Mtg.WUBRG.has(color):
		color = g.agents[pid].choose_color(g, pid, "fallback", Mtg.ManaColor.G)
	g.players[pid].mana_pool.add(color, 1)


static func _two_type_land() -> CardData:
	return CardData.new("Test Confluence", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.W).and_also(Mtg.ManaColor.U)) \
		.oracle("{T}: Add {W}{U}.")


static func _wastes() -> CardData:
	return CardData.new("Test Wastes", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1)).oracle("{T}: Add {C}.")


func _fertile_on(land: CardInstance, aura_pid := 0) -> CardInstance:
	var aura := give_synthetic(aura_pid, _fertile())
	g.attach_aura_from_anywhere(aura, land, aura_pid)
	g.recalculate()
	assert_eq(aura.attached_to, land.id)
	return aura


func _hand_artifacts(pid: int, names: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for name in names:
		out.append(give_hand(pid, String(name)))
	return out


# ------------------------------------------------------ reveal to pay --

func test_a_heuristic_seat_reveals_every_artifact_card() -> void:
	var worker := put_synthetic(0, _metalworker())
	_hand_artifacts(0, ["Sol Ring", "Ornithopter"])
	give_hand(0, "Grizzly Bears")
	assert_ok(g.tap_for_mana(0, worker))
	assert_null(g.awaiting_choice)
	assert_true(worker.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 4, "{C}{C} for each of two")
	assert_eq(revealed.size(), 1, "one reveal")
	assert_eq(int(revealed[0][0]), -1, "to every player")
	assert_eq((revealed[0][2] as Array).size(), 2)
	assert_true((revealed[0][2] as Array).has("Sol Ring") and (revealed[0][2] as Array).has("Ornithopter"))
	assert_false((revealed[0][2] as Array).has("Grizzly Bears"), "only artifact cards")


func test_a_human_is_held_on_how_many_then_which() -> void:
	_human_seat(0)
	var worker := put_synthetic(0, _metalworker())
	var cards := _hand_artifacts(0, ["Sol Ring", "Ornithopter"])
	assert_ok(g.tap_for_mana(0, worker))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "held on the count")
	assert_eq(asked.kind, PlayerChoice.Kind.OPTION)
	assert_true(asked.is_cost)
	assert_eq(asked.source, "Test Metalworker")
	assert_eq(asked.options, ["0", "1", "2"] as Array[String])
	assert_eq(int(asked.hint), 2, "the default reveals them all")
	assert_false(worker.tapped, "nothing paid while it stands")
	assert_ok(g.answer_choice(1))
	asked = g.awaiting_choice
	assert_not_null(asked, "held on which card")
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_true(asked.is_cost)
	assert_eq(asked.candidates.size(), 2)
	assert_true(asked.is_hand_candidate(cards[1]))
	assert_false(worker.tapped)
	assert_ok(g.answer_choice(cards[1].id))
	assert_null(g.awaiting_choice)
	assert_true(worker.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2)
	assert_eq(revealed.size(), 1)
	assert_eq(revealed[0][2], ["Ornithopter"], "the card they picked, and only it")
	assert_eq(g.unanswered_choices.size(), 0, "both answers were the player's")


func test_revealing_none_is_legal_and_asks_no_card() -> void:
	_human_seat(0)
	var worker := put_synthetic(0, _metalworker())
	_hand_artifacts(0, ["Sol Ring"])
	assert_ok(g.tap_for_mana(0, worker))
	assert_ok(g.answer_choice(0))
	assert_null(g.awaiting_choice)
	assert_true(worker.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(revealed.size(), 0, "nothing revealed")


func test_revealing_all_asks_no_card() -> void:
	_human_seat(0)
	var worker := put_synthetic(0, _metalworker())
	_hand_artifacts(0, ["Sol Ring", "Ornithopter"])
	assert_ok(g.tap_for_mana(0, worker))
	assert_ok(g.answer_choice(2))
	assert_null(g.awaiting_choice, "all of them: nothing to pick")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 4)


func test_no_artifact_card_asks_nothing() -> void:
	_human_seat(0)
	var worker := put_synthetic(0, _metalworker())
	give_hand(0, "Grizzly Bears")
	assert_ok(g.tap_for_mana(0, worker))
	assert_null(g.awaiting_choice)
	assert_true(worker.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_held_reveal_can_be_withdrawn() -> void:
	_human_seat(0)
	var worker := put_synthetic(0, _metalworker())
	_hand_artifacts(0, ["Sol Ring", "Ornithopter"])
	assert_ok(g.tap_for_mana(0, worker))
	assert_ok(g.answer_choice(1))
	assert_ok(g.cancel_choice())
	assert_null(g.awaiting_choice)
	assert_false(worker.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(revealed.size(), 0)


func test_summoning_sickness_refuses_before_any_question() -> void:
	_human_seat(0)
	var worker := put_synthetic(0, _metalworker())
	worker.summoning_sick = true
	_hand_artifacts(0, ["Sol Ring"])
	assert_refused(g.tap_for_mana(0, worker), "summoning sickness")
	assert_null(g.awaiting_choice)
	assert_eq(g.choice_log.size(), 0)


func test_the_planner_counts_the_seats_own_maximum_only() -> void:
	var worker := put_synthetic(0, _metalworker())
	_hand_artifacts(0, ["Sol Ring", "Ornithopter"])
	var own: Array = []
	for row in ManaPlanner.sources(g, 0):
		if row[0] == worker: own = row
	assert_false(own.is_empty())
	assert_eq(int(own[3]), 4, "its own hand: two artifact cards")
	var seen: Array = []
	for row in ManaPlanner.sources(g, 0, {}, true, 1):
		if row[0] == worker: seen = row
	assert_true(seen.is_empty(), "the other seat cannot count a hidden hand (rule 8)")
	assert_false(ManaPlanner.plan(g, 0, ManaCost.parse("{4}"), 0).is_empty())


func test_a_reveal_tap_is_journaled() -> void:
	var worker := put_synthetic(0, _metalworker())
	_hand_artifacts(0, ["Sol Ring"])
	var mark := g.make_mark()
	assert_ok(g.tap_for_mana(0, worker))
	assert_eq(g.players[0].mana_pool.total(), 2)
	g.unmake_to(mark)
	g.end_search()
	assert_false(worker.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)


# ------------------------------------- a mana trigger's colour, first --

func test_fertile_grounds_colour_holds_a_human_before_the_tap() -> void:
	_human_seat(0)
	var forest := put_battlefield(0, "Forest")
	var aura := _fertile_on(forest)
	assert_ok(g.tap_for_mana(0, forest))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "held on the colour")
	assert_eq(asked.kind, PlayerChoice.Kind.COLOR)
	assert_true(asked.is_cost)
	assert_eq(asked.pid, 0)
	assert_eq(asked.source, "Test Fertile")
	assert_eq(asked.prompt, PlayerChoice.mana_color_prompt("Test Fertile"))
	assert_eq(asked.colors, Mtg.WUBRG)
	assert_false(forest.tapped, "the land is not tapped while it stands")
	assert_ok(g.answer_choice(Mtg.ManaColor.U))
	assert_null(g.awaiting_choice)
	assert_true(forest.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1, "the player's own colour")
	assert_eq(tapped_events.size(), 1)
	assert_eq(tapped_events[0].get("bonus_colors"), {aura.id: Mtg.ManaColor.U})
	assert_eq(g.unanswered_choices.size(), 0)
	assert_eq(g.choice_log.size(), 1, "asked once — the trigger asked nothing")


func test_a_heuristic_seat_gets_the_lands_own_colour() -> void:
	var island := put_battlefield(0, "Island")
	_fertile_on(island)
	assert_ok(g.tap_for_mana(0, island))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2,
		"the colour the planner counted is the hint")
	assert_eq(g.choice_log.size(), 1)


func test_a_colorless_land_hints_the_colour_the_own_hand_wants() -> void:
	var wastes := put_synthetic(0, _wastes())
	_fertile_on(wastes)
	give_hand(0, "Counterspell")
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Lightning Bolt")
	assert_ok(g.tap_for_mana(0, wastes))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1, "its own hand, never the opponent's")
	assert_eq(g.players[0].mana_pool.total(), 2)


func test_the_lands_controller_is_asked() -> void:
	# The Aura is seat 0's, the land seat 1's: "its controller adds".
	_human_seat(1)
	var forest := put_battlefield(1, "Forest")
	_fertile_on(forest, 0)
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	assert_ok(g.tap_for_mana(1, forest))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked)
	assert_eq(asked.pid, 1)
	assert_ok(g.answer_choice(Mtg.ManaColor.R))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.R), 1)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_held_colour_can_be_withdrawn() -> void:
	_human_seat(0)
	var forest := put_battlefield(0, "Forest")
	_fertile_on(forest)
	assert_ok(g.tap_for_mana(0, forest))
	assert_ok(g.cancel_choice())
	assert_false(forest.tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(tapped_events.size(), 0)


func test_an_unenchanted_land_asks_nothing() -> void:
	_human_seat(0)
	var forest := put_battlefield(0, "Forest")
	var other := put_battlefield(0, "Forest")
	_fertile_on(forest)
	assert_ok(g.tap_for_mana(0, other))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].mana_pool.total(), 1)
	assert_false(tapped_events[0].has("bonus_colors"), "nothing asked, nothing carried")


func test_mana_flare_asks_a_human_among_the_types_before_the_tap() -> void:
	_human_seat(0)
	put_battlefield(1, "Mana Flare")
	var land := put_synthetic(0, _two_type_land())
	assert_ok(g.tap_for_mana(0, land))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "held on Mana Flare's type")
	assert_eq(asked.kind, PlayerChoice.Kind.OPTION)
	assert_true(asked.is_cost)
	assert_eq(asked.source, "Mana Flare")
	assert_eq(asked.prompt, "Mana Flare: What kind of mana?")
	assert_eq(asked.options, ["White", "Blue"] as Array[String])
	assert_false(land.tapped)
	assert_ok(g.answer_choice(1))
	assert_true(land.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 2, "the bonus is the type they named")
	assert_eq(g.unanswered_choices.size(), 0)


func test_two_mana_flares_ask_twice() -> void:
	_human_seat(0)
	put_battlefield(1, "Mana Flare")
	put_battlefield(0, "Mana Flare")
	var land := put_synthetic(0, _two_type_land())
	assert_ok(g.tap_for_mana(0, land))
	assert_ok(g.answer_choice(1))
	assert_not_null(g.awaiting_choice, "a separate choice for each Mana Flare")
	assert_ok(g.answer_choice(1))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 3)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 1)


func test_mana_flare_on_a_one_type_land_asks_nobody() -> void:
	_human_seat(0)
	put_battlefield(1, "Mana Flare")
	var forest := put_battlefield(0, "Forest")
	assert_ok(g.tap_for_mana(0, forest))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 2)


func test_the_planner_counts_an_any_colour_bonus_as_the_lands_colour() -> void:
	var island := put_battlefield(0, "Island")
	_fertile_on(island)
	var wastes := put_synthetic(0, _wastes())
	_fertile_on(wastes)
	for row in ManaPlanner.sources(g, 0):
		if row[0] == island:
			assert_eq(int(row[2]), Mtg.ManaColor.U)
			assert_eq(int(row[3]), 2, "the bonus counted as blue")
		if row[0] == wastes:
			assert_eq(int(row[3]), 2, "a colourless land's bonus counts as generic")
	assert_eq(ManaPlanner.bonus_color_for(0, Mtg.ManaColor.R), Mtg.ManaColor.R)
	assert_eq(ManaPlanner.bonus_color_for(Mtg.ManaColor.G, Mtg.ManaColor.R), Mtg.ManaColor.G)
	assert_eq(ManaPlanner.bonus_color_for(ManaPlanner.BONUS_ANY_COLOR, Mtg.ManaColor.R), Mtg.ManaColor.R)
	assert_eq(ManaPlanner.bonus_color_for(ManaPlanner.BONUS_ANY_COLOR, Mtg.ManaColor.C), Mtg.ManaColor.C)


func test_an_auto_pay_plan_stops_on_the_question_and_finishes_after() -> void:
	_human_seat(0)
	var forest := put_battlefield(0, "Forest")
	_fertile_on(forest)
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{G}{G}"), 0)
	assert_eq(plan.size(), 1, "one Forest pays {G}{G} with its bonus")
	assert_false(ManaPlanner.run_plan(g, 0, plan), "the run stops on the held question")
	assert_not_null(g.awaiting_choice)
	assert_ok(g.answer_choice(Mtg.ManaColor.G))
	assert_true(g.players[0].mana_pool.can_pay(ManaCost.parse("{G}{G}")))
