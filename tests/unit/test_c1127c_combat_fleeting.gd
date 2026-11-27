extends GameTest
## ROUND 3 OF THE PLAYER REPORT 2026-11-26, the computer's combat
## (engine/ai/combat_reads.gd), the two items 0.70.13 left:
##  1. a body an EFFECT put on the table and scheduled the loss of (Shallow
##     Grave's creature, Waylay's Knights) is read as gone at end of turn:
##     it attacks whatever is across the table, it blocks for nothing, and
##     the spell that makes it is cast when the body can be used — before
##     our combat with haste, or into their declared attack — and held at
##     every other moment;
##  2. the lethal push of the block ladder's pilots counts the gang block a
##     trampler invites.
## Each beside the gate's null arm ([member AiProfile.forecasts_tactics]
## off: the pilot as it was) or an unaffected control.

const COMBAT_READS := preload("res://engine/ai/combat_reads.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _rungs() -> Array:
	var out := [AiProfile.apprentice(), AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]
	for p in out: p.mistake_chance = 0.0
	return out


func _null(base: AiProfile = null) -> AiProfile:
	var p := base if base != null else AiProfile.wizard()
	p.mistake_chance = 0.0
	p.forecasts_tactics = false
	return p


func _ai(p: AiProfile) -> AiPlayer:
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _bury(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.players[pid].hand.erase(inst)
	g.players[pid].graveyard.append(inst)
	inst.zone = Mtg.Zone.GRAVEYARD
	return inst


## Cast [param card] for [param pid] by the engine, mana lent, and resolve it.
func _resolve(pid: int, card: String) -> void:
	var inst := give_hand(pid, card)
	for color in [Mtg.ManaColor.W, Mtg.ManaColor.B]: add_mana(pid, color, 3)
	assert_ok(g.cast_spell(pid, inst, [], 0, 0))
	resolve_stack()
	g.players[pid].mana_pool.clear()


func _names(ids: Array) -> Array:
	var out: Array = []
	for id in ids: out.append(g.find_instance(id).data.card_name)
	out.sort()
	return out


## Our turn from [param step] with [param card] in hand, [param lands] and
## [param grave] in our graveyard: was it cast, and what attacked.
func _turn(p: AiProfile, card: String, lands: Array, grave: Array, theirs: Array, step: int) -> Dictionary:
	before_each()
	var ai := _ai(p)
	for n in lands: put_battlefield(0, n)
	for n in theirs: put_battlefield(1, n)
	for n in grave: _bury(0, n)
	give_hand(0, card)
	advance_to_step(step)
	var out := {"cast": false, "attacked": []}
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and not g.game_over and guard < 200:
		guard += 1
		if g.awaiting_attackers:
			ai.act(g)
			out["attacked"] = _names(g.combat.attackers.keys())
		elif g.awaiting_blockers:
			g.declare_blockers(1, {})
		elif g.priority_player == 0:
			var line := ai.act(g)
			if line.contains(card): out["cast"] = true
			if line == "": g.pass_priority(0)
		else:
			g.pass_priority(g.priority_player)
	return out


## Their turn: [param theirs] attack us at [param life] with [param card]
## in our hand and [param lands]; what we cast and when, and our blocks.
func _defend(p: AiProfile, card: String, lands: Array, ours: Array, theirs: Array, life: int) -> Dictionary:
	before_each()
	var ai := _ai(p)
	g.players[0].life = life
	for n in lands: put_battlefield(0, n)
	for n in ours: put_battlefield(0, n)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	if card != "": give_hand(0, card)
	var ids: Array = []
	for n in theirs: ids.append(put_battlefield(1, n).id)
	var out := {"cast": "", "blocks": [], "life": life, "dead": []}
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and not g.game_over and guard < 300:
		guard += 1
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(1, ids))
		elif g.awaiting_blockers:
			ai.act(g)
			for b in g.combat.blocks:
				out["blocks"].append("%s>%s" % [g.find_instance(b).data.card_name,
					g.find_instance(int(g.combat.blocks[b])).data.card_name])
			out["blocks"].sort()
		elif g.priority_player == 0:
			var line := ai.act(g)
			if card != "" and line.contains(card) and out["cast"] == "":
				out["cast"] = Mtg.step_name(g.current_step())
			if line == "": g.pass_priority(0)
		else:
			g.pass_priority(g.priority_player)
	out["life"] = g.players[0].life
	for id in ids:
		if g.find_instance(id) == null or g.find_instance(id).zone != Mtg.Zone.BATTLEFIELD:
			out["dead"].append(id)
	return out


# ---------------------------------------- 1. the loss an effect scheduled --

func test_a_scheduled_loss_is_read_off_the_engine() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := _bury(0, "Hill Giant")
	_resolve(0, "Shallow Grave")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(COMBAT_READS.fleeting(g, giant), COMBAT_READS.LOST, "a delayed end-step exile, named in its memory")
	assert_eq(COMBAT_READS.fleeting(g, bears), COMBAT_READS.STAYS)
	var wurm := _bury(0, "Craw Wurm")
	_resolve(0, "Corpse Dance")
	assert_eq(COMBAT_READS.fleeting(g, wurm), COMBAT_READS.LOST)
	_resolve(0, "Waylay")
	var knights := 0
	for body in g.players[0].battlefield:
		if body.is_token:
			knights += 1
			assert_eq(COMBAT_READS.fleeting(g, body), COMBAT_READS.LOST, "a cleanup action, bound to its id and stamp")
	assert_eq(knights, 3)
	assert_eq(COMBAT_READS.fleeting(g, bears), COMBAT_READS.STAYS)


static func _nothing(_game: MtgGame, _source: CardInstance, _event: GameEvent, _id := 0, _stamp := 0) -> void:
	pass


func test_the_reading_is_the_line_and_the_object_it_names() -> void:
	var source := put_battlefield(0, "Sol Ring")
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var c := put_battlefield(0, "Grizzly Bears")
	var d := put_battlefield(0, "Grizzly Bears")
	# The id beside the stamp in the trigger's memory, whatever its key.
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _nothing,
		"Exile the token at the beginning of the next end step."), 0, source, false,
		{"token": a.id, "stamp": a.layer_timestamp})
	# The id and the stamp bound to the callable.
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
		_nothing.bind(b.id, b.layer_timestamp), "Return the guided creature to its owner's hand."), 0, source)
	# A condition in the line is a decision, and a line that takes nothing away is no loss.
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
		_nothing.bind(c.id, c.layer_timestamp), "Destroy that creature if it didn't attack this turn."), 0, source)
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
		_nothing.bind(d.id, d.layer_timestamp), "Put a +0/+1 counter on the creature."), 0, source)
	assert_eq(COMBAT_READS.fleeting(g, a), COMBAT_READS.LOST)
	assert_eq(COMBAT_READS.fleeting(g, b), COMBAT_READS.RETURNED)
	assert_eq(COMBAT_READS.fleeting(g, c), COMBAT_READS.STAYS)
	assert_eq(COMBAT_READS.fleeting(g, d), COMBAT_READS.STAYS)
	assert_eq(COMBAT_READS.fleeting(g, source), COMBAT_READS.STAYS)


func test_the_maker_is_read_off_its_printed_text() -> void:
	assert_true(COMBAT_READS.made_fleeting(CardRegistry.get_card("Waylay")).has("token"))
	assert_true(COMBAT_READS.made_fleeting(CardRegistry.get_card("Shallow Grave")).has("returns"))
	for other in ["Tidal Wave", "Corpse Dance", "Broken Visage", "Soulshriek", "Raise Dead", "Giant Growth", "Ball Lightning"]:
		assert_true(COMBAT_READS.made_fleeting(CardRegistry.get_card(other)).is_empty(), other)


func _attack_after(p: AiProfile, maker: String, grave: Array, theirs: Array) -> Array:
	before_each()
	var ai := _ai(p)
	for n in theirs: put_battlefield(1, n)
	for n in grave: _bury(0, n)
	advance_to_step(Mtg.Step.MAIN1)
	_resolve(0, maker)
	var guard := 0
	while not g.awaiting_attackers and guard < 50 and not g.game_over:
		if g.priority_player == 0: ai.act(g)
		else: g.pass_priority(g.priority_player)
		guard += 1
	assert_true(g.awaiting_attackers)
	ai.act(g)
	return _names(g.combat.attackers.keys())


func test_a_body_returned_for_one_turn_attacks_into_anything() -> void:
	for p in _rungs():
		assert_eq(_attack_after(p, "Shallow Grave", ["Hill Giant"], ["Craw Wurm"]), ["Hill Giant"], p.profile_name)
		assert_eq(_attack_after(p, "Corpse Dance", ["Hill Giant"], ["Craw Wurm"]), ["Hill Giant"], p.profile_name)
	assert_eq(_attack_after(_null(), "Shallow Grave", ["Hill Giant"], ["Craw Wurm"]), [], "gate off")


func test_the_return_is_cast_before_combat_and_attacks() -> void:
	for p in _rungs():
		for theirs in [[], ["Grizzly Bears"]]:
			var did := _turn(p, "Shallow Grave", ["Swamp", "Swamp"], ["Hill Giant"], theirs, Mtg.Step.MAIN1)
			assert_true(did["cast"] and did["attacked"] == ["Hill Giant"], "%s into %s: %s" % [p.profile_name, theirs, did])


func test_the_return_is_not_cast_for_nothing() -> void:
	for p in _rungs():
		assert_false(_turn(p, "Shallow Grave", ["Swamp", "Swamp"], ["Hill Giant"], [], Mtg.Step.MAIN2)["cast"],
			p.profile_name + ": after combat")
		assert_false(_turn(p, "Shallow Grave", ["Swamp", "Swamp"], [], [], Mtg.Step.MAIN1)["cast"],
			p.profile_name + ": an empty graveyard")
		assert_false(_turn(p, "Shallow Grave", ["Swamp", "Swamp"], ["Wall of Stone"], [], Mtg.Step.MAIN1)["cast"],
			p.profile_name + ": a defender")
		assert_false(_turn(p, "Shallow Grave", ["Swamp", "Swamp"], ["Hill Giant"], ["Wall of Stone"], Mtg.Step.MAIN1)["cast"],
			p.profile_name + ": into a blocker that stops it cold")


func test_the_knights_are_not_cast_in_our_own_turn() -> void:
	for p in _rungs():
		for step in [Mtg.Step.MAIN1, Mtg.Step.MAIN2]:
			assert_false(_turn(p, "Waylay", ["Plains", "Plains", "Plains"], [], ["Grizzly Bears"], step)["cast"],
				"%s %s" % [p.profile_name, Mtg.step_name(step)])
	assert_true(_turn(_null(), "Waylay", ["Plains", "Plains", "Plains"], [], ["Grizzly Bears"], Mtg.Step.MAIN1)["cast"],
		"gate off: three Knights that can neither attack nor stay")


func test_the_knights_ambush_a_declared_attack() -> void:
	# A Craw Wurm into an empty board at twenty: two Knights kill it.
	for p in _rungs():
		var did := _defend(p, "Waylay", ["Plains", "Plains", "Plains"], [], ["Craw Wurm"], 20)
		assert_eq(did["cast"], Mtg.step_name(Mtg.Step.DECLARE_ATTACKERS), "%s: %s" % [p.profile_name, did])
		assert_eq(did["dead"].size(), 1, "%s: the Wurm dies: %s" % [p.profile_name, did])
		assert_eq(did["life"], 20, p.profile_name)
	assert_eq(_defend(_null(), "Waylay", ["Plains", "Plains", "Plains"], [], ["Craw Wurm"], 20)["cast"], "", "gate off")


func test_the_knights_keep_us_alive() -> void:
	# Six at six life, and a Force of Nature the Knights cannot kill.
	for p in _rungs():
		var did := _defend(p, "Waylay", ["Plains", "Plains", "Plains"], [], ["Force of Nature"], 6)
		assert_eq(did["cast"], Mtg.step_name(Mtg.Step.DECLARE_ATTACKERS), "%s: %s" % [p.profile_name, did])
		assert_false(g.game_over, p.profile_name)


func test_the_knights_stay_in_hand_when_they_buy_nothing() -> void:
	for p in _rungs():
		# A flier they cannot block; nothing attacking at all.
		assert_eq(_defend(p, "Waylay", ["Plains", "Plains", "Plains"], [], ["Scryb Sprites"], 20)["cast"], "",
			p.profile_name + ": a flier")
		assert_eq(_defend(p, "Waylay", ["Plains", "Plains", "Plains"], [], [], 20)["cast"], "",
			p.profile_name + ": no attack")


func test_our_doomed_blockers_block_for_nothing() -> void:
	# The Knights are on the table (cast before the attack was declared):
	# they are spent on the attackers rather than kept.
	for p in _rungs():
		before_each()
		var ai := _ai(p)
		advance_to_step(Mtg.Step.MAIN1)
		advance_to_next_turn()
		assert_ok(g.pass_priority(1))
		_resolve(0, "Waylay")
		var wurm := put_battlefield(1, "Craw Wurm")
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(1, [wurm.id]))
		var guard := 0
		while not g.awaiting_blockers and guard < 20:
			g.pass_priority(g.priority_player)
			guard += 1
		ai.act(g)
		assert_gt(g.combat.blocks.size(), 1, "%s: enough Knights to kill a 6/4" % p.profile_name)


func test_their_returned_attacker_is_not_worth_a_body() -> void:
	# Their Hill Giant is exiled tonight whatever we do: ours in its way is
	# a Giant spent for three life, not a trade.
	for p in _rungs() + [_null()]:
		before_each()
		var ai := _ai(p)
		put_battlefield(0, "Hill Giant")
		advance_to_step(Mtg.Step.MAIN1)
		advance_to_next_turn()
		var giant := _bury(1, "Hill Giant")
		_resolve(1, "Shallow Grave")
		advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
		assert_ok(g.declare_attackers(1, [giant.id]))
		var guard := 0
		while not g.awaiting_blockers and guard < 20:
			g.pass_priority(g.priority_player)
			guard += 1
		ai.act(g)
		assert_eq(g.combat.blocks.size(), 0 if p.forecasts_tactics else 1, p.profile_name)
