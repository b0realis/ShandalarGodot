extends GutTest
## THE SPELL-CAST ANIMATION — `docs/duel-todo.md` §2.4, s30
## `duel_spell_animation.go`.
##
## The item is filed [1997] and the evidence says [s30] — [SpellFlight]'s
## own header carries the three findings. What IS 1997 is where the card
## goes: the **Spell Chain** window, not s30's magnifier, because the
## original has a chain window and s30 does not.
##
## The pixels cannot be asserted from a headless run, so what is pinned
## here is everything else: the diff that decides what flies, the
## board-skip predicate, the chain filter, and the fact that a headless
## run does no work at all.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


## A bare chain object of the given kind — the flight only ever reads
## `kind` and `card`, so nothing else needs filling in.
func _chain_item(inst: CardInstance, kind: int) -> StackItem:
	var item := StackItem.new()
	item.kind = kind
	item.card = inst
	item.controller = inst.controller_id
	return item


func _instance(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	return inst


# ------------------------------------------------------------- the diff --

func test_a_new_chain_object_has_arrived_and_a_gone_one_has_left() -> void:
	# s30's two loops in `syncSpellAnimations`: start an animation for an
	# item that is on the stack now and was not, resolve one that was and
	# is not.
	var change := SpellFlight.moved([1, 2], [2, 3])
	assert_eq(change["arrived"], [3])
	assert_eq(change["left"], [1])


func test_an_unchanged_chain_moves_nothing() -> void:
	var change := SpellFlight.moved([1, 2], [1, 2])
	assert_eq(change["arrived"], [])
	assert_eq(change["left"], [])


func test_only_spells_fly() -> void:
	# s30: `if item.IsAbility { continue }`. In the original an activation
	# is an Activation Card that was never in anybody's hand, so it has
	# nowhere to fly FROM.
	var g: MtgGame = screen.game
	var bolt := _instance(0, "Lightning Bolt")
	var sorcerer := _instance(0, "Prodigal Sorcerer")
	g.stack.append(_chain_item(bolt, Mtg.StackKind.SPELL))
	assert_eq(SpellFlight.chain_ids(g), [bolt.id], "the spell")
	g.stack.append(_chain_item(sorcerer, Mtg.StackKind.ABILITY))
	assert_eq(SpellFlight.chain_ids(g), [bolt.id],
		"and still only the spell")


# ------------------------------------------------- the board-skip predicate --

func test_a_card_in_the_air_is_not_drawn_on_the_board() -> void:
	# s30's `spellIsAnimating` (`:250-261`), which makes `drawBattlefield`
	# skip the permanent and `drawGraveyard` fall through — so the card is
	# never drawn in two places at once.
	var flight := SpellFlight.new()
	add_child_autofree(flight)
	var bolt := _instance(0, "Lightning Bolt")
	assert_false(flight.is_flying(bolt.id))
	flight._rects[bolt.id] = Rect2(Vector2(10, 10), Vector2(132, 106))
	screen.game.stack.append(_chain_item(bolt, Mtg.StackKind.SPELL))
	flight.note(screen.game)
	assert_true(flight.is_flying(bolt.id), "queued counts as in the air")


func test_the_screen_hides_a_flying_card() -> void:
	var bolt := _instance(0, "Lightning Bolt")
	bolt.zone = Mtg.Zone.BATTLEFIELD
	screen._flight._rects[bolt.id] = Rect2(Vector2(10, 10), Vector2(132, 106))
	screen.game.stack.append(_chain_item(bolt, Mtg.StackKind.SPELL))
	screen._flight.note(screen.game)
	var card := screen._make_card(bolt)
	add_child_autofree(card)
	assert_eq(card.modulate.a, 0.0, "the ghost is carrying it")


func test_a_card_that_was_never_drawn_does_not_fly() -> void:
	# No remembered rect means no source — a cast out of an opening hand
	# that nothing has painted yet, or a token.
	var bolt := _instance(0, "Lightning Bolt")
	screen.game.stack.append(_chain_item(bolt, Mtg.StackKind.SPELL))
	screen._flight.note(screen.game)
	assert_false(screen._flight.is_flying(bolt.id))


# ---------------------------------------------------- the headless invariant --

func test_a_headless_run_samples_nothing() -> void:
	# The per-frame scan is the layer's only cost, and it is off without a
	# display — the same gate `_run_coin_toss` uses. With no samples,
	# `note()` can never queue a flight, so a headless duel is exactly the
	# duel it was before this item.
	assert_eq(DisplayServer.get_name(), "headless", "the suite runs headless")
	assert_false(screen._flight.is_processing(), "no per-frame scan")


func test_the_flight_layer_is_above_the_board() -> void:
	# A card in the air crosses the hand window (z 60) it just left.
	assert_gt(screen._flight.z_index, screen._arrows.z_index)


func test_a_second_note_does_not_queue_the_same_card_twice() -> void:
	var bolt := _instance(0, "Lightning Bolt")
	screen._flight._rects[bolt.id] = Rect2(Vector2(10, 10), Vector2(132, 106))
	screen.game.stack.append(_chain_item(bolt, Mtg.StackKind.SPELL))
	screen._flight.note(screen.game)
	screen._flight.note(screen.game)
	assert_eq(screen._flight._pending.size(), 1)


func test_a_spell_that_left_the_chain_still_knows_its_own_card() -> void:
	# A Lightning Bolt on its way to the graveyard has no widget at either
	# end, so the layer has to have KEPT the instance — this is what the
	# graveyard fallback needs to know whose pile to aim at.
	var bolt := _instance(0, "Lightning Bolt")
	screen._flight._rects[bolt.id] = Rect2(Vector2(10, 10), Vector2(132, 106))
	screen.game.stack.append(_chain_item(bolt, Mtg.StackKind.SPELL))
	screen._flight.note(screen.game)
	screen._flight._pending.clear()
	screen.game.stack.clear()
	screen._flight.note(screen.game)
	assert_eq(screen._flight._pending.size(), 1, "the exit flight is queued")
	assert_eq(screen._flight._pending[bolt.id]["inst"], bolt)


func test_a_re_route_kills_the_first_leg_and_lands_once() -> void:
	# A spell that resolves mid-flight turns rather than restarting
	# (SpellFlight._queue). The first leg's ghost is freed — and a tween
	# whose target is gone does not stop, it FINISHES on its next step, so
	# before 2026-09-02 the first landing ran against a freed ghost (the
	# "Lambda capture ... was freed" errors three live duels printed
	# thirty-seven times). The stale tween must die with its ghost, and
	# only the second leg may land.
	var flight: SpellFlight = screen._flight
	var bolt := _instance(0, "Lightning Bolt")
	var landings: Array = []
	flight.landed.connect(func(id: int) -> void: landings.append(id))
	var a := Rect2(Vector2(10, 10), Vector2(132, 106))
	var b := Rect2(Vector2(400, 10), Vector2(132, 106))
	var c := Rect2(Vector2(400, 300), Vector2(132, 106))
	flight._fly(bolt, a, b)
	var first: MiniCard = flight._ghosts[bolt.id]
	var first_tween: Tween = first.get_meta(SpellFlight.FLIGHT_META)
	assert_true(first_tween.is_valid(), "the first leg is in the air")
	flight._fly(bolt, b, c)
	assert_false(first_tween.is_valid(), "the re-route killed the first leg's tween")
	assert_ne(flight._ghosts[bolt.id], first, "a fresh ghost carries the second leg")
	await wait_seconds(SpellFlight.MOVE_SECONDS + 0.2)
	assert_eq(landings, [bolt.id], "exactly one landing, the second leg's")
	assert_false(flight._ghosts.has(bolt.id), "the ghost is cleared on landing")
	assert_false(flight.is_flying(bolt.id))


func test_the_graveyard_is_the_fallback_destination() -> void:
	assert_true(screen._flight.fallback.is_valid())
	for pid in 2:
		assert_ne(screen._graveyard_rect(pid).size, Vector2.ZERO,
			"seat %d has a pile to fall back to" % pid)


func test_the_duration_is_s30s_own() -> void:
	assert_eq(SpellFlight.MOVE_SECONDS, 0.3,
		"spellAnimationMoveDuration, duel_spell_animation.go:18")
