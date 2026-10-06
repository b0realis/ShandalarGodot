extends GameTest
## SHADOW, READ BY THE FAIR AI (Pack 9, engine package E1; CR 702.28,
## 506.4; [member AiProfile.forecasts_tactics]; engine/ai/tempest_tactics.gd).
##
## The valuation and the attack/block planners already read shadow through
## the engine's block legality (tests/unit/test_pack_9_engine_E1_shadow_ai.gd).
## What this file pins is the deck study's evasion tag and the TRICKS:
##  * a shadow GRANT on a target (Dauthi Embrace, Shadow Rift) is cast on our
##    attacker after attackers are declared and before blocks, when their
##    untapped creatures would stop it — and never after blocks, when the
##    keyword changes nothing (CR 506.4); the spell is held out of the main
##    phase for that moment;
##  * a shadow LOSS (Reality Anchor) is cast on THEIR shade before blocks
##    when our blocker then kills it.
## The null arm (gate off) does neither; the opponent's hidden hand and
## library do not move the decision.


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


## Seat 0 declares [param ids] and holds priority in its declare-attackers
## step, before blocks.
func _we_attack(ids: Array) -> void:
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var guard := 0
	while not g.awaiting_attackers and guard < 50:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_attackers(0, ids))
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.priority_player, 0)


## Seat 1 attacks with [param ids]; seat 0 then holds priority before blocks.
func _they_attack(ids: Array) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, ids))
	guard = 0
	while g.priority_player != 0 and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)


## Our Hill Giant against their Wall of Stone, with Dauthi Embrace and two
## Swamps.
func _embrace_board() -> CardInstance:
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Dauthi Embrace")
	for _i in 2: put_battlefield(0, "Swamp")
	put_battlefield(1, "Wall of Stone")
	return giant


# --------------------------------------------------------- the deck study --

func test_a_shade_is_evasion_in_the_deck_study() -> void:
	assert_true(AiDeckStudy.classify(CardRegistry.get_card("Soltari Foot Soldier")).has("evasion"))
	assert_false(AiDeckStudy.classify(CardRegistry.get_card("Grizzly Bears")).has("evasion"))


# ------------------------------------------------------------ the grant --

func test_dauthi_embrace_shadows_the_attacker_their_wall_would_stop() -> void:
	var ai := _ai()
	var giant := _embrace_board()
	_we_attack([giant.id])
	assert_string_contains(ai.act(g), "Hill Giant gains shadow")
	resolve_stack()
	assert_true(giant.has_keyword(Mtg.Keyword.SHADOW))


func test_the_null_arm_keeps_the_embrace() -> void:
	var ai := _ai(false)
	var giant := _embrace_board()
	_we_attack([giant.id])
	assert_eq(ai.act(g), "pass")
	assert_false(giant.has_keyword(Mtg.Keyword.SHADOW))


func test_no_shadow_after_blocks() -> void:
	var ai := _ai()
	var giant := _embrace_board()
	var wall: CardInstance = g.players[1].battlefield[0]
	give_hand(0, "Shadow Rift")
	for _i in 2: put_battlefield(0, "Island")
	_we_attack([giant.id])
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_true(g.awaiting_blockers)
	assert_ok(g.declare_blockers(1, {wall.id: giant.id}))
	var guard := 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	var line := ai.act(g)
	assert_false(line.contains("shadow") or line.contains("Shadow Rift") or line.contains("Dauthi Embrace"),
		"a shadow gained after blocks changes nothing (CR 506.4): %s" % line)


func test_shadow_rift_waits_for_the_attack_then_flies_the_giant_over() -> void:
	var ai := _ai()
	var giant := put_battlefield(0, "Hill Giant")
	for _i in 2: put_battlefield(0, "Island")
	var rift := give_hand(0, "Shadow Rift")
	put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "held out of the main phase")
	assert_eq(rift.zone, Mtg.Zone.HAND)
	_we_attack([giant.id])
	assert_string_contains(ai.act(g), "Shadow Rift")
	resolve_stack()
	assert_true(giant.has_keyword(Mtg.Keyword.SHADOW))


func test_a_giant_nothing_can_block_is_not_shadowed() -> void:
	var ai := _ai()
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Dauthi Embrace")
	for _i in 2: put_battlefield(0, "Swamp")
	put_battlefield(1, "Soltari Foot Soldier")   # a shade cannot block it
	_we_attack([giant.id])
	assert_eq(ai.act(g), "pass")


func test_the_trick_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		var giant := _embrace_board()
		give_hand(1, "Giant Growth" if variant == 0 else "Swords to Plowshares")
		g.players[1].library.reverse()
		_we_attack([giant.id])
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
	assert_string_contains(answers[0], "gains shadow")


# ------------------------------------------------------------- the loss --

func _anchor_board() -> CardInstance:
	put_battlefield(0, "Hill Giant")
	for _i in 2: put_battlefield(0, "Forest")
	give_hand(0, "Reality Anchor")
	return put_battlefield(1, "Dauthi Slayer")   # 2/2 shadow, attacks each turn


func test_reality_anchor_lets_our_giant_block_their_shade() -> void:
	var ai := _ai()
	var slayer := _anchor_board()
	_they_attack([slayer.id])
	assert_string_contains(ai.act(g), "Reality Anchor")
	resolve_stack()
	assert_false(slayer.has_keyword(Mtg.Keyword.SHADOW))


func test_the_null_arm_lets_the_shade_through() -> void:
	var ai := _ai(false)
	var slayer := _anchor_board()
	_they_attack([slayer.id])
	assert_false(ai.act(g).contains("Reality Anchor"))
	assert_true(slayer.has_keyword(Mtg.Keyword.SHADOW))


func test_reality_anchor_is_held_in_our_main_phase() -> void:
	var ai := _ai()
	_anchor_board()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
