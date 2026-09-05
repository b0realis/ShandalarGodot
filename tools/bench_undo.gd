extends SceneTree
## PHASE-3 MEASUREMENT (docs/ROADMAP.md, M4 phase 3): where the ~3 ms of a
## rewind actually goes, what a journal costs instead, and how wide the
## search space really is. Run:
##   ../tools/godot --headless --path . -s res://tools/bench_undo.gd
##
## The phase-3 design note concluded that snapshot-per-node is two orders
## of magnitude short and that an undo log is the opening, on the strength
## of one undecomposed number. This decomposes it and prices the
## alternative. Eight sections, and each answers one question:
##
##   A  Is the 3 ms the SNAPSHOT or the GAME? (take / the bare Object.get
##      loop inside it / restore / recalculate / state-based actions)
##   B  What does a search NODE cost, and how much of it is the move?
##   C  What is being captured — which classes, how many properties
##   D  What does a move actually CHANGE? The size a journal must record,
##      found by diffing a full snapshot across the move
##   E  What does one journal record cost to write and to write back
##   F  Is the journal SOUND? Make a move with it on, unmake it, and
##      compare every field GameSnapshot captures. Anything printed is a
##      mutation MtgGame does not record — a gap, not a rounding error.
##      (tests/ai/test_undo_log.gd pins the same thing in the suite.)
##   G  Nodes/second, journal against snapshot, on the same workload
##   H  How wide is a real main phase, a real attack, a real block —
##      measured over gauntlet duels, not estimated
##
## EVERYTHING HERE IS TIMED UNDER WHATEVER ELSE THE MACHINE IS DOING. The
## ratios in G are the robust reading; the absolute microseconds move by
## 10-20% between runs on a shared box.

const BOARDS := [5, 10, 20, 40]
const REPS := 200
const MOVE_REPS := 100

const FILL := ["Grizzly Bears", "Mountain", "Forest", "Bad Moon", "Wall of Stone",
	"Savannah Lions", "Llanowar Elves", "Crusade", "Air Elemental", "Swamp"]


func _initialize() -> void:
	print("")
	print("=== A. WHERE THE REWIND COST GOES (microseconds, mean of %d) ===" % REPS)
	print("board  objs   take    reads   walk%%   restore  recalc   sba     take+rest")
	print("-----  ----   -----   -----   -----   -------  ------   -----   ---------")
	for per_seat in BOARDS:
		_measure_costs(per_seat)
	print("")
	print("=== B. WHAT A SEARCH NODE COSTS (microseconds) ===")
	print("board  objs   move    snap-node  move/node%%   nodes/sec(snap)")
	print("-----  ----   -----   ---------  ----------   ---------------")
	for per_seat in BOARDS:
		_measure_node(per_seat)
	print("")
	print("=== C. HOW MANY OBJECTS, BY CLASS (board=20/seat) ===")
	_census(10)
	print("")
	print("=== D. WHAT A MOVE ACTUALLY CHANGES (the undo log's real size) ===")
	print("move                    board  objs-changed  fields-changed  objs-new")
	print("---------------------   -----  ------------  --------------  --------")
	for per_seat in [5, 20]:
		_dirty_census(per_seat, "cast Grizzly Bears", _apply_a_move)
		_dirty_census(per_seat, "play a land", _apply_land)
		_dirty_census(per_seat, "tap Forest for mana", _apply_tap)
		_dirty_census(per_seat, "declare attackers", _apply_attack)
	print("")
	print("=== E. WHAT A JOURNAL ENTRY COSTS (microseconds per 1000) ===")
	_bench_journal()
	print("")
	print("=== F. IS THE JOURNAL SOUND? (residual diff after unmake) ===")
	for per_seat in [5, 20]:
		_verify(per_seat, "cast Grizzly Bears", _apply_a_move)
		_verify(per_seat, "play a land", _apply_land)
		_verify(per_seat, "tap Forest for mana", _apply_tap)
		_verify(per_seat, "declare attackers", _apply_attack)
	print("")
	print("=== G. NODES/SECOND: journal vs snapshot, same workload ===")
	print("board  objs  snap-node  undo-node   records  speed-up  nodes/s(undo)")
	print("-----  ----  ---------  ---------   -------  --------  -------------")
	for per_seat in BOARDS:
		_measure_undo_node(per_seat)
	print("")
	print("=== H. HOW WIDE IS A REAL MAIN PHASE? (branching factor) ===")
	_branching()
	quit()


## Make a move with the journal on, unmake it, and compare EVERY captured
## field against what it was. Anything printed here is a mutation the
## journal does not cover — a gap, not a rounding error.
func _verify(per_seat: int, label: String, mover: Callable) -> void:
	var game := _build(per_seat)
	if mover == _apply_attack:
		_to_attackers(game)
	var snap := GameSnapshot.take(game)
	var saved: Array = []
	for i in snap._objects.size():
		saved.append((snap._values[i] as Array).duplicate(true))
	var mark := game.make_mark()
	mover.call(game)
	game.unmake_to(mark)
	var bad: Array = []
	for i in snap._objects.size():
		var obj: Object = snap._objects[i]
		var pr: Array = snap._props[i]
		var old: Array = saved[i]
		var k := 0
		var cls: String = obj.get_script().get_global_name()
		for name in pr[0]:
			if obj.get(name) != old[k]:
				bad.append("%s.%s" % [cls, name])
			k += 1
		for name in pr[1]:
			if name == &"undo_log":
				k += 1
				continue      # the instrument, not the state
			if not _same(obj.get(name), old[k]):
				bad.append("%s.%s" % [cls, name])
			k += 1
	var rng_ok: bool = game.rng.state == snap._rng_state
	snap.restore()
	print("  %-23s board=%-3d  %s%s" % [label, per_seat * 2,
		"CLEAN" if bad.is_empty() and rng_ok else "LEAKS: " + ", ".join(bad),
		"" if rng_ok else "  + rng.state"])


## Play real AI-vs-AI duels and, at every sorcery-speed decision the AI
## reaches, count the moves a search would have to expand: land drops,
## castable cards times their legal target tuples, and activatable
## abilities times theirs. Tap plans are NOT counted — two payments for the
## same cast are the same position, which is exactly what a transposition
## table is for.
##
## This is the number that decides whether the throughput above is enough:
## nodes for a d-ply search go as (branching factor)^d.
func _branching() -> void:
	var widths: Array[int] = []
	var attack_widths: Array[int] = []
	var block_widths: Array[int] = []
	for seed_value in [11, 22, 33, 44, 55]:
		var game := MtgGame.new()
		var deck := DeckList.load_file("res://decks/black_red_raiders.deck")
		var deck2 := DeckList.load_file("res://decks/blue_skies.deck")
		if deck == null or deck2 == null:
			print("  (decks not loadable — skipped)")
			return
		game.setup(deck.cards, deck2.cards, "A", "B", 20, 20, seed_value)
		game.start(7)
		var ai0 := AiPlayer.new(0, AiProfile.wizard())
		var ai1 := AiPlayer.new(1, AiProfile.wizard())
		game.set_agent(0, ai0)
		game.set_agent(1, ai1)
		for _step in 20000:
			if game.game_over:
				break
			if game.active_player == 0 and game.priority_player == 0 \
					and Mtg.is_main_step(game.current_step()) \
					and game.stack.is_empty() and not game.awaiting_attackers \
					and not game.awaiting_blockers:
				widths.append(_count_moves(ai0, game, 0))
			if game.awaiting_attackers and game.active_player == 0:
				attack_widths.append(_attack_subsets(game, 0))
				block_widths.append(_block_assignments(game, 0))
			if ai0.act(game) == "" and ai1.act(game) == "":
				break
	if widths.is_empty():
		print("  (no decision points reached)")
		return
	widths.sort()
	var total := 0
	for w in widths:
		total += w
	print("  %d main-phase decisions over 5 duels" % widths.size())
	print("  moves per decision: mean %.1f   median %d   p90 %d   max %d" % [
		float(total) / widths.size(), widths[widths.size() / 2],
		widths[int(widths.size() * 0.9)], widths[widths.size() - 1]])
	var b: float = float(total) / widths.size()
	print("  a full main phase is a LINE, not one move: at b=%.1f a plain" % b)
	print("  d-ply expansion is b^d = %.0f (d=2), %.0f (d=3), %.0f (d=4)" % [
		pow(b, 2), pow(b, 3), pow(b, 4)])
	_report("  attack declarations (2^attackers)", attack_widths)
	_report("  block assignments (per attack)   ", block_widths)


func _report(label: String, xs: Array[int]) -> void:
	if xs.is_empty():
		print("%s: none reached" % label)
		return
	xs.sort()
	var total := 0
	for x in xs:
		total += x
	print("%s: mean %.0f  median %d  p90 %d  max %d  (n=%d)" % [
		label, float(total) / xs.size(), xs[xs.size() / 2],
		xs[int(xs.size() * 0.9)], xs[xs.size() - 1], xs.size()])


## Every subset of legal attackers — the width of ONE declare-attackers
## decision, and the reason combat rather than the main phase is where a
## Magic search explodes.
func _attack_subsets(game: MtgGame, pid: int) -> int:
	var n := 0
	for inst in game.players[pid].battlefield:
		if inst.is_creature() and not inst.summoning_sick and not inst.tapped \
				and not inst.has_keyword(Mtg.Keyword.DEFENDER):
			n += 1
	return int(pow(2.0, mini(n, 20)))


## Every way the defender could assign blockers to the widest attack:
## (attackers + 1) ^ blockers, which is the second half of the combat
## explosion and the larger one.
func _block_assignments(game: MtgGame, attacker_pid: int) -> int:
	var attackers := 0
	for inst in game.players[attacker_pid].battlefield:
		if inst.is_creature() and not inst.summoning_sick and not inst.tapped \
				and not inst.has_keyword(Mtg.Keyword.DEFENDER):
			attackers += 1
	var blockers := 0
	for inst in game.players[game.opponent_of(attacker_pid)].battlefield:
		if inst.is_creature() and not inst.tapped:
			blockers += 1
	return int(pow(float(attackers + 1), float(mini(blockers, 12))))


## Every sorcery-speed move available to [param pid] right now, counted the
## way a search would generate them.
func _plan(ai: AiPlayer, game: MtgGame, cost: ManaCost, surcharge: int) -> Array:
	return ai._plan_taps(game, cost, surcharge)


func _count_moves(ai: AiPlayer, game: MtgGame, pid: int) -> int:
	var n := 1                       # passing is always a move
	var seen_lands := {}
	for inst in game.players[pid].hand:
		if inst.is_land():
			if game.players[pid].lands_played_this_turn < 1 \
					and not seen_lands.has(inst.data.card_name):
				seen_lands[inst.data.card_name] = true
				n += 1
			continue
		# Affordability the way the AI judges it: what the UNTAPPED
		# sources could pay for, not what is already floating. Reading the
		# pool alone said b=1.2, which is only true of an AI that has
		# already spent its mana.
		var surcharge := game.spell_surcharge(pid, inst.data)
		if _plan(ai, game, inst.data.cost, surcharge).is_empty() \
				and not (inst.data.cost.mana_value() == 0 and surcharge == 0):
			continue
		var modes: int = maxi(inst.data.modes.size(), 1)
		for mode in modes:
			var specs := game._spell_target_specs(inst.data, mode)
			var combos := 1
			for spec in specs:
				combos *= maxi(spec.legal_targets(game, inst).size(), 1)
			n += combos
	for inst in game.players[pid].battlefield:
		for i in inst.data.activated_abilities.size():
			var ability: ActivatedAbility = inst.data.activated_abilities[i]
			if ability.cost != null \
					and _plan(ai, game, ability.cost, 0).is_empty() \
					and ability.cost.mana_value() > 0:
				continue
			var combos := 1
			for spec in ability.target_specs():
				combos *= maxi(spec.legal_targets(game, inst).size(), 1)
			n += combos
	return n


func _measure_undo_node(per_seat: int) -> void:
	var game := _build(per_seat)
	GameSnapshot.take(game).restore()
	var probe := GameSnapshot.take(game)
	var n := probe.object_count()
	probe.restore()

	var t := Time.get_ticks_usec()
	for _i in MOVE_REPS:
		var snap := GameSnapshot.take(game)
		_apply_a_move(game)
		snap.restore()
	var snap_us := float(Time.get_ticks_usec() - t) / MOVE_REPS

	# Warm: one make/unmake before timing.
	var w := game.make_mark()
	_apply_a_move(game)
	game.unmake_to(w)
	var records := 0
	t = Time.get_ticks_usec()
	for _i in MOVE_REPS:
		var mark := game.make_mark()
		_apply_a_move(game)
		records = game.undo_log.size() - mark
		game.unmake_to(mark)
	var undo_us := float(Time.get_ticks_usec() - t) / MOVE_REPS

	print("%5d  %4d  %9.0f  %9.0f   %7d  %7.1fx  %13.0f" % [
		per_seat * 2, n, snap_us, undo_us, records,
		snap_us / maxf(undo_us, 0.001), 1000000.0 / maxf(undo_us, 0.001)])


## Apply [param mover], then count how much of the game moved. This is the
## size an undo log would have to record and replay — the number the whole
## phase-3 decision turns on.
func _dirty_census(per_seat: int, label: String, mover: Callable) -> void:
	var game := _build(per_seat)
	if mover == _apply_attack:
		_to_attackers(game)
	var snap := GameSnapshot.take(game)
	var before_ids := {}
	for obj in snap._objects:
		before_ids[obj.get_instance_id()] = true
	# Save the values OUT of the snapshot before the move, because restore()
	# hands its containers back and we want to compare against them.
	var saved: Array = []
	for i in snap._objects.size():
		saved.append((snap._values[i] as Array).duplicate(true))
	mover.call(game)
	var objs_changed := 0
	var fields_changed := 0
	var names: Array = []
	for i in snap._objects.size():
		var obj: Object = snap._objects[i]
		var pr: Array = snap._props[i]
		var old: Array = saved[i]
		var k := 0
		var any := false
		var cls: String = obj.get_script().get_global_name()
		for name in pr[0]:
			if obj.get(name) != old[k]:
				fields_changed += 1
				any = true
				names.append("%s.%s" % [cls, name])
			k += 1
		for name in pr[1]:
			if not _same(obj.get(name), old[k]):
				fields_changed += 1
				any = true
				names.append("%s.%s" % [cls, name])
			k += 1
		if any:
			objs_changed += 1
	var after := GameSnapshot.take(game)
	var objs_new := 0
	for obj in after._objects:
		if not before_ids.has(obj.get_instance_id()):
			objs_new += 1
	after.restore()
	snap.restore()
	print("%-23s %5d  %12d  %14d  %8d" % [
		label, per_seat * 2, objs_changed, fields_changed, objs_new])
	if per_seat == 5:
		print("        fields: %s" % ", ".join(names))


static func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	if ta != typeof(b):
		return false
	if ta == TYPE_OBJECT:
		return a == b
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


## The floor of a field-level undo log: one (object, property, old value)
## record pushed and one written back. Nothing reflective per OBJECT, only
## per changed FIELD.
func _bench_journal() -> void:
	var game := _build(10)
	var inst: CardInstance = game.players[0].battlefield[0]
	const N := 1000
	const OUTER := 200
	var t := Time.get_ticks_usec()
	for _o in OUTER:
		var log: Array = []
		for _i in N:
			log.append(inst)
			log.append(&"tapped")
			log.append(inst.tapped)
	var push_us := float(Time.get_ticks_usec() - t) / OUTER
	# Replay backwards, as an unmake would.
	var log2: Array = []
	for _i in N:
		log2.append(inst)
		log2.append(&"tapped")
		log2.append(inst.tapped)
	t = Time.get_ticks_usec()
	for _o in OUTER:
		var i := log2.size() - 3
		while i >= 0:
			(log2[i] as Object).set(log2[i + 1], log2[i + 2])
			i -= 3
	var pop_us := float(Time.get_ticks_usec() - t) / OUTER
	print("  push 1000 records: %6.0f us   (%.3f us each)" % [push_us, push_us / N])
	print("  undo 1000 records: %6.0f us   (%.3f us each)" % [pop_us, pop_us / N])
	print("  a %d-field move would therefore cost about %.0f us to unmake" % [
		40, 40.0 * pop_us / N])
	quit()


func _measure_costs(per_seat: int) -> void:
	var game := _build(per_seat)
	GameSnapshot.take(game).restore()          # warm the per-script caches

	var probe := GameSnapshot.take(game)
	var count := probe.object_count()
	var objects: Array = probe._objects.duplicate()
	var props: Array = probe._props.duplicate()
	probe.restore()

	# take
	var t := Time.get_ticks_usec()
	var held: Array = []
	for _i in REPS:
		held.append(GameSnapshot.take(game))
	var take_us := float(Time.get_ticks_usec() - t) / REPS

	# restore
	t = Time.get_ticks_usec()
	for snap in held:
		(snap as GameSnapshot).restore()
	var restore_us := float(Time.get_ticks_usec() - t) / REPS
	held.clear()

	# reads only: the same Object.get() calls take() makes, with NO graph
	# walk, no seen-set, no container duplication. The reflection floor.
	t = Time.get_ticks_usec()
	for _i in REPS:
		var sink: Variant = null
		for oi in objects.size():
			var obj: Object = objects[oi]
			var pr: Array = props[oi]
			for name in pr[0]:
				sink = obj.get(name)
			for name in pr[1]:
				sink = obj.get(name)
	var reads_us := float(Time.get_ticks_usec() - t) / REPS

	t = Time.get_ticks_usec()
	for _i in REPS:
		game.recalculate()
	var recalc_us := float(Time.get_ticks_usec() - t) / REPS

	t = Time.get_ticks_usec()
	for _i in REPS:
		game.check_state_based_actions()
	var sba_us := float(Time.get_ticks_usec() - t) / REPS

	var walk_pct := 100.0 * (take_us - reads_us) / maxf(take_us, 0.001)
	print("%5d  %4d   %5.0f   %5.0f   %4.0f%%   %7.0f  %6.0f   %5.0f   %9.0f" % [
		per_seat * 2, count, take_us, reads_us, walk_pct, restore_us,
		recalc_us, sba_us, take_us + restore_us])


func _measure_node(per_seat: int) -> void:
	var game := _build(per_seat)
	GameSnapshot.take(game).restore()
	var count := GameSnapshot.take(game)
	var n := count.object_count()
	count.restore()

	# One search move, made and unmade the ONLY way available today.
	# Grizzly Bears from hand: cast + resolve + SBA, which is what any
	# node expansion has to pay whatever the unmake mechanism is. The MOVE
	# is timed INSIDE the loop rather than by subtracting two ~3.5 ms
	# totals — that difference is smaller than its own noise.
	var move_acc := 0
	var t := Time.get_ticks_usec()
	for _i in MOVE_REPS:
		var snap := GameSnapshot.take(game)
		var m0 := Time.get_ticks_usec()
		_apply_a_move(game)
		move_acc += Time.get_ticks_usec() - m0
		snap.restore()
	var node_us := float(Time.get_ticks_usec() - t) / MOVE_REPS
	var move_us := float(move_acc) / MOVE_REPS

	print("%5d  %4d   %5.0f   %9.0f  %9.0f%%   %15.0f" % [
		per_seat * 2, n, move_us, node_us,
		100.0 * move_us / maxf(node_us, 0.001), 1000000.0 / maxf(node_us, 0.001)])


## The move a search would make: cast a creature from hand and resolve it.
func _apply_a_move(game: MtgGame) -> void:
	var pid := 0
	var inst: CardInstance = null
	for c in game.players[pid].hand:
		if c.data.card_name == "Grizzly Bears":
			inst = c
			break
	if inst == null:
		return
	game.players[pid].mana_pool.add(Mtg.ManaColor.G, 1)
	game.players[pid].mana_pool.add(Mtg.ManaColor.G, 1)
	var refusal := game.cast_spell(pid, inst)
	if refusal != "":
		push_error("bench: cast refused: " + refusal)
		return
	while not game.stack.is_empty():
		game._resolve_top()
	game.check_state_based_actions()


func _apply_land(game: MtgGame) -> void:
	for c in game.players[0].hand:
		if c.is_land():
			game.play_land(0, c)
			return


func _apply_tap(game: MtgGame) -> void:
	for c in game.players[0].battlefield:
		if c.is_land() and not c.tapped:
			game.tap_for_mana(0, c)
			return


func _to_attackers(game: MtgGame) -> void:
	var guard := 0
	while game.current_step() != Mtg.Step.DECLARE_ATTACKERS and guard < 20:
		game.pass_priority(game.priority_player)
		guard += 1


func _apply_attack(game: MtgGame) -> void:
	var ids: Array = []
	for c in game.players[0].battlefield:
		if c.is_creature() and not c.summoning_sick \
				and not c.has_keyword(Mtg.Keyword.DEFENDER):
			ids.append(c.id)
	var why := game.declare_attackers(0, ids)
	if why != "" or ids.is_empty():
		push_error("bench: attack (%d ids) refused: %s" % [ids.size(), why])



func _census(per_seat: int) -> void:
	var game := _build(per_seat)
	var snap := GameSnapshot.take(game)
	var by_class := {}
	var props_by_class := {}
	for i in snap._objects.size():
		var obj: Object = snap._objects[i]
		var cls: String = obj.get_script().get_global_name()
		by_class[cls] = int(by_class.get(cls, 0)) + 1
		var pr: Array = snap._props[i]
		props_by_class[cls] = pr[0].size() + pr[1].size()
	snap.restore()
	var keys: Array = by_class.keys()
	keys.sort()
	var total_props := 0
	for k in keys:
		var n: int = by_class[k]
		var p: int = props_by_class[k]
		total_props += n * p
		print("  %-20s %4d objects x %3d props = %6d property reads" % [k, n, p, n * p])
	print("  %-20s %25s %6d" % ["TOTAL", "", total_props])


func _build(per_seat: int) -> MtgGame:
	var game := MtgGame.new()
	var filler: Array = []
	for _i in 40:
		filler.append("Forest")
	game.setup(filler, filler, "P0", "P1", 20, 20, 20260901)
	game.start(0)
	for pid in 2:
		for i in per_seat:
			_put(game, pid, FILL[i % FILL.size()])
		for i in 7:
			var inst := _make(game, pid, FILL[i % FILL.size()])
			inst.zone = Mtg.Zone.HAND
			game.players[pid].hand.append(inst)
		for i in 6:
			var dead := _make(game, pid, FILL[i % FILL.size()])
			dead.zone = Mtg.Zone.GRAVEYARD
			game.players[pid].graveyard.append(dead)
	# One Grizzly Bears in seat 0's hand for the move benchmark.
	var bears := _make(game, 0, "Grizzly Bears")
	bears.zone = Mtg.Zone.HAND
	game.players[0].hand.append(bears)
	# Park in seat 0's precombat main with an empty stack: the only moment
	# a sorcery-speed move is legal, and where a search would be thinking.
	var guard := 0
	while game.current_step() != Mtg.Step.MAIN1 and not game.game_over \
			and guard < 400:
		if game.awaiting_attackers:
			game.declare_attackers(game.active_player, [])
		elif game.awaiting_blockers:
			game.declare_blockers(game.opponent_of(game.active_player), {})
		else:
			game.pass_priority(game.priority_player)
		guard += 1
	game.recalculate()
	return game


func _make(game: MtgGame, pid: int, card_name: String) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	var inst := CardInstance.new(data, game._next_instance_id, pid)
	game._next_instance_id += 1
	game._instances[inst.id] = inst
	return inst


func _put(game: MtgGame, pid: int, card_name: String) -> CardInstance:
	var inst := _make(game, pid, card_name)
	game._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst
