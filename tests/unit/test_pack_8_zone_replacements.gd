extends GameTest
## Pack 8 engine package E7 — ZONE AND STACK REPLACEMENTS of the Mirage
## block, each pinned on a SYNTHETIC card built here:
##   * N_dies_to_library      — "If this creature would die, put it on top
##     of its owner's library instead" (Gravebane Zombie; CR 614.1);
##   * N_gy_exile_repl        — "If a card would be put into your graveyard
##     from anywhere, exile that card instead" (Forbidden Crypt);
##   * N_cast_from_gy         — "Until end of turn, you may cast instant and
##     sorcery spells from the top of your graveyard. If a spell cast this
##     way would be put into a graveyard, exile it instead" (Bösium Strip);
##   * N_on_milled            — "When this card is put into your graveyard
##     from your library" (Gaea's Blessing);
##   * N_counter_dest         — countered spell exiled (Dissipate) or put
##     onto the battlefield under the counterer's control (Desertion);
##   * N_facedown_exile_play  — play a face-down exiled card its owner may
##     look at (Three Wishes);
##   * N_hand_special_action  — "You may discard this card any time you
##     could cast an instant" (Circling Vultures; CR 116.2);
##   * N_becomes_aura         — a non-Aura enchantment becomes an Aura
##     attached to the creature it put onto the battlefield (Necromancy).


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


func _gravebane() -> CardData:
	return CardData.new("Synthetic Gravebane", "{3}{B}", Mtg.CardType.CREATURE).pt(3, 2) \
		.with_dies_to_library_top() \
		.oracle("If this creature would die, put it on top of its owner's library instead.")


func _crypt() -> CardData:
	return CardData.new("Synthetic Crypt", "{3}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(func(game: MtgGame, s: CardInstance) -> void:
			game.players[s.controller_id].graveyard_becomes_exile = true,
			"If a card would be put into your graveyard from anywhere, exile that card instead.")) \
		.oracle("If a card would be put into your graveyard from anywhere, exile that card instead.")


static func _instant_or_sorcery(c: CardInstance) -> bool:
	return c.data.is_type(Mtg.CardType.INSTANT) or c.data.is_type(Mtg.CardType.SORCERY)


# -------------------------------------------------------- N_dies_to_library --

func test_a_dying_gravebane_goes_on_top_of_its_library_and_never_dies() -> void:
	var zombie := put_synthetic(0, _gravebane())
	var deaths := g.creatures_died_this_turn
	g.destroy(zombie)
	assert_eq(zombie.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), zombie, "on TOP")
	assert_eq(g.creatures_died_this_turn, deaths, "replaced: it never died")
	assert_false(g.players[0].graveyard.has(zombie))


func test_sacrifice_and_lethal_damage_are_dying_too_but_exile_is_not() -> void:
	var a := put_synthetic(0, _gravebane())
	g.sacrifice_permanent(a)
	assert_eq(a.zone, Mtg.Zone.LIBRARY)
	var b := put_synthetic(0, _gravebane())
	var bolt := give_hand(1, "Lightning Bolt")
	g.priority_player = 1
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(b)]))
	resolve_stack()
	assert_eq(b.zone, Mtg.Zone.LIBRARY)
	var c := put_synthetic(0, _gravebane())
	g.exile_permanent(c)
	assert_eq(c.zone, Mtg.Zone.EXILE)


func test_a_stolen_gravebane_goes_to_its_owners_library() -> void:
	var zombie := put_synthetic(1, _gravebane())
	g.change_control(zombie, 0)
	g.destroy(zombie)
	assert_eq(zombie.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].library.back(), zombie)


# ---------------------------------------------------------- N_gy_exile_repl --

func test_forbidden_crypt_exiles_whatever_would_reach_its_controllers_graveyard() -> void:
	var crypt := put_synthetic(0, _crypt())
	assert_true(g.players[0].graveyard_becomes_exile)
	assert_false(g.players[1].graveyard_becomes_exile)
	var bear := put_battlefield(0, "Grizzly Bears")
	var deaths := g.creatures_died_this_turn
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.EXILE, "a creature so exiled")
	assert_eq(g.creatures_died_this_turn, deaths, "... does not die")
	var thrown := give_hand(0, "Lightning Bolt")
	g.discard_cards(0, [thrown])
	assert_eq(thrown.zone, Mtg.Zone.EXILE)
	var top: CardInstance = g.players[0].library.back()
	g.mill(0, 1)
	assert_eq(top.zone, Mtg.Zone.EXILE)
	var whole := give_hand(0, "Forest")
	g.discard_hand(0)
	assert_eq(whole.zone, Mtg.Zone.EXILE)
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.destroy(theirs)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "only YOUR graveyard")
	assert_eq(crypt.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.players[0].graveyard.is_empty())


func test_forbidden_crypt_exiles_resolved_and_countered_spells_and_itself() -> void:
	var crypt := put_synthetic(0, _crypt())
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	var second := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, second, [TargetRef.player(1)]))
	g.counter_spell(second)
	assert_eq(second.zone, Mtg.Zone.EXILE)
	g.destroy(crypt)
	assert_eq(crypt.zone, Mtg.Zone.EXILE, "the replacement still applies as it leaves")
	g.recalculate()
	assert_false(g.players[0].graveyard_becomes_exile)
	var later := put_battlefield(0, "Grizzly Bears")
	g.destroy(later)
	assert_eq(later.zone, Mtg.Zone.GRAVEYARD)


func test_crypt_and_a_dies_replacement_keep_the_card() -> void:
	put_synthetic(0, _crypt())
	var zombie := put_synthetic(0, _gravebane())
	g.destroy(zombie)
	assert_eq(zombie.zone, Mtg.Zone.LIBRARY)


# --------------------------------------------------------- N_cast_from_gy --

func _strip_permission(pid: int) -> void:
	g.grant_graveyard_cast(pid, _instant_or_sorcery, "instant and sorcery spells", true, true)


func test_the_top_instant_of_your_graveyard_may_be_cast_and_is_exiled_after() -> void:
	var under := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	var top := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_refused(g.cast_spell(0, top, [TargetRef.player(1)]))
	_strip_permission(0)
	assert_true(g.can_cast_from_graveyard(0, top))
	assert_false(g.can_cast_from_graveyard(0, under), "only the TOP card")
	assert_false(g.can_cast_from_graveyard(1, top), "only its holder")
	assert_true(g.playable_cards(0).has(top))
	assert_refused(g.cast_spell(0, under, [TargetRef.player(1)]))
	assert_ok(g.cast_spell(0, top, [TargetRef.player(1)]))
	assert_eq(top.zone, Mtg.Zone.STACK)
	assert_true(g.can_cast_from_graveyard(0, under), "now it is the top card")
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(top.zone, Mtg.Zone.EXILE, "would be put into a graveyard: exiled instead")


func test_a_spell_cast_from_the_graveyard_is_exiled_when_countered() -> void:
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	_strip_permission(0)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	g.counter_spell(bolt)
	assert_eq(bolt.zone, Mtg.Zone.EXILE)


func test_the_permission_keeps_timing_filters_and_ends_with_the_turn() -> void:
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	_strip_permission(0)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, bear), "")
	var sorcery := _named_in(0, "Stone Rain", Mtg.Zone.GRAVEYARD)
	var land := put_battlefield(1, "Forest")
	assert_true(g.can_cast_from_graveyard(0, sorcery))
	advance_to_next_turn()
	assert_false(g.can_cast_from_graveyard(0, sorcery), "until end of turn")
	assert_true(g.players[0].graveyard_cast_permissions.is_empty())
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)


func test_a_cast_from_graveyard_round_trips() -> void:
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	var mark := g.make_mark()
	_strip_permission(0)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard.has(bolt))
	assert_true(g.players[0].graveyard_cast_permissions.is_empty())
	assert_false(bolt.graveyard_exile_spell)


# ------------------------------------------------------------ N_on_milled --

func _blessing() -> CardData:
	var trig := TriggeredAbility.new(Mtg.EventType.PUT_INTO_GRAVEYARD_FROM_LIBRARY,
		func(game: MtgGame, s: CardInstance, _e: GameEvent) -> void:
			game.shuffle_graveyard_into_library(s.owner_id),
		"When this card is put into your graveyard from your library, shuffle your graveyard into your library.",
		func(_game: MtgGame, s: CardInstance, e: GameEvent) -> bool:
			return e.data.instance == s)
	return CardData.new("Synthetic Blessing", "{1}{G}", Mtg.CardType.SORCERY) \
		.with_graveyard_trigger(trig).oracle("...")


func test_a_milled_card_hears_its_own_trip_from_the_library() -> void:
	var dead := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	var blessing := _card_in(0, _blessing(), Mtg.Zone.LIBRARY)
	g.mill(0, 1)
	assert_eq(blessing.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.stack.size(), 1, "its trigger waits on the stack")
	resolve_stack()
	assert_eq(blessing.zone, Mtg.Zone.LIBRARY)
	assert_eq(dead.zone, Mtg.Zone.LIBRARY)
	assert_true(g.players[0].graveyard.is_empty())


func test_a_discarded_blessing_triggers_nothing() -> void:
	var blessing := _card_in(0, _blessing(), Mtg.Zone.HAND)
	g.discard_cards(0, [blessing])
	assert_eq(blessing.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.stack.is_empty())


func test_every_library_to_graveyard_path_fires_the_event() -> void:
	var heard: Array = []
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.PUT_INTO_GRAVEYARD_FROM_LIBRARY:
			heard.append(e.data.instance))
	var top: CardInstance = g.players[0].library.back()
	g.put_library_card_into_graveyard(top)
	assert_eq(top.zone, Mtg.Zone.GRAVEYARD)
	var next: CardInstance = g.players[0].library.back()
	g.card_to_graveyard_from_anywhere(next)
	assert_eq(heard, [top, next])


# --------------------------------------------------------- N_counter_dest --

func test_a_spell_countered_this_way_is_exiled() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var dissipate := CardData.new("Synthetic Dissipate", "{1}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(CounterEffect.new().to_exile()).oracle("...")
	var counter := _card_in(1, dissipate, Mtg.Zone.HAND)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[1].life, 20)


func _desertion() -> CardData:
	return CardData.new("Synthetic Desertion", "{3}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(CounterEffect.new().to_battlefield_for_caster()).oracle("...")


func test_a_creature_spell_countered_by_desertion_joins_the_counterer() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	var counter := _card_in(1, _desertion(), Mtg.Zone.HAND)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U, 5)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 1)
	assert_eq(bear.owner_id, 0)
	assert_true(g.players[1].battlefield.has(bear))
	assert_eq(counter.zone, Mtg.Zone.GRAVEYARD)


func test_desertion_sends_other_spells_to_the_graveyard() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var counter := _card_in(1, _desertion(), Mtg.Zone.HAND)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U, 5)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)


func test_desertion_round_trips() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	var mark := g.make_mark()
	g.counter_spell(bear, Mtg.Zone.BATTLEFIELD, 1)
	assert_eq(bear.controller_id, 1)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.zone, Mtg.Zone.STACK)
	assert_eq(g.stack.size(), 1)
	assert_false(g.players[1].battlefield.has(bear))


# ---------------------------------------------------- N_facedown_exile_play --

func test_the_owner_may_play_a_face_down_card_they_may_look_at() -> void:
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.LIBRARY)
	var exiled := g.exile_top_of_library(0, true, 0)
	assert_eq(exiled, bolt)
	assert_true(bolt.face_down)
	assert_eq(bolt.exile_visible_to, 0)
	g.grant_exile_play(bolt, 0, true)
	assert_true(g.can_play_from_exile(0, bolt))
	assert_false(g.can_play_from_exile(1, bolt))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_false(bolt.face_down, "a spell on the stack is face up")
	resolve_stack()
	assert_eq(g.players[1].life, 17)


func test_a_face_down_land_is_played_face_up_and_a_hidden_card_cannot_be_granted() -> void:
	var forest := _named_in(0, "Forest", Mtg.Zone.LIBRARY)
	g.exile_top_of_library(0, true, 0)
	g.grant_exile_play(forest, 0, true)
	assert_ok(g.play_land(0, forest))
	assert_false(forest.face_down)
	assert_true(forest.is_land())
	var secret := _named_in(0, "Lightning Bolt", Mtg.Zone.LIBRARY)
	g.exile_top_of_library(0, true)   # nobody may look at it
	g.grant_exile_play(secret, 0, true)
	assert_false(g.can_play_from_exile(0, secret))


# ---------------------------------------------------- N_hand_special_action --

func _vultures() -> CardData:
	return CardData.new("Synthetic Vultures", "{B}", Mtg.CardType.CREATURE).pt(3, 2) \
		.with_discard_special_action().oracle("You may discard this card any time you could cast an instant.")


func test_discarding_as_a_special_action_uses_no_stack_and_keeps_priority() -> void:
	var vultures := _card_in(0, _vultures(), Mtg.Zone.HAND)
	var heard: Array = []
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.CARD_DISCARDED: heard.append(e.data.by_effect))
	g.players[0].discard_to_library_top = true   # a Library of Leng: not an effect
	assert_ok(g.discard_as_special_action(0, vultures))
	assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.stack.is_empty())
	assert_eq(g.priority_player, 0)
	assert_eq(heard, [false])


func test_the_special_action_needs_priority_the_card_and_its_permission() -> void:
	var vultures := _card_in(0, _vultures(), Mtg.Zone.HAND)
	var bear := give_hand(0, "Grizzly Bears")
	assert_refused(g.discard_as_special_action(0, bear), "")
	assert_refused(g.discard_as_special_action(1, vultures), "")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_ok(g.pass_priority(0))
	assert_refused(g.discard_as_special_action(0, vultures), "priority")
	assert_eq(vultures.zone, Mtg.Zone.HAND)
	resolve_stack()
	# The opponent's turn: any time it could cast an instant.
	advance_to_next_turn()
	assert_ne(g.active_player, 0)
	g.priority_player = 0
	assert_ok(g.discard_as_special_action(0, vultures))


# ----------------------------------------------------------- N_becomes_aura --

func _necro() -> CardData:
	return CardData.new("Synthetic Necromancy", "{2}{B}", Mtg.CardType.ENCHANTMENT).oracle("...")


func test_an_enchantment_becomes_an_aura_on_the_creature_it_raised() -> void:
	var necro := put_synthetic(0, _necro())
	var bear := _named_in(1, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	assert_false(necro.is_aura())
	g.reanimate_as_aura(necro, bear)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 0)
	assert_true(necro.is_aura())
	assert_true(necro.has_subtype("aura"))
	assert_eq(necro.attached_to, bear.id)
	assert_true(bear.attachments.has(necro.id))
	assert_eq(necro.printed_data.card_name, "Synthetic Necromancy")
	g.check_state_based_actions()
	assert_eq(necro.zone, Mtg.Zone.BATTLEFIELD, "a legal Aura: it stays")


func test_when_the_aura_leaves_the_creature_is_sacrificed() -> void:
	var necro := put_synthetic(0, _necro())
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	g.reanimate_as_aura(necro, bear)
	g.destroy(necro)
	assert_eq(necro.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_false(necro.is_aura(), "a card in a graveyard is its printed self again")


func test_when_the_creature_leaves_the_aura_goes_to_the_graveyard() -> void:
	var necro := put_synthetic(0, _necro())
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	g.reanimate_as_aura(necro, bear)
	g.return_to_hand(bear)
	g.check_state_based_actions()
	assert_eq(necro.zone, Mtg.Zone.GRAVEYARD)


func test_the_aura_answers_to_aura_hate_and_returns_printed_when_bounced() -> void:
	var necro := put_synthetic(0, _necro())
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	g.reanimate_as_aura(necro, bear)
	var aura_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Aura",
		func(c: CardInstance) -> bool: return c.is_aura())
	assert_true(aura_spec.is_legal(g, TargetRef.card(necro), bear))
	g.return_to_hand(necro)
	assert_eq(necro.zone, Mtg.Zone.HAND)
	assert_eq(necro.data, necro.printed_data)
	assert_false(necro.data.is_aura())
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "its leaving sacrificed the creature")


func test_becoming_an_aura_round_trips() -> void:
	var necro := put_synthetic(0, _necro())
	var bear := _named_in(1, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	var mark := g.make_mark()
	g.reanimate_as_aura(necro, bear)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_false(necro.is_aura())
	assert_eq(necro.attached_to, -1)
	assert_eq(necro.data, necro.printed_data)


# ------------------------------------------------- the journal, field-exact --
# The same differ tests/ai/test_undo_log.gd uses: every mutable field
# GameSnapshot knows, captured, the move made with the journal on, unmade,
# and compared — a field a new path writes without journaling shows up by
# name.

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


func test_every_zone_replacement_round_trips_field_exact() -> void:
	put_synthetic(0, _crypt())
	var bear := put_battlefield(0, "Grizzly Bears")
	_round_trips(func() -> void: g.destroy(bear), "Crypt: a destroyed creature")
	var thrown := give_hand(0, "Lightning Bolt")
	_round_trips(func() -> void: g.discard_cards(0, [thrown]), "Crypt: a discard")
	_round_trips(func() -> void: g.mill(0, 2), "Crypt: a mill")
	var bolt := give_hand(0, "Lightning Bolt")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
		_resolve_all(), "Crypt: a resolved spell")
	var zombie := put_synthetic(1, _gravebane())
	_round_trips(func() -> void: g.destroy(zombie), "dies to library")
	var dissipate := CardData.new("Synthetic Dissipate", "{1}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(CounterEffect.new().to_exile()).oracle("...")
	var target := give_hand(0, "Lightning Bolt")
	var counter := _card_in(1, dissipate, Mtg.Zone.HAND)
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, target, [TargetRef.player(1)]))
		assert_ok(g.pass_priority(0))
		add_mana(1, Mtg.ManaColor.U, 3)
		assert_ok(g.cast_spell(1, counter, [TargetRef.card(target)]))
		_resolve_all(), "counter to exile")


func test_the_rest_of_the_package_round_trips_field_exact() -> void:
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.LIBRARY)
	_round_trips(func() -> void:
		g.exile_top_of_library(0, true, 0)
		g.grant_exile_play(bolt, 0, true)
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
		_resolve_all(), "face-down exile play")
	var vultures := _card_in(0, _vultures(), Mtg.Zone.HAND)
	_round_trips(func() -> void:
		assert_ok(g.discard_as_special_action(0, vultures)), "special-action discard")
	var top := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	_round_trips(func() -> void:
		_strip_permission(0)
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, top, [TargetRef.player(1)]))
		_resolve_all(), "graveyard cast")
	_card_in(0, _blessing(), Mtg.Zone.LIBRARY)
	_round_trips(func() -> void:
		g.mill(0, 1)
		_resolve_all(), "milled trigger")
	var necro := put_synthetic(0, _necro())
	var dead := _named_in(1, "Grizzly Bears", Mtg.Zone.GRAVEYARD)
	_round_trips(func() -> void:
		g.reanimate_as_aura(necro, dead)
		g.destroy(necro), "becomes an Aura and leaves")
	var bear := give_hand(0, "Grizzly Bears")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.G, 2)
		assert_ok(g.cast_spell(0, bear))
		g.counter_spell(bear, Mtg.Zone.BATTLEFIELD, 1), "Desertion")


# ----------------------------------- simultaneity, triggers, rules profiles --

func test_a_crypt_exiled_creature_fires_no_dies_trigger() -> void:
	var deaths: Array = []
	var watcher := CardData.new("Synthetic Watcher", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(Mtg.EventType.DIES,
			func(_game: MtgGame, _s: CardInstance, e: GameEvent) -> void: deaths.append(e.data.instance),
			"Whenever a creature dies, ...")).oracle("...")
	put_synthetic(1, watcher)
	put_synthetic(0, _crypt())
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear)
	resolve_stack()
	assert_eq(deaths, [], "exiled instead: it never died")
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.destroy(theirs)
	resolve_stack()
	assert_eq(deaths, [theirs])


func test_milling_three_shuffles_back_every_card_the_mill_moved() -> void:
	_card_in(0, CardRegistry.get_card("Forest"), Mtg.Zone.LIBRARY)
	var blessing := _card_in(0, _blessing(), Mtg.Zone.LIBRARY)
	_card_in(0, CardRegistry.get_card("Forest"), Mtg.Zone.LIBRARY)
	g.mill(0, 3)
	assert_eq(g.players[0].graveyard.size(), 3, "the three leave together")
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_true(g.players[0].graveyard.is_empty())
	assert_eq(blessing.zone, Mtg.Zone.LIBRARY)


func test_a_crypt_keeps_a_blessing_from_ever_reaching_the_graveyard() -> void:
	put_synthetic(0, _crypt())
	var blessing := _card_in(0, _blessing(), Mtg.Zone.LIBRARY)
	g.mill(0, 1)
	assert_eq(blessing.zone, Mtg.Zone.EXILE)
	assert_true(g.stack.is_empty(), "never put into the graveyard: no trigger")


class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func test_the_special_action_discard_under_both_rules_profiles() -> void:
	# Fifth Edition's damage-prevention window admits prevention only
	# (`Duel.hlp`); the modern profile has no window at all.
	for preset in ["fifth", "modern"]:
		before_each()
		g.rules.set_preset(preset)
		g.rules.damage_prevention_window = preset == "fifth"
		g.set_agent(1, Duelist.new())
		give_hand(1, "Healing Salve")   # something to do in the window
		var vultures := _card_in(1, _vultures(), Mtg.Zone.HAND)
		var bolt := give_hand(0, "Lightning Bolt")
		add_mana(0, Mtg.ManaColor.R)
		assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
		resolve_stack()
		if preset == "fifth":
			assert_true(g.awaiting_damage_prevention, "the window is open")
			if g.priority_player != 1:
				assert_ok(g.end_damage_prevention(g.priority_player))   # to the defender
			assert_eq(g.priority_player, 1)
			assert_refused(g.discard_as_special_action(1, vultures), "damage prevention")
			assert_eq(vultures.zone, Mtg.Zone.HAND)
		else:
			assert_false(g.awaiting_damage_prevention)
			g.priority_player = 1
			assert_ok(g.discard_as_special_action(1, vultures))
			assert_eq(vultures.zone, Mtg.Zone.GRAVEYARD)


func test_a_deserted_creature_enters_sick_and_fires_its_entry() -> void:
	var entered: Array = []
	var greeter := CardData.new("Synthetic Greeter", "{G}", Mtg.CardType.CREATURE).pt(1, 1) \
		.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
			func(_game: MtgGame, s: CardInstance, _e: GameEvent) -> void: entered.append(s.controller_id),
			"When this creature enters, ...",
			func(_game: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.instance == s)) \
		.oracle("...")
	var spell := _card_in(0, greeter, Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, spell))
	var counter := _card_in(1, _desertion(), Mtg.Zone.HAND)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.U, 5)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(spell)]))
	resolve_stack()
	assert_eq(spell.controller_id, 1)
	assert_true(spell.summoning_sick)
	assert_eq(entered, [1], "it entered, under the counterer")
