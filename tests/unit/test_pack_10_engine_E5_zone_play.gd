extends GameTest
## Pack 10 engine package E5 — PLAY FROM ANOTHER ZONE (CR 601.3, 305.1,
## 305.2, 118.9, 107.3b, 401.5): [method MtgGame.grant_zone_play].
##
## Yawgmoth's Will: "Until end of turn, you may play lands and cast spells
## from your graveyard." — a GRAVEYARD permission with `lands`: a land is
## PLAYED from there and spends the land drop (CR 305.2), a spell is cast
## from any position with its printed timing and costs.
##
## Temporal Aperture: "Until end of turn, for as long as that card remains
## on top of your library, ... you may play that card without paying its
## mana cost. (If it has X in its mana cost, X is 0.)" — a LIBRARY
## permission naming the revealed card, `free`: it adds one "Without
## paying its mana cost" payment row ({0}, an alternative cost — CR 118.9,
## X = 0 by CR 107.3b) and the printed rows are refused from there; a land
## plays as the land drop. The named card must be the top card: a draw or
## anything that buries it ends the permission.
##
## Both end at cleanup. The cards are SYNTHETIC or core-set stand-ins; the
## real Will and Aperture are batch B13's.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ----------------------------------------------------------------- helpers --

func _card_in(pid: int, data: CardData, zone: int) -> CardInstance:
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.HAND: g.players[pid].hand.append(inst)
		Mtg.Zone.GRAVEYARD: g.players[pid].graveyard.append(inst)
		Mtg.Zone.LIBRARY: g.players[pid].library.append(inst)
	return inst


func _named_in(pid: int, card_name: String, zone: int) -> CardInstance:
	return _card_in(pid, CardRegistry.get_card(card_name), zone)


## Yawgmoth's Will's first sentence.
func _will(pid: int, exile_instead := false) -> void:
	g.grant_zone_play(pid, {"zone": Mtg.Zone.GRAVEYARD, "lands": true, "spells": true,
		"top_only": false, "exile_instead": exile_instead,
		"desc": "lands and spells from their graveyard"})


## Temporal Aperture's permission on [param card], the top of the library.
func _aperture(pid: int, card: CardInstance, source: CardInstance = null,
		hold := Callable()) -> void:
	var spec := {"zone": Mtg.Zone.LIBRARY, "card": card, "lands": true, "spells": true,
		"free": true, "desc": "the top card of their library", "source": source}
	if hold.is_valid():
		spec["while"] = hold
	g.grant_zone_play(pid, spec)


static func _artifact_stand_in() -> CardData:
	return CardData.new("Test Aperture", "{2}", Mtg.CardType.ARTIFACT)


static func _touch() -> CardData:
	return CardData.new("Test Touch", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(1).any_target()) \
		.with_buyback({"mana": "{4}"})


static func _free_row(rows: Array) -> int:
	for i in rows.size():
		if bool(Dictionary(rows[i].get("payment", {})).get("zone_free", false)):
			return i
	return -1


# ------------------------------------------------- the graveyard (the Will) --

func test_a_graveyard_land_is_played_as_the_land_drop() -> void:
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	assert_refused(g.play_land(0, forest), "not in your hand")
	_will(0)
	assert_true(g.can_play_from_zone(0, forest))
	assert_false(g.can_cast_from_graveyard(0, forest), "a land is played, never cast")
	assert_ok(g.play_land(0, forest))
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.players[0].graveyard.has(forest))
	assert_eq(g.players[0].lands_played_this_turn, 1, "CR 305.2: the land drop")


func test_no_land_drop_left_refuses_the_graveyard_land() -> void:
	_will(0)
	assert_ok(g.play_land(0, _named_in(0, "Forest", Mtg.Zone.HAND)))
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	assert_refused(g.play_land(0, forest), "already played a land")
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)


func test_a_graveyard_land_keeps_the_land_timing() -> void:
	_will(0)
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	assert_refused(g.play_land(0, forest), "empty stack")
	resolve_stack()
	advance_to_next_turn()   # P1's turn: the permission is gone anyway
	assert_false(g.can_play_from_zone(0, forest), "until end of turn")


func test_lands_need_the_lands_half() -> void:
	g.grant_graveyard_cast(0, Callable(), "spells", false, false)   # Bösium-like, no lands
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	assert_false(g.can_play_from_zone(0, forest))
	assert_refused(g.play_land(0, forest), "not in your hand")
	assert_false(g.playable_cards(0).has(forest))


func test_only_your_own_graveyard() -> void:
	_will(0)
	var theirs := _named_in(1, "Forest", Mtg.Zone.GRAVEYARD)
	var bolt := _named_in(1, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	assert_false(g.can_play_from_zone(0, theirs))
	assert_refused(g.play_land(0, theirs))
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]))


func test_playable_cards_lists_the_graveyard_under_the_permission_only() -> void:
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	assert_false(g.playable_cards(0).has(forest))
	assert_false(g.playable_cards(0).has(bolt))
	_will(0)
	assert_true(g.playable_cards(0).has(forest))
	assert_true(g.playable_cards(0).has(bolt))
	assert_false(g.playable_cards(1).has(bolt))


func test_a_spell_anywhere_in_the_graveyard_is_cast_with_its_printed_cost() -> void:
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	_named_in(0, "Forest", Mtg.Zone.GRAVEYARD)   # on top of it
	_will(0)
	assert_true(g.can_cast_from_graveyard(0, bolt), "not only the top card")
	assert_eq(g.payment_rows(0, bolt).size(), 1, "no free row: the printed cost")
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]), "not enough mana")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_false(g.players[0].graveyard.has(bolt))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "no exile rider on this permission")


func test_the_exile_rider_exiles_the_spell() -> void:
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	_will(0, true)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)


func test_a_buyback_spell_from_the_graveyard_returns_to_the_hand() -> void:
	var touch := _card_in(0, _touch(), Mtg.Zone.GRAVEYARD)
	_will(0, true)
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 1))
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.HAND, "CR 702.27a: never a graveyard to replace")


func test_a_creature_from_the_graveyard_keeps_sorcery_timing() -> void:
	_will(0)
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, bear), "main phase")


func test_casting_a_land_is_refused_in_words() -> void:
	_will(0)
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	assert_refused(g.cast_spell(0, forest), "lands are played, not cast")


func test_the_permission_ends_at_cleanup() -> void:
	_will(0)
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	assert_true(g.can_play_from_zone(0, forest))
	advance_to_next_turn()
	assert_false(g.can_play_from_zone(0, forest))
	assert_true(g.players[0].graveyard_cast_permissions.is_empty())


func test_a_graveyard_land_play_round_trips() -> void:
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	var mark := g.make_mark()
	_will(0)
	assert_ok(g.play_land(0, forest))
	g.unmake_to(mark)
	g.end_search()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard.has(forest))
	assert_false(g.players[0].battlefield.has(forest))
	assert_eq(g.players[0].lands_played_this_turn, 0)
	assert_true(g.players[0].graveyard_cast_permissions.is_empty())


# ------------------------------------------- the library top (the Aperture) --

func test_the_top_card_is_cast_without_paying_its_mana_cost() -> void:
	var aperture := put_synthetic(0, _artifact_stand_in())
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	assert_false(g.can_play_from_zone(0, bear), "no permission yet")
	_aperture(0, bear, aperture)
	assert_true(g.can_play_from_zone(0, bear))
	assert_true(g.playable_cards(0).has(bear))
	var rows := g.payment_rows(0, bear)
	var free := _free_row(rows)
	assert_eq(rows.size(), 2, "the printed row and the free one")
	assert_eq(free, 1, "after the printed rows: no index moves")
	assert_string_contains(String(rows[free]["label"]), "Without paying its mana cost")
	assert_string_contains(String(rows[free]["label"]), "Test Aperture")
	assert_ok(g.cast_spell(0, bear, [], 0, free))
	assert_eq(bear.zone, Mtg.Zone.STACK)
	assert_false(g.players[0].library.has(bear))
	assert_string_contains(g.stack.back().description, "Test Aperture")
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_the_printed_cost_is_refused_from_the_library() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_aperture(0, bear)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, bear, [], 0, 0), "without paying its mana cost")
	assert_eq(bear.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].mana_pool.total(), 2, "nothing was paid")


func test_every_asker_refuses_the_printed_row_of_a_free_only_card() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_aperture(0, bear)
	add_mana(0, Mtg.ManaColor.G, 2)
	var free := _free_row(g.payment_rows(0, bear))
	assert_refused(g.payment_row_refusal(0, bear, 0), "without paying its mana cost")
	assert_refused(g.spell_announce_refusal(0, bear, 0, 0), "without paying its mana cost")
	assert_refused(g.cast_refusal(0, bear, [], 0, 0), "without paying its mana cost")
	assert_eq(g.payment_row_refusal(0, bear, free), "", "the free row stays open")
	assert_eq(g.spell_announce_refusal(0, bear, 0, free), "")
	assert_eq(g.cast_refusal(0, bear, [], 0, free), "")
	var hand_bear := _named_in(0, "Grizzly Bears", Mtg.Zone.HAND)
	assert_eq(g.payment_row_refusal(0, hand_bear, 0), "", "control: the hand's printed row")
	# The network referee's open rows (SGManalink) are the free one only.
	assert_eq(SgDuelActions.open_modes(g, 0, bear), [free])
	assert_eq(SgDuelActions.open_modes(g, 0, hand_bear), [0])


func test_a_graveyard_spell_under_the_will_keeps_its_printed_row() -> void:
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	_will(0)
	add_mana(0, Mtg.ManaColor.R)
	assert_eq(g.payment_row_refusal(0, bolt, 0), "", "not free: the printed cost is the way")


func test_x_is_zero() -> void:
	var disintegrate := _named_in(0, "Disintegrate", Mtg.Zone.LIBRARY)
	_aperture(0, disintegrate)
	var free := _free_row(g.payment_rows(0, disintegrate))
	assert_gt(free, 0)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_refused(g.cast_spell(0, disintegrate, [TargetRef.player(1)], 3, free), "X must be 0")
	assert_ok(g.cast_spell(0, disintegrate, [TargetRef.player(1)], 0, free))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "X = 0 (CR 107.3b)")


func test_a_land_on_top_plays_as_the_land_drop() -> void:
	var forest := _named_in(0, "Forest", Mtg.Zone.LIBRARY)
	_aperture(0, forest)
	assert_true(g.playable_cards(0).has(forest))
	assert_ok(g.play_land(0, forest))
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.players[0].library.has(forest))
	assert_eq(g.players[0].lands_played_this_turn, 1)
	var next := _named_in(0, "Forest", Mtg.Zone.LIBRARY)
	assert_false(g.can_play_from_zone(0, next), "only the card the permission names")


func test_a_draw_ends_the_permission() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_aperture(0, bear)
	g.draw_cards(0, 1)
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_false(g.can_play_from_zone(0, bear))


func test_a_card_put_on_top_of_it_ends_the_permission() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_aperture(0, bear)
	var other := _named_in(0, "Lightning Bolt", Mtg.Zone.LIBRARY)
	assert_false(g.can_play_from_zone(0, bear), "no longer on top")
	assert_false(g.can_play_from_zone(0, other), "not the card it names")
	assert_false(g.playable_cards(0).has(other), "the hidden top stays hidden (fair play)")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, bear, [], 0, 1))


func test_a_shuffle_that_buries_it_ends_the_permission() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_aperture(0, bear)
	var guard := 0
	while g.players[0].library.back() == bear and guard < 10:
		g.shuffle_library(0)
		guard += 1
	assert_ne(g.players[0].library.back(), bear)
	assert_false(g.can_play_from_zone(0, bear))


func test_the_while_condition_is_asked() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	var open := [true]
	_aperture(0, bear, null, func(_g: MtgGame, _i: CardInstance) -> bool: return open[0])
	assert_true(g.can_play_from_zone(0, bear))
	open[0] = false
	assert_false(g.can_play_from_zone(0, bear))


func test_only_its_owner_and_never_the_opponents_library() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_aperture(0, bear)
	assert_false(g.can_play_from_zone(1, bear))
	assert_false(g.playable_cards(1).has(bear))
	assert_eq(_free_row(g.payment_rows(1, bear)), -1)


func test_a_library_permission_must_name_its_card() -> void:
	g.grant_zone_play(0, {"zone": Mtg.Zone.LIBRARY, "lands": true, "spells": true, "free": true})
	var top: CardInstance = g.players[0].library.back()
	assert_false(g.can_play_from_zone(0, top), "a hidden card is never offered")


func test_the_library_permission_ends_at_cleanup() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_aperture(0, bear)
	advance_to_next_turn()   # P1's turn: P0 draws nothing, the Bears stay on top
	assert_eq(g.players[0].library.back(), bear)
	assert_false(g.can_play_from_zone(0, bear), "until end of turn")
	assert_true(g.players[0].graveyard_cast_permissions.is_empty())


func test_a_free_cast_from_the_library_round_trips() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_aperture(0, bear)
	var free := _free_row(g.payment_rows(0, bear))
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, bear, [], 0, free))
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), bear)
	assert_true(g.stack.is_empty())
	assert_true(g.can_play_from_zone(0, bear))


func test_the_free_row_carries_a_buyback() -> void:
	var touch := _card_in(0, _touch(), Mtg.Zone.LIBRARY)
	_aperture(0, touch)
	var rows := g.payment_rows(0, touch)
	var buyback_free := -1
	for i in rows.size():
		var pay: Dictionary = rows[i].get("payment", {})
		if bool(pay.get("zone_free", false)) and bool(pay.get("buyback", false)):
			buyback_free = i
	assert_gt(buyback_free, 0, "a free row with the buyback on top (an additional cost)")
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, buyback_free))
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 19)
