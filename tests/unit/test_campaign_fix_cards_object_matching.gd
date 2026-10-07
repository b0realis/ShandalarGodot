extends GameTest
## Whole-game campaign 2026-10, finding w7-1 (fix-cards): the "distinct
## objects" check behind every additional object cost
## (engine/additional_object_costs.gd) was an ordering search — with one
## slot more than there were cards it walked every permutation before it
## could say no. Holding Firestorm ("discard X cards") with ten cards in
## hand froze the host for seconds on every view, X window and AI turn
## (max_x asks for X + 1 slots until that fails). Haunting Misery (exile X
## creature cards from your graveyard) and Infernal Harvest (return X
## Swamps) share it.
##
## Pinned here: the check is a matching (polynomial), max_x is one largest
## matching, and every caller's contract — can_assign(slots, index, used),
## refusal, max_x (-1 without an X group, 0 when even X = 0 cannot pay),
## choose offering only extendable picks — is unchanged.

const OC := preload("res://engine/additional_object_costs.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super.before_each()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	CardPacks.set_enabled("pack-8", false)


static func _creature_card(c: CardInstance) -> bool:
	return c.data.is_creature()

static func _land_card(c: CardInstance) -> bool:
	return c.data.is_land()


func _storm() -> CardData:
	return CardData.new("Synthetic Storm", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(0).x_damage().target_player()) \
		.with_object_cost(OC.times_x(OC.discarding("a card"))).oracle("...")


func _slot(cards: Array) -> Dictionary:
	return {"group": OC.discarding("card"), "cards": cards}


# ------------------------------------------------------------- speed (w7-1) --

func test_max_x_for_firestorm_with_a_big_hand_is_immediate() -> void:
	var firestorm := give_hand(0, "Firestorm")
	for i in 14:
		give_hand(0, "Grizzly Bears")
	var groups := g.spell_object_costs(firestorm.data, 0, 0, firestorm)
	var t0 := Time.get_ticks_msec()
	var x := OC.max_x(g, 0, groups, firestorm)
	var ms := Time.get_ticks_msec() - t0
	assert_eq(x, 14, "every other card in hand, never Firestorm itself")
	assert_lt(ms, 100, "max X with fourteen other cards in hand, ms")


func test_refusing_one_card_too_many_is_immediate() -> void:
	var firestorm := give_hand(0, "Firestorm")
	for i in 12:
		give_hand(0, "Grizzly Bears")
	var groups := g.spell_object_costs(firestorm.data, 0, 0, firestorm)
	var t0 := Time.get_ticks_msec()
	assert_eq(OC.refusal(g, 0, groups, firestorm, 12), "")
	assert_ne(OC.refusal(g, 0, groups, firestorm, 13), "", "thirteen discards from twelve cards")
	assert_ne(OC.refusal(g, 0, groups, firestorm, 500), "")
	assert_lt(Time.get_ticks_msec() - t0, 100, "three refusal checks, ms")


func test_haunting_misery_with_a_full_graveyard_is_immediate() -> void:
	var misery := give_hand(0, "Haunting Misery")
	for i in 40:
		var body := CardInstance.new(CardRegistry.get_card("Grizzly Bears" if i % 3 else "Lightning Bolt"),
			g._next_instance_id, 0)
		g._next_instance_id += 1
		g._instances[body.id] = body
		body.zone = Mtg.Zone.GRAVEYARD
		g.players[0].graveyard.append(body)
	var groups := g.spell_object_costs(misery.data, 0, 0, misery)
	var t0 := Time.get_ticks_msec()
	var x := OC.max_x(g, 0, groups, misery)
	assert_eq(x, 26, "the creature cards only (26 of 40)")
	assert_eq(OC.refusal(g, 0, groups, misery, 26), "")
	assert_ne(OC.refusal(g, 0, groups, misery, 27), "")
	assert_lt(Time.get_ticks_msec() - t0, 250, "max X and two refusals over 40 graveyard cards, ms")


func test_the_x_window_choice_walk_stays_fast_at_the_top_x() -> void:
	# choose() offers only picks the remaining slots can still be paid
	# around; at X = hand size that is a check per candidate per slot.
	g.interactive_choices = false
	var fire := give_synthetic(0, _storm())
	var others: Array = []
	for i in 10:
		others.append(give_hand(0, "Grizzly Bears"))
	add_mana(0, Mtg.ManaColor.R, 1)
	var t0 := Time.get_ticks_msec()
	assert_ok(g.cast_spell(0, fire, [TargetRef.player(1)], 10))
	assert_lt(Time.get_ticks_msec() - t0, 500, "casting with X = 10 discards, ms")
	for c in others:
		assert_eq(c.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------- contract (w7-1) --

func test_can_assign_finds_the_assignment_a_greedy_pick_misses() -> void:
	var a := give_hand(0, "Grizzly Bears")
	var b := give_hand(0, "Grizzly Bears")
	var c := give_hand(0, "Grizzly Bears")
	# Slot 0 takes a or b, slot 1 only a: the first-come pick (a) must move.
	assert_true(OC.can_assign([_slot([a, b]), _slot([a])]))
	assert_false(OC.can_assign([_slot([a]), _slot([a])]), "one card, two slots")
	assert_false(OC.can_assign([_slot([a, b]), _slot([a, b]), _slot([a, b, c]), _slot([b])]),
		"four slots, three cards")
	assert_true(OC.can_assign([_slot([a, b]), _slot([b, c]), _slot([a, c])]))
	# A chain: every slot's first card is the previous slot's only card.
	assert_true(OC.can_assign([_slot([a, b]), _slot([b, c]), _slot([c])]))
	assert_false(OC.can_assign([_slot([a, b]), _slot([b, c]), _slot([c]), _slot([])]), "an empty slot")
	assert_true(OC.can_assign([]), "nothing to pay")


func test_can_assign_honours_its_start_index_and_used_cards() -> void:
	var a := give_hand(0, "Grizzly Bears")
	var b := give_hand(0, "Grizzly Bears")
	var slots := [_slot([a]), _slot([a, b]), _slot([b])]
	assert_false(OC.can_assign(slots), "slot 1 has nothing left")
	assert_true(OC.can_assign(slots, 1), "from slot 1 on: a then b")
	assert_false(OC.can_assign(slots, 1, {a.id: true}), "a already taken")
	assert_true(OC.can_assign(slots, 2, {a.id: true}))
	assert_false(OC.can_assign(slots, 2, {b.id: true}))
	assert_true(OC.can_assign(slots, 3, {a.id: true, b.id: true}), "past the end: nothing left to pay")


func test_max_x_keeps_its_contract() -> void:
	var fire := give_synthetic(0, _storm())
	assert_eq(OC.max_x(g, 0, fire.data.object_costs, fire), 0, "an empty hand: X = 0")
	assert_eq(OC.max_x(g, 0, [OC.discarding("a card")], fire), -1, "no X group")
	give_hand(0, "Forest")
	give_hand(0, "Grizzly Bears")
	assert_eq(OC.max_x(g, 0, fire.data.object_costs, fire), 2)


func test_max_x_shares_cards_with_a_fixed_group() -> void:
	# "Discard a land card" AND "discard X cards": the land is spoken for.
	var fire := give_synthetic(0, _storm())
	var groups := [OC.discarding("land card", _land_card), OC.times_x(OC.discarding("a card"))]
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Grizzly Bears")
	assert_eq(OC.max_x(g, 0, groups, fire), 0, "no land: the fixed slot cannot pay (contract: 0)")
	give_hand(0, "Forest")
	assert_eq(OC.max_x(g, 0, groups, fire), 2, "the Forest pays the land slot, the bears pay X")
	give_hand(0, "Forest")
	assert_eq(OC.max_x(g, 0, groups, fire), 3)
	# Two X groups move together: X creature cards AND X land cards.
	var both := [OC.times_x(OC.discarding("creature card", _creature_card)),
		OC.times_x(OC.discarding("land card", _land_card))]
	assert_eq(OC.max_x(g, 0, both, fire), 2, "two bears, two Forests")
	give_hand(0, "Grizzly Bears")
	assert_eq(OC.max_x(g, 0, both, fire), 2, "the third bear has no Forest to pair with")
	# Agreement with the step-by-step reading for every X.
	for groups_case in [groups, both, fire.data.object_costs]:
		var bound := OC.max_x(g, 0, groups_case, fire)
		assert_eq(OC.refusal(g, 0, groups_case, fire, bound), "")
		assert_ne(OC.refusal(g, 0, groups_case, fire, bound + 1), "")


func test_choose_still_offers_only_picks_the_rest_can_pay_around() -> void:
	# Discard a land card AND discard X cards (X = 2) from Forest, Bear,
	# Bear: the first (X) ask may not take the Forest — the land slot needs it.
	var fire := give_synthetic(0, _storm())
	var forest := give_hand(0, "Forest")
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Grizzly Bears")
	var groups := [OC.times_x(OC.discarding("a card")), OC.discarding("land card", _land_card)]
	var asked: Array = []
	g.set_agent(0, _Recorder.new(asked))
	var picks := OC.choose(g, 0, fire, groups, {}, 2)
	assert_eq(picks.size(), 3)
	assert_false(asked.is_empty(), "the payer chose")
	assert_false(forest in asked[0], "the Forest is not offered to the X discards")
	assert_eq(picks[2].card, forest, "the land slot gets it")


## Records every card ask's candidates and takes the first.
class _Recorder extends DecisionAgent:
	var sink: Array
	func _init(into: Array) -> void:
		sink = into
	func answer_card(_game: MtgGame, _pid: int,
			candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		sink.append(candidates.duplicate())
		return candidates[0]


## [method extendable] is exactly "the candidates can_assign can extend",
## on random slot shapes (seeded): what choose() offers did not change.
func test_extendable_matches_the_per_candidate_check() -> void:
	var cards: Array = []
	for i in 7:
		cards.append(give_hand(0, "Grizzly Bears"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7101
	var checked := 0
	for trial in 300:
		var slots: Array = []
		for s in rng.randi_range(1, 6):
			var pool: Array[CardInstance] = []
			for c in cards:
				if rng.randf() < 0.45: pool.append(c)
			slots.append({"group": OC.discarding("card"), "cards": pool})
		var used := {}
		for c in cards:
			if rng.randf() < 0.15: used[c.id] = true
		for index in slots.size():
			var expected: Array = []
			for c in slots[index].cards:
				if used.has(c.id): continue
				var next := used.duplicate()
				next[c.id] = true
				if OC.can_assign(slots, index + 1, next): expected.append(c)
			assert_eq(Array(OC.extendable(slots, index, used)), expected,
				"trial %d slot %d" % [trial, index])
			checked += 1
	assert_gt(checked, 300)


## The ordering search can_assign used to be — the reference the matching
## is checked against on small random shapes.
static func _by_search(slots: Array, index: int, used: Dictionary) -> bool:
	if index >= slots.size(): return true
	for card in slots[index].cards:
		if used.has(card.id): continue
		var next := used.duplicate()
		next[card.id] = true
		if _by_search(slots, index + 1, next): return true
	return false


func test_can_assign_agrees_with_the_ordering_search() -> void:
	var cards: Array = []
	for i in 6:
		cards.append(give_hand(0, "Grizzly Bears"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7102
	var yes := 0
	var no := 0
	for trial in 400:
		var slots: Array = []
		for s in rng.randi_range(1, 7):
			var pool: Array[CardInstance] = []
			for c in cards:
				if rng.randf() < 0.4: pool.append(c)
			slots.append({"group": OC.discarding("card"), "cards": pool})
		var used := {}
		for c in cards:
			if rng.randf() < 0.1: used[c.id] = true
		var index := rng.randi_range(0, slots.size() - 1)
		var want := _by_search(slots, index, used)
		assert_eq(OC.can_assign(slots, index, used), want, "trial %d" % trial)
		if want: yes += 1
		else: no += 1
	assert_gt(yes, 30, "both answers are exercised")
	assert_gt(no, 30)
