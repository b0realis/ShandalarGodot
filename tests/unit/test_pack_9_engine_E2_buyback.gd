extends GameTest
## Pack 9 engine package E2 — BUYBACK and BUYBACK COST REDUCTION.
##
## - M_BUYBACK: "Buyback <cost> (You may pay an additional <cost> as you
##   cast this spell. If you do, put this card into your hand as it
##   resolves.)" — an OPTIONAL ADDITIONAL cost announced with the spell
##   (CR 702.27a, 118.8, 601.2b) and paid with the rest of it (601.2f-h).
##   It is a PAYMENT ROW ([method CardData.with_buyback]) beside the printed
##   one, so the mode index that already travels through cast_spell, the
##   duel screen, SGManalink and the AI carries the choice — cast_spell has
##   no new parameter. A RESOLVED spell whose buyback was paid goes to its
##   OWNER's hand (608.2n); a countered or fizzled one goes to the graveyard
##   as always; a COPY is not a card and simply ceases to exist (707.10a).
## - M_BUYBACK_DISCOUNT: "Buyback costs cost {2} less" (Memory Crystal) —
##   only the GENERIC part of the buyback, never below zero, never the rest
##   of the spell's cost ([method CardData.with_buyback_modifier]); a static
##   ability, so a tapped one stops under the 1997 rules
##   (RulesOptions.tapped_artifacts_stop).

const OC := preload("res://engine/additional_object_costs.gd")


# ------------------------------------------------------------- synthetics --

static func _is_land(i: CardInstance) -> bool:
	return i.is_land()


## Searing Touch's shape: {R}, 1 damage to any target, buyback {4}.
func _touch(buyback := "{4}", cost := "{R}") -> CardData:
	return CardData.new("Test Touch", cost, Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(1).any_target()) \
		.with_buyback({"mana": buyback})


## Mind Games' buyback shape: a coloured buyback ({2}{U}).
func _games() -> CardData:
	return CardData.new("Test Games", "{U}", Mtg.CardType.INSTANT) \
		.spell(DrawEffect.new(1)) \
		.with_buyback({"mana": "{2}{U}"})


## Constant Mists' shape: "Buyback—Sacrifice a land."
func _mists() -> CardData:
	return CardData.new("Test Mists", "{G}", Mtg.CardType.INSTANT) \
		.spell(GainLifeEffect.new(2)) \
		.with_buyback({"object_costs": [OC.sacrificing("a land", _is_land)],
			"text": "Sacrifice a land"})


## Forbid's shape: "Buyback—Discard two cards."
func _forbid() -> CardData:
	return CardData.new("Test Forbid", "{1}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(CounterEffect.new()) \
		.with_buyback({"object_costs": [OC.discarding("card", Callable(), 2)],
			"text": "Discard two cards"})


## Slaughter's shape: "Buyback—Pay 4 life."
func _slaughter() -> CardData:
	return CardData.new("Test Slaughter", "{B}", Mtg.CardType.SORCERY) \
		.spell(GainLifeEffect.new(1)) \
		.with_buyback({"life": 4, "text": "Pay 4 life"})


## Fanning the Flames' shape: {X}{R}, X damage to any target, buyback {3}.
func _fanning() -> CardData:
	return CardData.new("Test Fanning", "{X}{R}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(0).x_damage().any_target()) \
		.with_buyback({"mana": "{3}"})


## Memory Crystal's shape: "Buyback costs cost {2} less."
func _crystal() -> CardData:
	return CardData.new("Test Crystal", "{3}", Mtg.CardType.ARTIFACT) \
		.with_buyback_modifier(func(_g: MtgGame, _pid: int, _data: CardData,
				_source: CardInstance) -> int: return -2)


func _bear() -> CardData:
	return CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)


func _to_exile(inst: CardInstance) -> void:
	g.players[inst.owner_id].hand.erase(inst)
	inst.zone = Mtg.Zone.EXILE
	g.players[inst.owner_id].exile.append(inst)


func _pool(pid: int) -> int:
	return g.players[pid].mana_pool.total()


# --------------------------------------------------------- the row itself --

func test_the_buyback_row_follows_the_printed_row_and_keeps_the_mana_value() -> void:
	var data := _touch()
	assert_eq(data.modes.size(), 2, "the printed row, then the buyback row")
	assert_true(data.payment_option(0).is_empty(), "row 0 pays the printed cost")
	assert_true(bool(data.payment_option(1).get("buyback", false)))
	assert_eq(data.buyback_rows(), [1])
	assert_true(data.has_buyback())
	assert_eq(data.cost.mana_value(), 1, "an additional cost never changes the mana value (CR 118.8d)")
	assert_string_contains(String(data.modes[1]["label"]), "buyback")
	assert_eq(data.modes[1]["effects"], data.modes[0]["effects"], "the same spell either way")
	assert_eq(g.spell_cost_for(0, data, 0, 1).mana_value(), 5, "{R} plus {4}")
	assert_eq(g.spell_cost_for(0, data, 0, 0).mana_value(), 1)


func test_unpaid_buyback_goes_to_the_graveyard() -> void:
	var touch := give_synthetic(0, _touch())
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	assert_eq(touch.zone, Mtg.Zone.GRAVEYARD)


func test_paid_buyback_returns_the_card_to_its_owners_hand() -> void:
	var touch := give_synthetic(0, _touch())
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
	assert_eq(_pool(0), 0, "the printed {R} and the buyback {4} were both paid")
	assert_true(g.buyback_paid(touch), "the stack knows the buyback was paid")
	resolve_stack()
	assert_eq(g.players[1].life, 19, "the spell did its work first")
	assert_eq(touch.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(touch))
	assert_false(g.players[0].graveyard.has(touch))


func test_unaffordable_buyback_is_refused_and_nothing_is_paid() -> void:
	var touch := give_synthetic(0, _touch())
	add_mana(0, Mtg.ManaColor.R, 4)
	assert_refused(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1), "not enough mana")
	assert_eq(_pool(0), 4, "a refused cast pays nothing (CR 601.2h)")
	assert_eq(touch.zone, Mtg.Zone.HAND)
	assert_true(g.stack.is_empty())


func test_a_countered_buyback_spell_goes_to_the_graveyard() -> void:
	var touch := give_synthetic(0, _touch())
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
	assert_ok(g.pass_priority(0))
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(touch)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)
	assert_eq(touch.zone, Mtg.Zone.GRAVEYARD, "countered: it never resolved (CR 702.27a)")


func test_a_fizzled_buyback_spell_goes_to_the_graveyard() -> void:
	var bear := put_synthetic(1, _bear())
	var touch := give_synthetic(0, _touch())
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, touch, [TargetRef.card(bear)], 0, 1))
	g.destroy(bear)
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.GRAVEYARD, "no legal target: it doesn't resolve (CR 608.2b)")


func test_a_copy_of_a_buyback_spell_ceases_to_exist_and_the_original_returns() -> void:
	var touch := give_synthetic(0, _touch())
	add_mana(0, Mtg.ManaColor.R, 7)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
	var fork := give_hand(0, "Fork")
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(touch)]))
	resolve_stack()
	assert_eq(g.players[1].life, 18, "the original and its copy each dealt 1")
	assert_eq(touch.zone, Mtg.Zone.HAND)
	var touches := 0
	for card in g.players[0].hand + g.players[0].graveyard:
		if card.data.card_name == "Test Touch":
			touches += 1
	assert_eq(touches, 1, "the copy is not a card and went nowhere (CR 707.10a)")
	assert_eq(fork.zone, Mtg.Zone.GRAVEYARD)


func test_the_card_returns_to_its_owners_hand_not_its_casters() -> void:
	var touch := give_synthetic(0, _touch())
	_to_exile(touch)
	g.grant_exile_play(touch, 1)
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)
	add_mana(1, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(1, touch, [TargetRef.player(0)], 0, 1))
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	assert_true(g.players[0].hand.has(touch), "its OWNER's hand (CR 702.27a)")
	assert_false(g.players[1].hand.has(touch))


func test_a_coloured_buyback_needs_its_colour() -> void:
	var games := give_synthetic(0, _games())
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_refused(g.cast_spell(0, games, [], 0, 1), "not enough mana")
	assert_eq(_pool(0), 4)
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, games, [], 0, 1))
	resolve_stack()
	assert_eq(games.zone, Mtg.Zone.HAND)


func test_x_is_announced_with_the_buyback_on_top() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var fanning := give_synthetic(0, _fanning())
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_refused(g.cast_spell(0, fanning, [TargetRef.player(1)], 2, 1), "not enough mana")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, fanning, [TargetRef.player(1)], 2, 1))
	assert_eq(_pool(0), 0, "{X}{R} at X=2 plus {3}: six mana")
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_eq(fanning.zone, Mtg.Zone.HAND)
	assert_false(fanning.memory.has("x_value"), "X is forgotten off the stack (CR 107.3b)")


# ----------------------------------------------------- non-mana buybacks --

func test_sacrifice_a_land_buyback_is_paid_as_the_spell_is_cast() -> void:
	var forest := put_battlefield(0, "Forest")
	var mists := give_synthetic(0, _mists())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, mists, [], 0, 1))
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the land is a cost, paid at once (CR 601.2h)")
	resolve_stack()
	assert_eq(g.players[0].life, 22)
	assert_eq(mists.zone, Mtg.Zone.HAND)


func test_a_land_buyback_with_no_land_is_refused_before_anything_is_paid() -> void:
	var mists := give_synthetic(0, _mists())
	add_mana(0, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(0, mists, [], 0, 1))
	assert_eq(_pool(0), 1, "nothing paid")
	assert_eq(mists.zone, Mtg.Zone.HAND)
	assert_ne(g.spell_announce_refusal(0, mists, 0, 1), "", "the network's options agree")
	assert_eq(g.spell_announce_refusal(0, mists, 0, 0), "", "the printed row stays open")


func test_a_discard_two_buyback_needs_two_other_cards() -> void:
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	var forbid := give_synthetic(0, _forbid())
	var spare := give_hand(0, "Forest")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_refused(g.cast_spell(0, forbid, [TargetRef.card(bolt)], 0, 1), "additional cost")
	assert_eq(spare.zone, Mtg.Zone.HAND, "the spell itself is not a card to discard")
	assert_eq(_pool(0), 3)
	var spare2 := give_hand(0, "Forest")
	assert_ok(g.cast_spell(0, forbid, [TargetRef.card(bolt)], 0, 1))
	assert_eq(spare.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(spare2.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "the Bolt was countered")
	assert_eq(forbid.zone, Mtg.Zone.HAND)


func test_a_life_buyback_needs_the_life() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var slaughter := give_synthetic(0, _slaughter())
	g.players[0].life = 3
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.cast_spell(0, slaughter, [], 0, 1), "life")
	assert_eq(g.players[0].life, 3)
	assert_eq(_pool(0), 1)
	g.players[0].life = 10
	assert_ok(g.cast_spell(0, slaughter, [], 0, 1))
	assert_eq(g.players[0].life, 6, "the 4 life is paid as it is cast")
	resolve_stack()
	assert_eq(g.players[0].life, 7)
	assert_eq(slaughter.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------ the presets --

func test_buyback_under_the_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	var touch := give_synthetic(0, _touch())
	add_mana(0, Mtg.ManaColor.R, 5)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 0))
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 18)


func test_cast_again_and_again() -> void:
	var touch := give_synthetic(0, _touch())
	for i in 3:
		add_mana(0, Mtg.ManaColor.R, 5)
		assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
		resolve_stack()
		assert_eq(touch.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 17)


# --------------------------------------------------------- Memory Crystal --

func test_crystal_reduces_a_generic_buyback() -> void:
	put_synthetic(0, _crystal())
	var touch := give_synthetic(0, _touch())
	assert_eq(g.spell_cost_for(0, touch.data, 0, 1).mana_value(), 3, "{R} plus {4} less {2}")
	assert_eq(g.spell_cost_for(0, touch.data, 0, 0).mana_value(), 1, "no buyback, no discount")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
	assert_eq(_pool(0), 0)
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.HAND)


func test_crystal_never_touches_a_coloured_buyback_pip() -> void:
	put_synthetic(0, _crystal())
	var cost := g.spell_cost_for(0, _games(), 0, 1)
	assert_eq(cost.mana_value(), 2, "{U} plus {2}{U} less {2} = {U}{U}")
	assert_eq(int(cost.colored.get(Mtg.ManaColor.U, 0)), 2)


func test_crystal_never_reduces_below_the_buyback_or_into_the_spell() -> void:
	put_synthetic(0, _crystal())
	var data := _touch("{1}", "{2}{R}")
	assert_eq(g.spell_cost_for(0, data, 0, 1).mana_value(), 3,
		"{2}{R} plus {1}: the buyback goes to 0, the printed {2} stays")
	put_synthetic(1, _crystal())
	assert_eq(g.spell_cost_for(0, data, 0, 1).mana_value(), 3, "a second Crystal finds nothing more")


func test_two_crystals_add_up_and_affect_every_player() -> void:
	put_synthetic(0, _crystal())
	put_synthetic(1, _crystal())
	var touch := give_synthetic(1, _touch())
	assert_eq(g.spell_cost_for(1, touch.data, 0, 1).mana_value(), 1, "{4} less {2} less {2}")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, touch, [TargetRef.player(0)], 0, 1))
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.HAND)


func test_crystal_leaves_a_non_mana_buyback_alone() -> void:
	put_synthetic(0, _crystal())
	var data := _forbid()
	assert_eq(g.spell_cost_for(0, data, 0, 1).mana_value(), 3, "{1}{U}{U}: the discard is not mana")
	assert_eq(g.spell_object_costs(data, 1).size(), 1, "the two discards are still owed")


func test_a_tapped_crystal_stops_under_the_1997_rules_only() -> void:
	var crystal := put_synthetic(0, _crystal())
	var touch := give_synthetic(0, _touch())
	g.tap_permanent(crystal)
	g.recalculate()
	assert_eq(g.spell_cost_for(0, touch.data, 0, 1).mana_value(), 3, "modern: a tapped artifact still works")
	g.rules.set_edition("fifth")
	g.recalculate()
	assert_eq(g.spell_cost_for(0, touch.data, 0, 1).mana_value(), 5,
		"fifth: a tapped artifact's static ability stops (manual p.124)")


func test_the_payment_the_cast_demands_matches_the_query() -> void:
	put_synthetic(0, _crystal())
	var touch := give_synthetic(0, _touch())
	var pay := g.spell_payment(0, touch.data, 0, 1, touch, 1)
	assert_eq((pay["cost"] as ManaCost).mana_value() + int(pay["extra"]), 3)


# ---------------------------------------------------------------- undo --

func _capture() -> Array:
	var snap := GameSnapshot.take(g)
	var out: Array = []
	for i in snap._objects.size():
		var obj: Object = snap._objects[i]
		var props: Array = snap._props[i]
		var values: Array = snap._values[i]
		var k := 0
		for group in [props[0], props[1]]:
			for name in group:
				if name != &"undo_log" and name != &"journal":
					out.append([obj, name, _deep(values[k])])
				k += 1
	out.append([g.rng, &"state", g.rng.state])
	snap.restore()
	return out


static func _deep(value: Variant) -> Variant:
	var t := typeof(value)
	if t == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	if t == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if t >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value


func _drift(before: Array) -> Array:
	var bad: Array = []
	for row in before:
		var obj: Object = row[0]
		var name: StringName = row[1]
		if not _same(obj.get(name), row[2]):
			bad.append("%s.%s" % [obj.get_script().get_global_name(), name])
	return bad


static func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	if ta != typeof(b):
		return false
	if ta == TYPE_ARRAY:
		var aa := a as Array
		var bb := b as Array
		if aa.size() != bb.size():
			return false
		for i in aa.size():
			if not _same(aa[i], bb[i]):
				return false
		return true
	if ta == TYPE_DICTIONARY:
		var ad := a as Dictionary
		var bd := b as Dictionary
		if ad.size() != bd.size():
			return false
		for k in ad:
			if not bd.has(k) or not _same(ad[k], bd[k]):
				return false
		return true
	return a == b


func _round_trips(move: Callable, what: String) -> void:
	var before := _capture()
	var mark := g.make_mark()
	move.call()
	var mark_size := g.undo_log.size()
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "%s left state behind" % what)
	assert_gt(mark_size, mark, "%s recorded nothing — is the move happening?" % what)
	g.end_search()


func _resolve_all() -> void:
	while not g.stack.is_empty():
		g._resolve_top()
	g.check_state_based_actions()


func test_a_buyback_cast_and_return_round_trips_field_exact() -> void:
	put_synthetic(0, _crystal())
	var forest := put_battlefield(0, "Forest")
	var touch := give_synthetic(0, _touch())
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.R, 3)
		assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
		_resolve_all()
		assert_eq(touch.zone, Mtg.Zone.HAND), "a buyback cast that returns")
	var mists := give_synthetic(0, _mists())
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.G)
		assert_ok(g.cast_spell(0, mists, [], 0, 1))
		_resolve_all()
		assert_eq(forest.zone, Mtg.Zone.GRAVEYARD), "a sacrifice-a-land buyback")
	assert_eq(touch.zone, Mtg.Zone.HAND)
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "unmade")
