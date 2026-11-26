extends GameTest
## PLAYER REPORT 2026-11-26, the computer's play: "Sandstorm — casts it
## outside of combat", "Hurkyl's Recall — casts it when you have no
## artifacts", "Stream of Life — casts it turn 2 for one life gain". When a
## spell is worth its card (engine/ai/spell_timing.gd):
##  1. a spell whose printed effect is over attacking or blocking creatures
##     is never cast with none — every standard rung; the gate off is the
##     pilot as it was;
##  2. it IS cast once they attack and it pays, at once or with the blocks
##     known, and never into our own attack;
##  3. a cast that would change nothing stays in hand;
##  4. a set of permanents is worth the card or waits;
##  5. an X that only scales is held until it is worth it — unless the life
##     is needed now or the hand is full;
##  6. the forecast puts everything back, the random stream included.

const TIMING := preload("res://engine/ai/spell_timing.gd")


func after_each() -> void:
	g = null


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _rungs() -> Array:
	return [AiProfile.apprentice(), AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]


## Our main phase, until the pilot passes.
func _main(ai: AiPlayer) -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	var lines: Array = []
	for _i in 8:
		if g.game_over or g.priority_player != 0 or g.current_step() != Mtg.Step.MAIN1:
			break
		var line := ai.act(g)
		lines.append(line)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass": break
	return lines


## Their turn: [param attackers] attack, the pilot answers every priority
## it gets until the combat damage step; [param blocks] is declared for it.
func _their_attack(ai: AiPlayer, attackers: Array, blocks: Dictionary = {}) -> Array:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	assert_ok(g.declare_attackers(1, ids))
	var lines: Array = []
	var guard := 0
	while not g.game_over and guard < 60 and g.active_player == 1 \
			and g.current_step() <= Mtg.Step.DECLARE_BLOCKERS:
		guard += 1
		if g.awaiting_blockers:
			var live := {}
			for blocker_id in blocks:
				var blocker := g.find_instance(blocker_id)
				var attacker := g.find_instance(blocks[blocker_id])
				if blocker != null and blocker.zone == Mtg.Zone.BATTLEFIELD \
						and attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD:
					live[blocker_id] = blocks[blocker_id]
			assert_ok(g.declare_blockers(0, live))
		elif g.priority_player == 0:
			var line := ai.act(g)
			if line != "pass": lines.append("%s: %s" % [Mtg.step_name(g.current_step()), line])
		else:
			g.pass_priority(1)
	return lines


# --------------------------------------------------- 1 no combat, no cast --

func test_sandstorm_is_not_cast_outside_combat() -> void:
	for profile in _rungs():
		for across in ["", "Grizzly Bears", "Savannah Lions"]:
			before_each()
			var ai := _ai(profile)
			put_battlefield(0, "Forest")
			put_battlefield(0, "Forest")
			if across != "": put_battlefield(1, across)
			var storm := give_hand(0, "Sandstorm")
			var lines := _main(ai)
			assert_eq(storm.zone, Mtg.Zone.HAND, "%s, %s across: %s" % [profile.profile_name, across, lines])


func test_null_arm_casts_it_as_before() -> void:
	var ai := _ai(_null())
	put_battlefield(0, "Forest")
	var storm := give_hand(0, "Sandstorm")
	_main(ai)
	assert_ne(storm.zone, Mtg.Zone.HAND, "the gate off is the pilot as it was")


func test_blocking_and_attacking_pumps_wait_for_the_combat() -> void:
	for card_name in ["Piety", "Army of Allah", "Morale", "Righteousness"]:
		before_each()
		var ai := _ai()
		for _i in 4: put_battlefield(0, "Plains")
		put_battlefield(0, "Grizzly Bears")
		put_battlefield(1, "Grizzly Bears")
		var card := give_hand(0, card_name)
		advance_to_step(Mtg.Step.MAIN1)
		assert_ne(ai._cast_gate(g, card), "", "%s has no combat to act on" % card_name)
		var lines := _main(ai)
		assert_eq(card.zone, Mtg.Zone.HAND, "%s: %s" % [card_name, lines])


func test_the_shape_is_read_off_the_printed_line() -> void:
	var rows := {
		"Sandstorm": [true, false], "Army of Allah": [true, false], "Piety": [false, true],
		"Righteousness": [false, true], "Remove Enchantments": [false, false],
		"Giant Growth": [false, false], "Lightning Bolt": [false, false],
		"Hurkyl's Recall": [false, false],
	}
	for card_name in rows:
		var shape := TIMING.shape_of(CardRegistry.get_card(card_name))
		assert_eq([shape["attack"], shape["block"]], rows[card_name], card_name)
	assert_true(TIMING.shape_of(CardRegistry.get_card("Fog"))["combat"])
	assert_true(TIMING.shape_of(CardRegistry.get_card("Hurkyl's Recall"))["set"])
	assert_true(TIMING.shape_of(CardRegistry.get_card("Braingeyser"))["hidden"])
	var read := TIMING._read_shape(TIMING.plain(
		"Untap target nonattacking creature. (Not an attacking creature.)"))
	assert_false(read["attack"], "nonattacking, and reminder text, are not the shape")
	read = TIMING._read_shape(TIMING.plain("Destroy target nonblack attacking creature."))
	assert_true(read["attack"])
	read = TIMING._read_shape(TIMING.plain("Target creature gains trample until end of turn. When that creature becomes blocked this turn, it gets +1/+1 until end of turn for each creature blocking it."))
	assert_false(read["block"], "a rider is not what the spell acts on")


# ------------------------------------------------- 2 cast in its combat --

func test_sandstorm_is_cast_when_their_attackers_die_to_it() -> void:
	for profile in [AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]:
		before_each()
		var ai := _ai(profile)
		put_battlefield(0, "Forest")
		var lions := [put_battlefield(1, "Savannah Lions"), put_battlefield(1, "Savannah Lions")]
		var storm := give_hand(0, "Sandstorm")
		var lines := _their_attack(ai, lions)
		assert_eq(storm.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(lions[0].zone, Mtg.Zone.GRAVEYARD, profile.profile_name)
		assert_eq(lions[1].zone, Mtg.Zone.GRAVEYARD, profile.profile_name)
		assert_eq(g.players[0].life, 20, profile.profile_name)


func test_sandstorm_waits_when_nothing_would_die() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	var giant := put_battlefield(1, "Hill Giant")
	var storm := give_hand(0, "Sandstorm")
	var lines := _their_attack(ai, [giant])
	assert_eq(storm.zone, Mtg.Zone.HAND, "one damage on a 3/3 is a card for nothing: %s" % [lines])


func test_sandstorm_finishes_a_blocked_attacker() -> void:
	# Bears block a Hill Giant: two damage and the storm's one kill it.
	var ai := _ai()
	put_battlefield(0, "Forest")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var storm := give_hand(0, "Sandstorm")
	var lines := _their_attack(ai, [giant], {bears.id: giant.id})
	assert_eq(storm.zone, Mtg.Zone.GRAVEYARD, "the blocks are known: %s" % [lines])
	assert_true(lines.any(func(l: String) -> bool: return l.begins_with("Declare Blockers")), str(lines))


func test_sandstorm_is_not_cast_into_our_own_attack() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Savannah Lions")
	put_battlefield(0, "Savannah Lions")
	var storm := give_hand(0, "Sandstorm")
	advance_to_step(Mtg.Step.MAIN1)
	var guard := 0
	while not g.game_over and g.active_player == 0 and guard < 80:
		guard += 1
		if g.awaiting_blockers and g.block_chooser() == 1:
			g.declare_blockers(1, {})
		elif g.awaiting_attackers or g.priority_player == 0:
			ai.act(g)
		else:
			g.pass_priority(1)
	assert_eq(storm.zone, Mtg.Zone.HAND, "it would have hit our own Lions")
	assert_eq(g.players[1].life, 16, "and the Lions attacked")


# ------------------------------------------ 3 the cast that changes nothing --

func test_a_cast_that_changes_nothing_stays_in_hand() -> void:
	# No blue creature to tap; no creature to shrink; no damage to reverse
	# or to prevent, on our own Bears or anywhere.
	for row in [["Riptide", "Island"], ["Holy Light", "Plains"], ["Reverse Damage", "Plains"],
			["Eye for an Eye", "Plains"], ["Healing Salve", "Plains"], ["Guardian Angel", "Plains"]]:
		before_each()
		var ai := _ai()
		for _i in 4: put_battlefield(0, row[1])
		if row[0] in ["Healing Salve", "Guardian Angel"]: put_battlefield(0, "Grizzly Bears")
		var card := give_hand(0, row[0])
		var lines := _main(ai)
		assert_eq(card.zone, Mtg.Zone.HAND, "%s: %s" % [row[0], lines])


func test_the_same_card_is_cast_when_it_does_something() -> void:
	var ai := _ai()
	for _i in 4: put_battlefield(0, "Plains")
	var elves := put_battlefield(1, "Llanowar Elves")
	var light := give_hand(0, "Holy Light")
	var lines := _main(ai)
	assert_ne(light.zone, Mtg.Zone.HAND, "their 1/1 dies to it: %s" % [lines])
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------- 4 the set's worth --

func test_recall_waits_for_artifacts_worth_a_card() -> void:
	for row in [["", false], ["Sol Ring", false], ["Juggernaut", true]]:
		before_each()
		var ai := _ai()
		for _i in 3: put_battlefield(0, "Island")
		put_battlefield(1, "Grizzly Bears")
		if row[0] != "": put_battlefield(1, row[0])
		var recall := give_hand(0, "Hurkyl's Recall")
		var lines := _main(ai)
		assert_eq(recall.zone != Mtg.Zone.HAND, row[1], "their artifacts: '%s' (%s)" % [row[0], lines])


func test_recall_is_not_aimed_at_our_own_artifacts() -> void:
	var ai := _ai()
	for _i in 3: put_battlefield(0, "Island")
	put_battlefield(0, "Juggernaut")
	var recall := give_hand(0, "Hurkyl's Recall")
	var lines := _main(ai)
	assert_eq(recall.zone, Mtg.Zone.HAND, str(lines))


# ------------------------------------------------------ 5 the X too small --

func _stream(forests: int, life: int, across: String, extra_hand := 0) -> Dictionary:
	before_each()
	var ai := _ai()
	g.players[0].life = life
	for _i in forests: put_battlefield(0, "Forest")
	if across != "": put_battlefield(1, across)
	var stream := give_hand(0, "Stream of Life")
	for _i in extra_hand: give_hand(0, "Shivan Dragon")
	var lines := _main(ai)
	return {"cast": stream.zone != Mtg.Zone.HAND, "life": g.players[0].life, "lines": lines}


func test_stream_of_life_is_not_cast_for_one_on_turn_two() -> void:
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		put_battlefield(0, "Forest")
		put_battlefield(0, "Forest")
		put_battlefield(1, "Grizzly Bears")
		var stream := give_hand(0, "Stream of Life")
		var lines := _main(ai)
		assert_eq(stream.zone, Mtg.Zone.HAND, "%s: %s" % [profile.profile_name, lines])
	var hurt := _stream(3, 14, "Grizzly Bears")
	assert_false(bool(hurt["cast"]), "two life at fourteen is still not a card: %s" % [hurt["lines"]])


func test_stream_of_life_is_cast_when_x_is_worth_it() -> void:
	var late := _stream(6, 14, "Grizzly Bears")
	assert_true(bool(late["cast"]), str(late["lines"]))
	assert_eq(int(late["life"]), 19, "all five")


func test_stream_of_life_is_cast_small_when_the_life_is_needed() -> void:
	var low := _stream(2, 3, "Hill Giant")
	assert_true(bool(low["cast"]), "3 life in front of a Hill Giant: %s" % [low["lines"]])


func test_stream_of_life_goes_before_it_is_discarded() -> void:
	var full := _stream(2, 14, "Grizzly Bears", 7)
	assert_true(bool(full["cast"]), "eight cards in hand: %s" % [full["lines"]])


func test_null_arm_streams_for_one() -> void:
	var ai := _ai(_null())
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Grizzly Bears")
	var stream := give_hand(0, "Stream of Life")
	_main(ai)
	assert_ne(stream.zone, Mtg.Zone.HAND, "the gate off is the pilot as it was")


# ------------------------------------------- 6 the forecast puts it back --

func test_the_forecast_changes_nothing() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	var lions := put_battlefield(1, "Savannah Lions")
	var bears := put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	var recall := give_hand(0, "Hurkyl's Recall")
	advance_to_step(Mtg.Step.MAIN1)
	var before := ai._public_signature(g)
	var state := g.rng.state
	var seen := TIMING.forecast(g, ai, bolt, [TargetRef.card(lions)], 0, 0)
	assert_true(bool(seen["changed"]))
	assert_eq(int(seen["theirs_lost"]), 1)
	assert_gt(float(seen["swing"]), TIMING.CARD_BAR)
	seen = TIMING.forecast(g, ai, bolt, [TargetRef.card(bears)], 0, 0)
	assert_lt(float(seen["swing"]), 0.0, "our own Bears")
	seen = TIMING.forecast(g, ai, recall, [TargetRef.player(1)], 0, 0)
	assert_false(bool(seen["changed"]), "no artifact: nothing but the card moved")
	assert_eq(ai._public_signature(g), before)
	assert_eq(g.rng.state, state)
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_eq(lions.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 0, "the lent mana went back")
	assert_null(g.undo_log, "and the journal is closed")
