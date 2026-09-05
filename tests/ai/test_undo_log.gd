extends GameTest
## THE SEARCH JOURNAL — [UndoLog] plus [MtgGame.make_mark] /
## [MtgGame.unmake_to], M4 phase 3.
##
## The journal exists so a search can unmake a move in time proportional to
## the MOVE rather than to the board; [GameSnapshot] costs the whole game
## (~3.4 ms) and is a rewind rather than a fork. Everything here is about
## the two promises that makes:
##
## 1. **A make/unmake round trip leaves NOTHING behind.** Pinned against
##    `GameSnapshot` itself, which is the engine's own definition of "all
##    the mutable state there is": take a snapshot, make the move with the
##    journal on, unmake it, and compare every captured field. A field the
##    journal misses shows up here by name.
## 2. **The random stream does not move.** A search that draws from
##    `game.rng` while exploring and leaves the stream advanced would change
##    what the REAL game rolls — every seeded Deck Lab replay rests on it
##    not doing that (CONTRIBUTING.md rule 7).
##
## And the third promise, which is about the thousands of tests that are
## not here: the journal is OFF unless something turns it on, so a normal
## duel pays one null test per instrumented write and nothing else.
##
## THE MOVE MENU at the bottom is promise 1 taken seriously: one round trip
## per KIND of move a search can make — pump, burn that kills and burn
## that does not, burn to the face, a ping, X spells, bounce, exile,
## destroy, an enchantment leaving, a land leaving, mana rituals, a
## counterspell, recursion, draws, a prevention shield that gets used, a
## global damage ability, a token, and a damage trigger going on the
## stack. Each one was a real gap when it was written (2026-09-02: the
## journal covered the SIX helpers a creature cast touches and nothing a
## spell resolution writes — damage, life, departures, `memory`, every
## per-turn table). The differ names the field, so a new gap reads as
## `CardInstance.damage`, not as a mysterious search result.


# ------------------------------------------------------- the state differ --

## Every mutable field of the game, as [GameSnapshot] defines "mutable" —
## `[[object, property, value], ...]`, deep-copied so it survives the moves
## made after it.
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
				# `undo_log` (and ContinuousEffects' `journal`, the same
				# object) is the instrument, not the state.
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


## The fields that differ from [param before] now — named, so a failure
## says WHICH mutation the journal does not cover.
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


## Make [param move] with the journal on, unmake it, and assert the game is
## indistinguishable from what it was.
func _round_trips(move: Callable, what: String) -> void:
	var before := _capture()
	var mark := g.make_mark()
	move.call()
	var mark_size := g.undo_log.size()
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "%s left state behind" % what)
	assert_gt(mark_size, mark, "%s recorded nothing — is the move happening?" % what)


## Cast [param card_name] from [param pid]'s hand at [param targets] and
## resolve everything it put on the stack, the way a search node would:
## straight through `_resolve_top`, no priority passing, then the
## state-based check that a real resolution would be followed by.
func _cast_and_resolve(pid: int, card_name: String, targets: Array, x := 0, mode := 0) -> void:
	var inst := g.find_in_hand(pid, card_name)
	assert_not_null(inst, card_name)
	assert_ok(g.cast_spell(pid, inst, targets, x, mode))
	_resolve_all()


func _resolve_all() -> void:
	while not g.stack.is_empty():
		g._resolve_top()
	g.check_state_based_actions()


# --------------------------------------------------------------- the tests --

func test_the_journal_is_off_until_something_turns_it_on() -> void:
	# The promise the other 3092 tests rest on: a duel that never searches
	# never allocates a log and never records a field.
	assert_null(g.undo_log, "a fresh game must not carry a journal")
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	resolve_stack()
	assert_null(g.undo_log, "playing a duel must not create a journal")


func test_casting_a_creature_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Bad Moon")       # a static, so recalculate has work
	put_battlefield(1, "Savannah Lions")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.G, 2)
		var bear := g.find_in_hand(0, "Grizzly Bears")
		assert_ok(g.cast_spell(0, bear))
		while not g.stack.is_empty():
			g._resolve_top()
		g.check_state_based_actions(), "casting a creature")


func test_playing_a_land_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Forest")
	_round_trips(func() -> void:
		assert_ok(g.play_land(0, g.find_in_hand(0, "Forest"))),
		"playing a land")


func test_tapping_for_mana_round_trips() -> void:
	put_battlefield(0, "Forest")
	_round_trips(func() -> void:
		assert_ok(g.tap_for_mana(0, g.find_on_battlefield(0, "Forest"))),
		"tapping a land")


func test_declaring_attackers_round_trips() -> void:
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Savannah Lions")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var bear := g.find_on_battlefield(0, "Grizzly Bears")
	_round_trips(func() -> void:
		assert_ok(g.declare_attackers(0, [bear.id])),
		"declaring an attacker")


func test_a_line_of_several_moves_round_trips_to_the_root() -> void:
	# What a search actually does: a whole main phase explored from one
	# mark, then thrown away in a single unwind.
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Forest")
	give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var before := _capture()
	var mark := g.make_mark()
	assert_ok(g.play_land(0, g.find_in_hand(0, "Forest")))
	for land in g.players[0].battlefield:
		if land.is_land() and not land.tapped:
			g.tap_for_mana(0, land)
	assert_ok(g.cast_spell(0, g.find_in_hand(0, "Grizzly Bears")))
	while not g.stack.is_empty():
		g._resolve_top()
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "a three-move line left state behind")


func test_nested_marks_unwind_to_the_one_they_were_given() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Forest")
	put_battlefield(0, "Forest")
	var outer := g.make_mark()
	assert_ok(g.play_land(0, g.find_in_hand(0, "Forest")))
	var after_land := _capture()
	var inner := g.make_mark()
	assert_ok(g.tap_for_mana(0, g.players[0].battlefield[0]))
	g.unmake_to(inner)
	assert_eq(_drift(after_land), [],
		"unwinding the inner mark must not disturb the outer move")
	g.unmake_to(outer)
	assert_eq(g.players[0].hand.size(), 1, "the land is back in hand")


# ------------------------------------------------------------- determinism --

func test_exploring_does_not_move_the_real_games_random_stream() -> void:
	# THE bug this guard exists for: a search that flips a coin while
	# exploring, and the real duel then rolls something else. The Deck Lab's
	# whole methodology is that a seed replays line for line.
	var state_before := g.rng.state
	var mark := g.make_mark()
	for _i in 20:
		g.rng.randi()
	g.unmake_to(mark)
	assert_eq(g.rng.state, state_before,
		"the journal must put game.rng back exactly where it found it")


func test_a_searched_game_draws_the_same_cards_as_an_unsearched_one() -> void:
	# The same promise end to end: two identical games, one of which does a
	# make/unmake first, must draw the same cards in the same order.
	var control := MtgGame.new()
	var filler: Array = []
	for _i in 30:
		filler.append("Forest")
	control.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	control.start(0)
	control.draw_cards(0, 5)
	var expected: Array = []
	for c in control.players[0].hand:
		expected.append(c.data.card_name)

	var searched := MtgGame.new()
	searched.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	searched.start(0)
	var mark := searched.make_mark()
	searched.draw_cards(0, 3)      # the "search" draws, and is rewound
	searched.unmake_to(mark)
	searched.draw_cards(0, 5)
	var got: Array = []
	for c in searched.players[0].hand:
		got.append(c.data.card_name)
	assert_eq(got, expected,
		"a game that searched must draw exactly what one that did not draws")


func test_ending_a_search_puts_the_game_back_to_paying_nothing() -> void:
	# The footgun the pair exists for: `unmake_to` empties the journal but
	# leaves it ALLOCATED, so a duel that searched once and never ended the
	# search would go on recording every mutation into a log nobody reads.
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Forest")
	var mark := g.make_mark()
	assert_ok(g.play_land(0, g.find_in_hand(0, "Forest")))
	g.unmake_to(mark)
	assert_not_null(g.undo_log, "the journal survives one node's unwind")
	g.end_search()
	assert_null(g.undo_log, "end_search drops the journal")
	assert_false(g.is_probing(), "end_search stops probing")
	# And the duel really does record nothing from here.
	assert_ok(g.play_land(0, g.find_in_hand(0, "Forest")))
	assert_null(g.undo_log, "a duel after a search records nothing")


func test_the_probe_flag_comes_back_off() -> void:
	# A search node IS a probe — silent log, no signals, no held
	# resolutions — but the flag must not survive the unwind, or the real
	# duel would go quiet.
	assert_false(g.is_probing())
	var mark := g.make_mark()
	assert_true(g.is_probing(), "a search node runs as a probe")
	g.unmake_to(mark)
	assert_false(g.is_probing(), "the probe flag must be rewound")


# ------------------------------------------------------------ the move menu --
# One round trip per kind of move a search makes. See the header.

func test_a_pump_spell_round_trips() -> void:
	# Giant Growth: an until-end-of-turn layer on ContinuousEffects plus
	# the spell going to the graveyard.
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Giant Growth")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.G, 1)
		_cast_and_resolve(0, "Giant Growth", [TargetRef.card(bear)]), "giant growth")


func test_burn_a_creature_survives_round_trips() -> void:
	# Damage that stays on the creature: `damage`, `damaged_by_this_turn`,
	# the packet counter, the source's dealt-this-turn tally.
	advance_to_step(Mtg.Step.MAIN1)
	var angel := put_battlefield(1, "Serra Angel")
	give_hand(0, "Lightning Bolt")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.R, 1)
		_cast_and_resolve(0, "Lightning Bolt", [TargetRef.card(angel)]), "bolt, survives")


func test_burn_a_creature_dies_round_trips() -> void:
	# A departure: the whole CardInstance (`clear_battlefield_state` wipes
	# forty-odd fields), both battlefields, `_battlefield_order`, the
	# died-this-turn list, the graveyard it lands in.
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Lightning Bolt")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.R, 1)
		_cast_and_resolve(0, "Lightning Bolt", [TargetRef.card(bear)]), "bolt, dies")


func test_burn_to_the_face_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Lightning Bolt")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.R, 1)
		_cast_and_resolve(0, "Lightning Bolt", [TargetRef.player(1)]), "bolt to the face")


func test_a_ping_round_trips() -> void:
	# An activated ability: `ability_uses`, the tap, the ability item on
	# and off the stack.
	advance_to_step(Mtg.Step.MAIN1)
	var tim := put_battlefield(0, "Prodigal Sorcerer")
	var bear := put_battlefield(1, "Grizzly Bears")
	_round_trips(func() -> void:
		assert_ok(g.activate_ability(0, tim, 0, [TargetRef.card(bear)]))
		_resolve_all(), "tim ping")


func test_an_x_spell_round_trips() -> void:
	# `memory["x_value"]`, written at cast and forgotten at resolution.
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Fireball")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.R, 3)
		_cast_and_resolve(0, "Fireball", [TargetRef.player(1)], 2), "fireball")


func test_a_drain_round_trips() -> void:
	# Damage AND life gain from one resolution.
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Drain Life")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.B, 4)
		_cast_and_resolve(0, "Drain Life", [TargetRef.player(1)], 2), "drain life")


func test_bounce_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Unsummon")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.U, 1)
		_cast_and_resolve(0, "Unsummon", [TargetRef.card(bear)]), "unsummon")


func test_exile_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Swords to Plowshares")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.W, 1)
		_cast_and_resolve(0, "Swords to Plowshares", [TargetRef.card(bear)]), "swords")


func test_destroy_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Terror")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.B, 2)
		_cast_and_resolve(0, "Terror", [TargetRef.card(bear)]), "terror")


func test_an_enchantment_leaving_round_trips() -> void:
	# A static's layer comes off ContinuousEffects when Bad Moon dies.
	advance_to_step(Mtg.Step.MAIN1)
	var moon := put_battlefield(1, "Bad Moon")
	give_hand(0, "Disenchant")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.W, 2)
		_cast_and_resolve(0, "Disenchant", [TargetRef.card(moon)]), "disenchant")


func test_a_land_leaving_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var land := put_battlefield(1, "Forest")
	give_hand(0, "Stone Rain")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.R, 3)
		_cast_and_resolve(0, "Stone Rain", [TargetRef.card(land)]), "stone rain")


func test_a_ritual_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Dark Ritual")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.B, 1)
		_cast_and_resolve(0, "Dark Ritual", []), "dark ritual")


func test_a_counterspell_round_trips() -> void:
	# `counter_spell`: the countered item comes off the stack and its card
	# goes to the graveyard without ever resolving.
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Grizzly Bears")
	give_hand(1, "Counterspell")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.G, 2)
		add_mana(1, Mtg.ManaColor.U, 2)
		var bears := g.find_in_hand(0, "Grizzly Bears")
		assert_ok(g.cast_spell(0, bears))
		assert_ok(g.pass_priority(0))
		assert_ok(g.cast_spell(1, g.find_in_hand(1, "Counterspell"), [TargetRef.card(bears)]))
		_resolve_all(), "counterspell")


func test_recursion_to_hand_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	g.discard_cards(0, [bear])
	give_hand(0, "Regrowth")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.G, 2)
		_cast_and_resolve(0, "Regrowth", [TargetRef.card(bear)]), "regrowth")


func test_raise_dead_round_trips() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	g.discard_cards(0, [bear])
	give_hand(0, "Raise Dead")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.B, 1)
		_cast_and_resolve(0, "Raise Dead", [TargetRef.card(bear)]), "raise dead")


func test_drawing_cards_round_trips() -> void:
	# `library`, `hand`, `draws_this_step`.
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Ancestral Recall")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.U, 1)
		_cast_and_resolve(0, "Ancestral Recall", [TargetRef.player(0)]), "ancestral")


func test_a_prevention_shield_being_used_round_trips() -> void:
	# Healing Salve mode 1 writes `prevention` on the bear; the bolt then
	# consumes it. Both writes happen inside a resolution.
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Healing Salve")
	give_hand(0, "Lightning Bolt")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.W, 1)
		add_mana(0, Mtg.ManaColor.R, 1)
		_cast_and_resolve(0, "Healing Salve", [TargetRef.card(bear)], 0, 1)
		_cast_and_resolve(0, "Lightning Bolt", [TargetRef.card(bear)]), "salve then bolt")


func test_a_global_damage_ability_round_trips() -> void:
	# Pestilence: every creature and every player damaged in one
	# resolution, one of them dying of it.
	advance_to_step(Mtg.Step.MAIN1)
	var pest := put_battlefield(0, "Pestilence")
	put_battlefield(1, "Savannah Lions")
	put_battlefield(0, "Serra Angel")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.B, 1)
		assert_ok(g.activate_ability(0, pest, 0, []))
		_resolve_all(), "pestilence")


func test_a_damage_trigger_going_on_the_stack_round_trips() -> void:
	# Sengir Vampire's counter comes from a trigger PUSHED by the death:
	# `_next_stack_id`, the trigger item, then `counters` on resolution.
	advance_to_step(Mtg.Step.MAIN1)
	var vamp := put_battlefield(0, "Sengir Vampire")
	var bear := put_battlefield(1, "Grizzly Bears")
	_round_trips(func() -> void:
		g.deal_damage(vamp, TargetRef.card(bear), 2, false)
		_resolve_all()
		_resolve_all(), "sengir kill")


func test_making_a_token_round_trips() -> void:
	# `create_token`: `_next_instance_id`, `_instances`, and a permanent
	# that must not survive the unwind.
	advance_to_step(Mtg.Step.MAIN1)
	var hive := put_battlefield(0, "The Hive")
	_round_trips(func() -> void:
		add_mana(0, Mtg.ManaColor.C, 5)
		assert_ok(g.activate_ability(0, hive, 0, []))
		_resolve_all(), "the hive")
	assert_null(g.find_on_battlefield(0, "Wasp"), "the token is unmade with the move")
