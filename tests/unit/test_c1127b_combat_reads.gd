extends GameTest
## PLAYER REPORT 2026-11-26, the computer's combat (engine/ai/combat_reads.gd):
##  1. a body gone at end of turn anyway (Ball Lightning's printed line, a
##     body on the engine's end-step doom list) attacks whatever is across
##     the table, and its death is priced at nothing on both sides; a body
##     back in hand at end of turn (Viashino Sandstalker) attacks unless a
##     blocker stops it cold; neither is cast after combat or into a
##     blocker that stops it cold;
##  2. a trampler's spill: when the swing is lethal, the block ladder's
##     answer is the block that keeps the pilot alive.
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


## Our attack declaration on this board: the names sent.
func _attack(p: AiProfile, ours: Array, theirs: Array, doom := false) -> Array:
	before_each()
	var ai := _ai(p)
	for n in theirs: put_battlefield(1, n)
	for n in ours:
		var body := put_battlefield(0, n)
		if doom: g.doom_at_next_end_step(body, false, false, true, 0)
	var guard := 0
	while not g.awaiting_attackers and guard < 50 and not g.game_over:
		if g.priority_player == 0: ai.act(g)
		else: g.pass_priority(g.priority_player)
		guard += 1
	assert_true(g.awaiting_attackers)
	ai.act(g)
	return _names(g.combat.attackers.keys())


## Our whole turn from [param step] with [param card] in hand and three
## Mountains: what was cast, and what attacked.
func _turn(p: AiProfile, card: String, theirs: Array, step: int) -> Dictionary:
	before_each()
	var ai := _ai(p)
	for i in 3: put_battlefield(0, "Mountain")
	for n in theirs: put_battlefield(1, n)
	give_hand(0, card)
	advance_to_step(step)
	var out := {"cast": false, "attacked": false}
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and not g.game_over and guard < 200:
		guard += 1
		if g.awaiting_attackers:
			ai.act(g)
			out["attacked"] = _names(g.combat.attackers.keys()).has(card)
		elif g.awaiting_blockers:
			g.declare_blockers(1, {})
		elif g.priority_player == 0:
			var line := ai.act(g)
			if line.begins_with("cast " + card): out["cast"] = true
			if line == "": g.pass_priority(0)
		else:
			g.pass_priority(g.priority_player)
	return out


## Our blocks against [param theirs] attacking at [param life]: "blocker>attacker".
func _blocks(p: AiProfile, ours: Array, theirs: Array, life: int) -> Array:
	before_each()
	var ai := _ai(p)
	g.players[0].life = life
	for n in ours: put_battlefield(0, n)
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var ids: Array = []
	for n in theirs: ids.append(put_battlefield(1, n).id)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, ids))
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_true(g.awaiting_blockers)
	ai.act(g)
	var out: Array = []
	for b in g.combat.blocks:
		out.append("%s>%s" % [g.find_instance(b).data.card_name,
			g.find_instance(int(g.combat.blocks[b])).data.card_name])
	out.sort()
	return out


func _names(ids: Array) -> Array:
	var out: Array = []
	for id in ids: out.append(g.find_instance(id).data.card_name)
	return out


# ------------------------------------------- 1. gone at end of turn anyway --

func test_the_reading_is_the_printed_line() -> void:
	assert_eq(COMBAT_READS.printed_fleeting(CardRegistry.get_card("Ball Lightning")), COMBAT_READS.LOST)
	assert_eq(COMBAT_READS.printed_fleeting(CardRegistry.get_card("Viashino Sandstalker")), COMBAT_READS.RETURNED)
	assert_eq(COMBAT_READS.printed_fleeting(CardRegistry.get_card("Viashino Cutthroat")), COMBAT_READS.RETURNED)
	assert_eq(COMBAT_READS.printed_fleeting(CardRegistry.get_card("Viashino Sandscout")), COMBAT_READS.RETURNED)
	assert_eq(COMBAT_READS.printed_fleeting(CardRegistry.get_card("Grizzly Bears")), COMBAT_READS.STAYS)
	assert_eq(COMBAT_READS.printed_fleeting(CardRegistry.get_card("Pestilence")), COMBAT_READS.STAYS)
	var giant := put_battlefield(0, "Hill Giant")
	assert_eq(COMBAT_READS.fleeting(g, giant), COMBAT_READS.STAYS)
	g.doom_at_next_end_step(giant, true)   # Berserk: only if it attacked
	assert_eq(COMBAT_READS.fleeting(g, giant), COMBAT_READS.STAYS, "a conditional doom is a decision")
	var other := put_battlefield(0, "Hill Giant")
	g.doom_at_next_end_step(other, false, false, true, 0)
	assert_eq(COMBAT_READS.fleeting(g, other), COMBAT_READS.LOST)


func test_a_body_sacrificed_at_end_of_turn_attacks_into_a_first_striker() -> void:
	# Tundra Wolves kill a 6/1 before it deals anything: the old pilot kept
	# the Ball Lightning home and sacrificed it there.
	for p in _rungs():
		assert_eq(_attack(p, ["Ball Lightning"], ["Tundra Wolves"]), ["Ball Lightning"], p.profile_name)
	assert_eq(_attack(_null(), ["Ball Lightning"], ["Tundra Wolves"]), [], "gate off")


func test_a_body_condemned_for_the_end_step_attacks_into_anything() -> void:
	# The engine's own doom list (Sneak Attack's creature): a Hill Giant
	# that is sacrificed tonight loses nothing to a Craw Wurm.
	for p in _rungs():
		assert_eq(_attack(p, ["Hill Giant"], ["Craw Wurm"], true), ["Hill Giant"], p.profile_name)
	assert_eq(_attack(AiProfile.wizard(), ["Hill Giant"], ["Craw Wurm"]), [], "control: an ordinary Giant stays home")
	assert_eq(_attack(_null(), ["Hill Giant"], ["Craw Wurm"], true), [], "gate off")


func test_a_body_returned_at_end_of_turn_attacks_unless_stopped_cold() -> void:
	for p in _rungs():
		assert_eq(_attack(p, ["Viashino Sandstalker"], ["Grizzly Bears"]), ["Viashino Sandstalker"],
			"%s: a trade or four damage, and it blocks nothing at home" % p.profile_name)
	assert_eq(_attack(AiProfile.wizard(), ["Viashino Sandstalker"], ["Wall of Swords"]), [],
		"the card is kept: it does not walk into a 3/5")
	assert_eq(_attack(_null(), ["Viashino Sandstalker"], ["Grizzly Bears"]), [], "gate off")


func test_it_is_cast_before_combat_and_attacks() -> void:
	for p in _rungs():
		for theirs in [[], ["Grizzly Bears"]]:
			for card in ["Ball Lightning", "Viashino Sandstalker"]:
				var did := _turn(p, card, theirs, Mtg.Step.MAIN1)
				assert_true(did["cast"] and did["attacked"], "%s %s into %s: %s" % [p.profile_name, card, theirs, did])


func test_it_is_not_cast_after_combat() -> void:
	for p in _rungs():
		for card in ["Ball Lightning", "Viashino Sandstalker"]:
			assert_false(_turn(p, card, [], Mtg.Step.MAIN2)["cast"], "%s %s" % [p.profile_name, card])
	assert_true(_turn(_null(), "Ball Lightning", [], Mtg.Step.MAIN2)["cast"], "gate off: three mana for nothing")


func test_it_is_not_cast_into_a_blocker_that_stops_it_cold() -> void:
	for p in _rungs():
		assert_false(_turn(p, "Ball Lightning", ["Wall of Stone"], Mtg.Step.MAIN1)["cast"], p.profile_name + " wall")
		assert_false(_turn(p, "Ball Lightning", ["Tundra Wolves"], Mtg.Step.MAIN1)["cast"], p.profile_name + " first strike")
		assert_false(_turn(p, "Viashino Sandstalker", ["Wall of Stone"], Mtg.Step.MAIN1)["cast"], p.profile_name + " stalker")
	assert_true(_turn(_null(), "Ball Lightning", ["Wall of Stone"], Mtg.Step.MAIN1)["cast"], "gate off")
	# A tapped wall stops nothing.
	before_each()
	var ai := _ai(AiProfile.wizard())
	put_battlefield(1, "Wall of Stone").tapped = true
	var ball := give_hand(0, "Ball Lightning")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(COMBAT_READS.cast_refusal(g, ai, ball), "")


func test_killing_their_doomed_attacker_is_worth_nothing() -> void:
	# Their Ball Lightning dies tonight whatever we do: a Hill Giant in its
	# way is a Giant spent for three life, not a trade.
	for p in _rungs():
		assert_eq(_blocks(p, ["Hill Giant"], ["Ball Lightning"], 20), [], p.profile_name)
		assert_eq(_blocks(p, ["Hill Giant"], ["Ball Lightning"], 6), ["Hill Giant>Ball Lightning"],
			"%s: six at six life is the game" % p.profile_name)
		assert_eq(_blocks(p, ["Tundra Wolves"], ["Ball Lightning"], 20), ["Tundra Wolves>Ball Lightning"],
			"%s: the free block is still taken" % p.profile_name)
	assert_eq(_blocks(_null(), ["Hill Giant"], ["Ball Lightning"], 20), ["Hill Giant>Ball Lightning"], "gate off")


# ------------------------------------------------- 2. the trampler's spill --

func test_a_chump_against_a_trampler_is_not_made_at_twenty_life() -> void:
	for p in _rungs():
		assert_eq(_blocks(p, ["Scryb Sprites"], ["Force of Nature"], 20), [], p.profile_name)


func test_the_lethal_trample_is_met_by_the_block_that_survives_it() -> void:
	# Eight trampling at six life: one 1/1 stops one (dead); the 1/1 and the
	# 2/2 together stop three (alive at one).
	for p in _rungs():
		assert_eq(_blocks(p, ["Scryb Sprites", "Grizzly Bears"], ["Force of Nature"], 6),
			["Grizzly Bears>Force of Nature", "Scryb Sprites>Force of Nature"], p.profile_name)
		assert_false(g.game_over)
	assert_eq(_blocks(_null(AiProfile.apprentice()), ["Scryb Sprites", "Grizzly Bears"], ["Force of Nature"], 6),
		["Scryb Sprites>Force of Nature"], "gate off: the cheapest chump, and dead")


func test_the_wall_holds_the_trampler_and_the_chump_stays_home() -> void:
	# Eight trampling at one life: the 0/8 soaks all of it; the 1/1 the
	# ladder threw in front soaks one and loses the game.
	for p in _rungs():
		assert_eq(_blocks(p, ["Wall of Stone", "Scryb Sprites"], ["Force of Nature"], 1),
			["Wall of Stone>Force of Nature"], p.profile_name)
	assert_eq(_blocks(_null(AiProfile.apprentice()), ["Wall of Stone", "Scryb Sprites"], ["Force of Nature"], 1),
		["Scryb Sprites>Force of Nature"], "gate off")


func test_when_no_block_survives_the_ladder_answer_stands() -> void:
	var on := _blocks(_rungs()[0], ["Scryb Sprites"], ["Force of Nature"], 2)
	var off := _blocks(_null(AiProfile.apprentice()), ["Scryb Sprites"], ["Force of Nature"], 2)
	assert_eq(on, off)


func test_a_non_trampler_is_blocked_as_before() -> void:
	for p in _rungs():
		assert_eq(_blocks(p, ["Scryb Sprites", "Grizzly Bears"], ["Craw Wurm"], 6).size(), 1, p.profile_name)


func test_our_trampler_counts_its_spill_for_the_lethal_push() -> void:
	for p in _rungs():
		var names := _attack(p, ["Force of Nature"], ["Grizzly Bears", "Grizzly Bears"])
		assert_eq(names, ["Force of Nature"], p.profile_name)
