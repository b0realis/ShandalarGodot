extends GameTest
## Pack 9 (the Tempest block), the fair AI's COUNTERSPELLS (stage 4,
## casting; engine package E6, [member AiProfile.forecasts_tactics]).
##
## 1. "THIS SPELL CAN'T BE COUNTERED" (Scragnoth). The shared
##    [CounterEffect] already declined it ([method CounterEffect.affects_spell]);
##    the card-local counters the reader finds by their printed line —
##    Power Sink, Mana Drain, Spell Blast, Force Spike — did not, and were
##    thrown at a spell [method MtgGame.counter_spell] leaves on the stack.
##    So was Ertai, Wizard Adept's activation.
## 2. ERTAI'S MEDDLING exiles the spell with X delay counters (not a
##    counter, CR 701.5a — it works on Scragnoth). It answers a spell that
##    clears the counter bar when no counter in hand does, at the largest
##    X the mana pays, and never one of ours.
## With the gate off the counters fire as they did before Pack 9 and the
## Meddling is never cast. The opponent's hidden hand never moves a
## decision.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)


## P1 casts [param spell] in its first main phase (P1's mana given) and
## passes: P0 holds priority over it.
func _they_cast(spell: String, color: int, amount: int) -> CardInstance:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	var card := give_hand(1, spell)
	add_mana(1, color, amount)
	assert_ok(g.cast_spell(1, card, []))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return card


# ------------------------------------------------------- "can't be countered" --

func test_no_card_local_counter_answers_scragnoth() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	var hand: Array = []
	for card_name in ["Power Sink", "Mana Drain", "Spell Blast", "Force Spike"]:
		hand.append(give_hand(0, card_name))
	var scragnoth := _they_cast("Scragnoth", Mtg.ManaColor.G, 5)
	var ref := TargetRef.card(scragnoth)
	for card in hand:
		assert_null(ai._counter_spec(g, card, ref), card.data.card_name)
	ai.act(g)
	for card in hand:
		assert_eq(card.zone, Mtg.Zone.HAND, card.data.card_name + " kept")
	resolve_stack()
	assert_eq(scragnoth.zone, Mtg.Zone.BATTLEFIELD)


func test_the_null_arm_still_names_scragnoth() -> void:
	var ai := _ai(false)
	_lands(0, "Island", 6)
	var sink := give_hand(0, "Power Sink")
	var scragnoth := _they_cast("Scragnoth", Mtg.ManaColor.G, 5)
	assert_not_null(ai._counter_spec(g, sink, TargetRef.card(scragnoth)),
		"gate off: the printed line, as before Pack 9")


func test_a_counter_still_answers_a_spell_that_can_be_countered() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	var sink := give_hand(0, "Power Sink")
	var angel := _they_cast("Serra Angel", Mtg.ManaColor.W, 5)
	assert_not_null(ai._counter_spec(g, sink, TargetRef.card(angel)))


# ---------------------------------------------------------------- Ertai's Meddling --

func test_meddling_delays_their_angel_with_every_spare_mana() -> void:
	var ai := _ai()
	_lands(0, "Island", 4)
	var meddling := give_hand(0, "Ertai's Meddling")
	var angel := _they_cast("Serra Angel", Mtg.ManaColor.W, 5)
	assert_string_contains(ai.act(g), "Ertai's Meddling")
	resolve_stack()
	assert_eq(meddling.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.zone, Mtg.Zone.EXILE)
	assert_eq(int(angel.counters.get("delay", 0)), 3, "{U} + X=3 from four Islands")


func test_meddling_answers_what_a_counter_cannot() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	var sink := give_hand(0, "Power Sink")
	give_hand(0, "Ertai's Meddling")
	var scragnoth := _they_cast("Scragnoth", Mtg.ManaColor.G, 5)
	assert_string_contains(ai.act(g), "Ertai's Meddling")
	resolve_stack()
	assert_eq(scragnoth.zone, Mtg.Zone.EXILE)
	assert_eq(sink.zone, Mtg.Zone.HAND)


func test_a_hard_counter_comes_before_the_meddling() -> void:
	var ai := _ai()
	_lands(0, "Island", 6)
	var counterspell := give_hand(0, "Counterspell")
	var meddling := give_hand(0, "Ertai's Meddling")
	var angel := _they_cast("Serra Angel", Mtg.ManaColor.W, 5)
	assert_string_contains(ai.act(g), "Counterspell")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(counterspell.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(meddling.zone, Mtg.Zone.HAND)


func test_the_null_arm_never_meddles() -> void:
	var ai := _ai(false)
	_lands(0, "Island", 4)
	var meddling := give_hand(0, "Ertai's Meddling")
	var angel := _they_cast("Serra Angel", Mtg.ManaColor.W, 5)
	ai.act(g)
	assert_eq(meddling.zone, Mtg.Zone.HAND)
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)


func test_the_meddling_ignores_their_hidden_hand() -> void:
	var zones: Array = []
	for hand in [["Counterspell", "Giant Growth"], ["Forest"], []]:
		g = null
		before_each()
		var ai := _ai()
		_lands(0, "Island", 4)
		give_hand(0, "Ertai's Meddling")
		var guard := 0
		while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) and guard < 400:
			_advance_once()
			guard += 1
		for card_name in hand: give_hand(1, card_name)
		var angel := give_hand(1, "Serra Angel")
		add_mana(1, Mtg.ManaColor.W, 5)
		assert_ok(g.cast_spell(1, angel, []))
		assert_ok(g.pass_priority(1))
		ai.act(g)
		resolve_stack()
		zones.append(angel.zone)
	assert_eq(zones, [Mtg.Zone.EXILE, Mtg.Zone.EXILE, Mtg.Zone.EXILE])
