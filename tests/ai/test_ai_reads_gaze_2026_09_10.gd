extends GameTest
## THE THREE READS THE COMBAT MATHS NEVER MADE (2026-09-10, [member
## AiProfile.reads_gaze]; `docs/forge/combat.md` P3).
##
## Every kill this AI predicts goes through [method AiPlayer._dies_to],
## and that predicate was power against toughness and nothing else. Three
## printed shapes in this pool settle a combat some other way, and all
## three were reproduced before a line was written:
##
##  * THE GAZE. `_dies_to(Craw Wurm, Cockatrice) = false`, `_attack_risk
##    = 0.0`, `declared 1 attacker(s)` — a 6/4 walks into a 2/4 that
##    destroys it at end of combat and the seat reads the swing as free.
##    From the other seat the same blindness keeps our OWN Cockatrice at
##    home: `declared 0 block(s)`, six to the face, when the 2/4 in front
##    of the Wurm is a trade the ladder would take.
##  * RAMPAGE (CR 702.23). Two Grizzly Bears gang a Craw Giant on
##    `2 + 2 >= 4` and meet an 8/6: `Bears GRAVEYARD/GRAVEYARD, Craw
##    Giant BATTLEFIELD, our life 16`. The crack-back model said the same
##    thing in its own words — `resolve_block([0,1]) = [true, 3, 2]`,
##    the attacker dead and two through, where the truth is alive and
##    four.
##  * THE EXECUTIONER. `_attack_risk(Hypnotic Specter) = -1.0` — nothing
##    over there may block a flier — and the 1/1 Royal Assassin beside
##    three untapped Swamps took it during the declaration: `Hypnotic
##    Specter GRAVEYARD, their life 20`.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_gaze = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.reads_gaze = false
	return profile


func _blockers(seat: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[seat].battlefield:
		if inst.is_creature() and not inst.tapped:
			out.append(inst)
	return out


## Walk priority from our first main phase to OUR attack declaration.
func _reach_attackers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_attackers and not g.game_over and guard < 40:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_attackers, "reached the declaration")


## Hand the turn to seat 1 and walk it to its declare-attackers.
func _their_turn() -> void:
	var guard := 0
	while (not g.awaiting_attackers or g.active_player != 1) \
			and not g.game_over and guard < 200:
		if g.awaiting_attackers:
			assert_ok(g.declare_attackers(g.active_player, []))
		elif g.awaiting_blockers:
			assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {}))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_attackers, "reached their declaration")


func _reach_blockers(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_blockers and not g.game_over and guard < 60:
		if g.priority_player == 0:
			ai.act(g)
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_true(g.awaiting_blockers, "reached the block declaration")


## Both seats act until the combat phase is behind us — the gaze resolves
## at end of combat, so nothing short of that proves it.
func _play_out_combat(ai: AiPlayer, foe: AiPlayer) -> void:
	var guard := 0
	while not g.game_over and g.current_step() <= Mtg.Step.COMBAT_END \
			and guard < 120:
		var mine := ai.act(g)
		var theirs := foe.act(g)
		if mine == "" and theirs == "":
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1


# ------------------------------------------------------------- the gaze --

func test_the_wurm_does_not_walk_into_a_cockatrice() -> void:
	var ai := _ai(_on())
	var wurm := put_battlefield(0, "Craw Wurm")
	var cock := put_battlefield(1, "Cockatrice")
	assert_true(ai._dies_to(g, wurm, cock), "the gaze kills it whatever the numbers say")
	assert_almost_eq(ai._attack_risk(g, wurm, _blockers(1), 1), 2.5, 0.01,
		"a trade down, not a free swing")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	assert_eq(g.players[1].life, 20, "and nothing landed")


func test_off_the_wurm_walks_into_it() -> void:
	# The malfunction as it stood, so the null is the pilot as it was.
	var ai := _ai(_off())
	var wurm := put_battlefield(0, "Craw Wurm")
	var cock := put_battlefield(1, "Cockatrice")
	assert_false(ai._dies_to(g, wurm, cock), "power against toughness and nothing else")
	assert_almost_eq(ai._attack_risk(g, wurm, _blockers(1), 1), 0.0, 0.01,
		"read as a free swing")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")


func test_our_cockatrice_steps_in_front_of_the_wurm() -> void:
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var cock := put_battlefield(0, "Cockatrice")
	var wurm := put_battlefield(1, "Craw Wurm")
	_their_turn()
	assert_ok(g.declare_attackers(1, [wurm.id]))
	_reach_blockers(ai)
	assert_string_contains(ai.act(g), "declared 1 block")
	_play_out_combat(ai, foe)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "the gaze took the Wurm")
	assert_eq(g.players[0].life, 20, "and nothing got through")


func test_off_our_cockatrice_watches_the_wurm_go_by() -> void:
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var cock := put_battlefield(0, "Cockatrice")
	var wurm := put_battlefield(1, "Craw Wurm")
	_their_turn()
	assert_ok(g.declare_attackers(1, [wurm.id]))
	_reach_blockers(ai)
	assert_string_contains(ai.act(g), "declared 0 block")
	_play_out_combat(ai, foe)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "nothing was traded")
	assert_eq(g.players[0].life, 14, "and six landed on us")


func test_the_triggers_own_rider_answers_for_itself() -> void:
	# Cockatrice's line spares a WALL, and the reading never says so: the
	# trigger's own condition is put to a probe event (CR 603.4), so the
	# card answers the question it printed.
	var ai := _ai(_on())
	var cock := put_battlefield(0, "Cockatrice")
	var wall := put_battlefield(1, "Wall of Stone")
	assert_false(ai._gaze_kills(g, cock, wall), "a Wall is no meal for the gaze")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_true(ai._gaze_kills(g, cock, bears), "a non-Wall is")


func test_the_gaze_is_a_destruction_and_a_shield_answers_it() -> void:
	var ai := _ai(_on())
	var cock := put_battlefield(0, "Cockatrice")
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	put_battlefield(1, "Swamp")
	assert_true(ai._gaze_kills(g, cock, skeletons), "the line names it")
	assert_false(ai._dies_to(g, skeletons, cock),
		"but a regeneration shield in reach is the same answer it always was")


func test_a_creature_with_no_trigger_at_all_is_untouched() -> void:
	# The empty-trigger bail is what keeps this off the cost of the
	# crack-back matrix; it is also the whole pool.
	var ai := _ai(_on())
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	assert_false(ai._gaze_kills(g, bears, wurm))
	assert_false(ai._gaze_kills(g, wurm, bears))


# ------------------------------------------------------------- rampage --

func test_the_gang_is_priced_at_the_size_it_will_meet() -> void:
	var ai := _ai(_on())
	var b1 := put_battlefield(0, "Grizzly Bears")
	var b2 := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Craw Giant")
	assert_eq(giant.cur_rampage, 2, "rampage 2: two blockers make it an 8/6")
	var band: Array[CardInstance] = [b1, b2]
	assert_false(ai._band_kills(g, giant, band), "four damage against a toughness of six")
	var used: Array[int] = []
	assert_eq(ai._best_block_for(g, giant, band, used, false).size(), 0,
		"so the gang is not declared")


func test_off_the_gang_is_declared_and_dies_for_nothing() -> void:
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var b1 := put_battlefield(0, "Grizzly Bears")
	var b2 := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Craw Giant")
	var band: Array[CardInstance] = [b1, b2]
	assert_true(ai._band_kills(g, giant, band), "four damage against a toughness of four")
	_their_turn()
	assert_ok(g.declare_attackers(1, [giant.id]))
	_reach_blockers(ai)
	assert_string_contains(ai.act(g), "declared 2 block")
	_play_out_combat(ai, foe)
	assert_eq(b1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b2.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "and it walked away")
	assert_eq(g.players[0].life, 16, "with four trampling through")


func test_a_gang_of_one_is_the_number_it_always_was() -> void:
	# What pins this to the engine's own predicate: rampage is zero for a
	# single blocker, so [method AiPlayer._band_kills] IS [method
	# AiPlayer._dies_to] there, on both arms.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var wurm := put_battlefield(0, "Craw Wurm")
		var giant := put_battlefield(1, "Craw Giant")
		var band: Array[CardInstance] = [wurm]
		assert_eq(ai._band_kills(g, giant, band), ai._dies_to(g, giant, wurm),
			"one blocker: the band predicate and the pair predicate agree")


func test_the_crack_back_model_carries_the_rampage() -> void:
	var ai := _ai(_on())
	var b1 := put_battlefield(0, "Grizzly Bears")
	var b2 := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Craw Giant")
	var mine: Array[CardInstance] = [b1, b2]
	var theirs: Array[CardInstance] = [giant]
	var model := ai._build_combat_model(g, mine, theirs, mine, 1)
	assert_eq(model.d_rampage[0], 2, "the model carries the printed number")
	var out := model.resolve_block(0, [0, 1], false)
	assert_false(bool(out[0]), "the 8/6 lives")
	assert_eq(int(out[2]), 4, "and four trample through")


func test_off_the_crack_back_model_carries_none() -> void:
	var ai := _ai(_off())
	var b1 := put_battlefield(0, "Grizzly Bears")
	var b2 := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Craw Giant")
	var mine: Array[CardInstance] = [b1, b2]
	var theirs: Array[CardInstance] = [giant]
	var model := ai._build_combat_model(g, mine, theirs, mine, 1)
	assert_eq(model.d_rampage[0], 0, "zero at the null, so the search is unmoved")
	var out := model.resolve_block(0, [0, 1], false)
	assert_true(bool(out[0]), "the model kills a body that lives")
	assert_eq(int(out[2]), 2)


# -------------------------------------------------------- the executioner --

func test_the_specter_stays_home_in_front_of_an_assassin() -> void:
	var ai := _ai(_on())
	var foe := _ai(AiProfile.wizard(), 1)
	var spec := put_battlefield(0, "Hypnotic Specter")
	put_battlefield(1, "Royal Assassin")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	assert_almost_eq(ai._attack_risk(g, spec, _blockers(1), 1), 5.5, 0.01,
		"the body's whole worth, because that is what the {T} takes")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	_play_out_combat(ai, foe)
	assert_eq(spec.zone, Mtg.Zone.BATTLEFIELD, "and it is still ours")


func test_off_the_specter_taps_into_it() -> void:
	var ai := _ai(_off())
	var foe := _ai(AiProfile.wizard(), 1)
	var spec := put_battlefield(0, "Hypnotic Specter")
	put_battlefield(1, "Royal Assassin")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	assert_almost_eq(ai._attack_risk(g, spec, _blockers(1), 1), -1.0, 0.01,
		"nothing over there may block a flier, and that was the whole reading")
	_reach_attackers(ai)
	assert_string_contains(ai.act(g), "declared 1 attacker")
	_play_out_combat(ai, foe)
	assert_eq(spec.zone, Mtg.Zone.GRAVEYARD, "executed at the declaration")
	assert_eq(g.players[1].life, 20, "and nothing landed")


func test_vigilance_is_outside_the_reading() -> void:
	# A Serra Angel does not tap to attack, so the {T} never gets its
	# target: the reading is silent on both arms.
	for on in [true, false]:
		before_each()
		var ai := _ai(_on() if on else _off())
		var serra := put_battlefield(0, "Serra Angel")
		put_battlefield(1, "Royal Assassin")
		put_battlefield(1, "Swamp")
		put_battlefield(1, "Swamp")
		put_battlefield(1, "Swamp")
		assert_false(ai._taps_into_execution(g, serra, 1))
		assert_almost_eq(ai._attack_risk(g, serra, _blockers(1), 1), -1.0, 0.01)


func test_a_tapped_assassin_is_no_reason_to_stay_home() -> void:
	# The {T} is the WHOLE cost of this one — the {1}{B}{B} is what it
	# cost to cast — so the mana gate has nothing to refuse here and the
	# board state is the whole of it.
	var ai := _ai(_on())
	var spec := put_battlefield(0, "Hypnotic Specter")
	var assassin := put_battlefield(1, "Royal Assassin")
	assert_true(ai._taps_into_execution(g, spec, 1), "untapped, and the {T} is free")
	assassin.tapped = true
	g.recalculate()
	assert_false(ai._taps_into_execution(g, spec, 1), "a tapped assassin has no {T}")


func test_a_summoning_sick_assassin_cannot_execute_yet() -> void:
	var ai := _ai(_on())
	var spec := put_battlefield(0, "Hypnotic Specter")
	put_battlefield(1, "Royal Assassin", true)
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	assert_false(ai._taps_into_execution(g, spec, 1), "CR 302.6: no {T} on its first turn")


func test_protection_from_the_executioner_is_no_risk_at_all() -> void:
	var ai := _ai(_on())
	var knight := put_battlefield(0, "White Knight")
	put_battlefield(1, "Royal Assassin")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	assert_false(ai._taps_into_execution(g, knight, 1), "protection from black")


func test_a_line_that_can_take_the_body_standing_still_is_not_this_read() -> void:
	# Tetsuo Umezawa's "target tapped or blocking creature" carries no
	# filter in this engine, so it may already aim at our body: the attack
	# is not what buys them the kill and the body is no more at home than
	# it is swinging.
	var ai := _ai(_on())
	var spec := put_battlefield(0, "Hypnotic Specter")
	put_battlefield(1, "Tetsuo Umezawa")
	for _i in 4:
		put_battlefield(1, "Swamp")
	assert_false(ai._taps_into_execution(g, spec, 1))


# --------------------------------------------------------------- the ladder --

func test_the_ladder_reads_from_sorcerer_up() -> void:
	assert_false(AiProfile.apprentice().reads_gaze)
	assert_false(AiProfile.magician().reads_gaze)
	assert_true(AiProfile.sorcerer().reads_gaze)
	assert_true(AiProfile.wizard().reads_gaze)


func test_the_knob_reads_from_the_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("reads_gaze=off"), "")
	assert_false(profile.reads_gaze)
	assert_eq(profile.apply_overrides("reads_gaze=on"), "")
	assert_true(profile.reads_gaze)
