extends GameTest
## ENGINE BUG SWEEP, 2026-09-02 — one test per finding of the read-only
## review that ran against the rules engine that day, each one written to
## FAIL against the code as the reviewer found it.
##
## 1. Blaze of Glory's "can block any number of creatures THIS TURN" never
##    expired: `_finish_cleanup` reset `must_block_this_turn` and left
##    `extra_blocks_this_turn` at -1, so a Wall that had been given the
##    order once could block the whole team every turn for the rest of the
##    game. It is cleared at cleanup now, beside the order it came with.
## 2. The search journal ([UndoLog]) did not cover a BLOCK: `declare_blockers`,
##    `set_block` and `remove_from_combat` recorded nothing, so an AI search
##    that explored a block left `combat.blocks` / `extra_blocks` /
##    `blocked_attackers` populated after `unmake_to`, with the
##    declare-blockers window closed. The three now record `combat` whole
##    (the way `declare_attackers` already did) and the per-blocker and
##    per-game fields they write.
## 3. Two zone helpers bypassed the journal: `put_from_hand_into_play`
##    erased the card from the hand without recording the hand (after an
##    unwind the card's zone said HAND but no hand array held it — a
##    phantom), and `pick_from_library` erased from and shuffled the
##    library without recording it.
## 4. Time Vault's heuristic hint ("skip one turn in five", rolled on
##    `game.rng`) was rolled BEFORE the turn-based hold, and a held human
##    seat re-runs `_begin_turn` from the top on every answer — so the real
##    game's random stream moved once per re-run (CONTRIBUTING.md rule 7). The
##    roll now happens only once the seat is not held.
## +  Found while instrumenting (2): the "it blocks each attacking creature
##    if able" check ran AFTER the block map had been written, so a REFUSED
##    declaration left its blocks behind (rule 3 — a refusal changes
##    nothing). The check now runs with the other validations.


# ------------------------------------------------------- the state differ --
# The same instrument tests/ai/test_undo_log.gd uses: GameSnapshot's own
# definition of "all the mutable state there is", diffed after a
# make/unmake round trip, so a field the journal misses fails BY NAME.

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


## A seat that takes the first card offered WITHOUT filing the question:
## the base agent's `choose_card` records every answer on the game's
## resolving-choices list, which is a resolution's business (and journaled
## there) rather than the library helper's.
class FirstPick extends DecisionAgent:
	func choose_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String, _optional := false, _adverse := false,
			_ordered := false) -> CardInstance:
		return candidates[0] if not candidates.is_empty() else null


## P0 attacks with [param attacker_ids]; P1 casts Blaze of Glory on
## [param conscript] in the window after attackers are declared; the game
## is left at the declare-blockers step.
func _attack_under_blaze_of_glory(attacker_ids: Array, conscript: CardInstance) -> void:
	var blaze := give_hand(1, "Blaze of Glory")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	resolve_stack()
	assert_ok(g.pass_priority(0))       # the defender's window
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, blaze, [TargetRef.card(conscript)]))
	resolve_stack()
	assert_eq(g.blocks_allowed(conscript), -1, "any number, this turn")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)


# ------------------------------------------- 1. the permission is per turn --

func test_blaze_of_glorys_permission_expires_at_cleanup() -> void:
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")     # 0/8
	_attack_under_blaze_of_glory([a.id, b.id], wall)
	assert_ok(g.declare_blockers(1, {wall.id: [a.id, b.id]}))
	advance_to_next_turn()                              # P1's turn 2
	assert_eq(wall.extra_blocks_this_turn, 0,
		"the grant is 'this turn' and cleanup must take it back with the order")
	assert_eq(g.blocks_allowed(wall), 1, "an ordinary Wall again")
	advance_to_next_turn()                              # P0's turn 3
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: [a.id, b.id]}),
		"can block only 1 attacker")
	assert_ok(g.declare_blockers(1, {wall.id: [a.id]}))


# ---------------------------------------- 2. blocks in the search journal --

func test_declaring_blockers_round_trips_through_the_journal() -> void:
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")   # blocks two
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)
	var before := _capture()
	var mark := g.make_mark()
	# A one-to-many block AND a gang block on the same attacker, so every
	# combat collection — blocks, extra_blocks, blocked_attackers and the
	# announced damage order — gets written.
	assert_ok(g.declare_blockers(1, {giant.id: [a.id, b.id], bears.id: a.id}))
	assert_false(g.awaiting_blockers)
	assert_true(g.combat.extra_blocks.has(giant.id))
	assert_true(g.combat.damage_order.has(a.id))
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "declaring blockers left state behind")
	assert_true(g.awaiting_blockers, "the declaration is open again")
	assert_true(g.combat.blocks.is_empty())
	assert_true(g.combat.extra_blocks.is_empty())
	assert_true(g.combat.blocked_attackers.is_empty())
	assert_true(g.combat.damage_order.is_empty())
	assert_false(giant.blocked_this_turn)
	assert_true(giant.blocked_ids_this_turn.is_empty())
	# ... and, the search over (end_search hands the game back — a journal
	# left allocated would record the game into itself on the next move),
	# the real declaration can still be made.
	g.end_search()
	assert_ok(g.declare_blockers(1, {giant.id: [a.id, b.id]}))
	assert_true(g.combat.is_blocking(giant.id, b.id))


func test_re_pointing_a_block_round_trips_through_the_journal() -> void:
	# set_block (False Orders, Sorrow's Path): a blocker moved from one
	# attacker to another, its extra blocks dropped, the new attacker
	# marked blocked.
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: [a.id, b.id]}))
	var before := _capture()
	var mark := g.make_mark()
	g.set_block(giant, b)
	assert_false(g.combat.extra_blocks.has(giant.id), "re-pointed, not added to")
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "set_block left state behind")
	assert_eq(g.combat.attackers_blocked_by(giant.id), [a.id, b.id] as Array[int])


func test_removing_from_combat_round_trips_through_the_journal() -> void:
	# remove_from_combat (Mijae Djinn's lost flip, Ydwen Efreet's, False
	# Orders' unblocking): every combat collection loses the creature.
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: [a.id, b.id]}))
	var before := _capture()
	var mark := g.make_mark()
	g.remove_from_combat(giant, true)   # the False Orders form unblocks too
	assert_false(g.combat.blocks.has(giant.id))
	assert_false(g.combat.blocked_attackers.has(a.id), "unblocked")
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "remove_from_combat left state behind")
	assert_true(g.combat.is_blocking(giant.id, a.id))
	assert_true(g.combat.is_blocking(giant.id, b.id))
	assert_true(g.combat.blocked_attackers.has(a.id), "blocked again (CR 509.1h)")


func test_a_refused_must_block_declaration_writes_no_blocks() -> void:
	# CONTRIBUTING.md rule 3: a refused action changes nothing. The Blaze of
	# Glory order was checked AFTER the block map had been written, so the
	# Bears here were left blocking the Ogre by a declaration the engine
	# had refused — and the next, accepted, declaration never named them.
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	var bears := put_battlefield(1, "Grizzly Bears")
	_attack_under_blaze_of_glory([a.id, b.id], wall)
	assert_refused(g.declare_blockers(1, {bears.id: a.id, wall.id: [a.id]}),
		"must block")
	assert_true(g.combat.blocks.is_empty(),
		"a refused declaration must leave no block behind")
	assert_true(g.combat.blocked_attackers.is_empty())
	assert_false(bears.blocked_this_turn)
	assert_true(bears.blocked_ids_this_turn.is_empty())
	assert_true(g.awaiting_blockers, "still waiting for a legal declaration")
	assert_ok(g.declare_blockers(1, {wall.id: [a.id, b.id]}))
	assert_false(g.combat.blocks.has(bears.id), "the Bears were never declared")
	assert_eq(g.combat.blockers_of(a.id), [wall.id] as Array[int])


# --------------------------------------- 3. zone helpers and the journal --

func test_put_from_hand_into_play_round_trips_through_the_journal() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := give_hand(0, "Grizzly Bears")
	var before := _capture()
	var mark := g.make_mark()
	g.put_from_hand_into_play(bear, 0)          # Eureka, Triassic Egg ...
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.players[0].hand.has(bear))
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "put_from_hand_into_play left state behind")
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(bear),
		"back in the hand ARRAY — a card whose zone says HAND but which no hand holds is a phantom")
	assert_false(g.players[0].battlefield.has(bear))


func test_pick_from_library_round_trips_through_the_journal() -> void:
	g.set_agent(0, FirstPick.new())
	var order_before: Array = g.players[0].library.duplicate()
	var before := _capture()
	var mark := g.make_mark()
	var found := g.pick_from_library(0,
		func(inst: CardInstance) -> bool: return inst.data.card_name == "Forest",
		"find a Forest")                         # Transmute Artifact's search
	assert_not_null(found)
	assert_eq(g.players[0].library.size(), order_before.size() - 1)
	g.put_into_play(found, 0)
	assert_eq(found.zone, Mtg.Zone.BATTLEFIELD)
	g.unmake_to(mark)
	assert_eq(_drift(before), [], "pick_from_library left state behind")
	assert_eq(found.zone, Mtg.Zone.LIBRARY)
	assert_true(g.players[0].library.has(found), "back in the library")
	assert_eq(g.players[0].library, order_before, "and the shuffle is unmade")


func test_a_fruitless_library_pick_still_unmakes_its_shuffle() -> void:
	# "Finds nothing" shuffles too (CR 701.19a), and that reordering is a
	# mutation like any other.
	g.set_agent(0, FirstPick.new())
	var order_before: Array = g.players[0].library.duplicate()
	var mark := g.make_mark()
	var found := g.pick_from_library(0,
		func(inst: CardInstance) -> bool: return inst.data.card_name == "Island",
		"find an Island")
	assert_null(found, "there is no Island in a library of Forests")
	g.unmake_to(mark)
	assert_eq(g.players[0].library, order_before, "the shuffle is unmade")


# ------------------------------------ 4. Time Vault's roll and the hold --

func test_time_vaults_hint_is_rolled_once_and_only_after_the_hold() -> void:
	# A held human seat re-runs _begin_turn from the top when it answers;
	# a roll ABOVE the hold moved game.rng on the first run and again on
	# the re-run. CONTRIBUTING.md rule 7: a seeded duel must roll the same
	# stream whether or not a seat was held on a question.
	var vault := put_battlefield(0, "Time Vault")
	var forest := put_battlefield(0, "Forest")
	forest.tapped = true
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()                      # P1's turn 2
	var state_before := g.rng.state
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_not_null(g.awaiting_choice, "the turn held on the Vault's question")
	assert_eq(g.awaiting_choice.source, "Time Vault")
	assert_eq(g.rng.state, state_before,
		"held BEFORE the heuristic rolls — a re-run must not roll a second time")
	assert_ok(g.answer_choice(0))               # "Play this turn."
	assert_null(g.awaiting_choice)
	assert_true(vault.tapped)
	var expected := RandomNumberGenerator.new()
	expected.state = state_before
	expected.randi()
	assert_eq(g.rng.state, expected.state, "exactly one roll for one question")
