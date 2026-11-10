extends GameTest
## Gap review 2026-11-10, r1b-1: the counter answers before every per-set
## special-spell arm of `AiPlayer._respond_action` (Portal / Second Age,
## Alliances, Ice Age, Homelands). Each arm used to run first, so a spell
## it liked spent the mana a Counterspell held for a lethal spell, and the
## pilot died with the counter in hand.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	for id in ["pack-3", "pack-4", "pack-5", "pack-6", "pack-9"]:
		CardPacks.set_enabled(id, true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## Seat 1 attacks with [param attacker] and holds priority in its
## declare-attackers step.
func _their_attack(attacker: CardInstance) -> void:
	_their_main()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.active_player, 1)
	assert_ok(g.declare_attackers(1, [attacker.id]))
	resolve_stack()
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.priority_player, 1)


## Seat 0 (the AI) answers; seat 1 only passes; until the stack is empty.
func _play_out_stack(ai: AiPlayer) -> Array:
	var lines: Array = []
	var guard := 0
	while not g.stack.is_empty() and not g.game_over and guard < 60:
		guard += 1
		if g.priority_player == 0:
			var did := ai.act(g)
			if did != "pass" and did != "":
				lines.append(did)
		else:
			assert_ok(g.pass_priority(1))
	return lines


## THE PORTAL ARM (portal_tactics.gd `special_spell`, Diabolic Edict's
## `opponent_sacrifice_creature`): their Fireball for 20 at our face, we
## hold Counterspell and Diabolic Edict on two Islands and a Swamp. The
## Edict went first and ate an Island; the Counterspell could not be paid.
func test_a_lethal_fireball_is_countered_not_answered_with_an_edict() -> void:
	var ai := _ai(true)
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(0, "Swamp")
	give_hand(0, "Counterspell")
	give_hand(0, "Diabolic Edict")
	put_battlefield(1, "Grizzly Bears")
	_their_main()
	var ball := give_hand(1, "Fireball")
	add_mana(1, Mtg.ManaColor.R, 21)
	assert_ok(g.cast_spell(1, ball, [TargetRef.player(0)], 20))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var lines := _play_out_stack(ai)
	gut.p("Portal arm: AI did %s; our life %d" % [lines, g.players[0].life])
	assert_false(g.game_over, "died to a Fireball it held a Counterspell for: %s" % [lines])
	assert_true(not lines.is_empty() and str(lines[0]).contains("Counterspell"),
		"the counter answers first: %s" % [lines])


## THE ALLIANCES ARM (alliances_tactics.gd `special_spell`, Exile's
## `attacker_exile_life`): their attacking Bears and a Lightning Bolt for
## our last 3 life; Exile ({2}{W}) and Counterspell ({U}{U}) on two Islands
## and a Plains — one of them only.
func test_a_lethal_bolt_is_countered_not_answered_with_exile() -> void:
	var ai := _ai(true)
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(0, "Plains")
	give_hand(0, "Counterspell")
	give_hand(0, "Exile")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.players[0].life = 3
	_their_attack(bears)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var lines := _play_out_stack(ai)
	gut.p("Alliances arm: AI did %s; our life %d" % [lines, g.players[0].life])
	assert_false(g.game_over, "died to a Bolt it held a Counterspell for: %s" % [lines])
	assert_true(not lines.is_empty() and str(lines[0]).contains("Counterspell"),
		"the counter answers first: %s" % [lines])


## THE ICE AGE ARM (ice_age_tactics.gd `respond`, Ray of Command at their
## declare-attackers step): Ray ({3}{U}) and Counterspell on four Islands.
func test_a_lethal_bolt_is_countered_not_answered_with_ray_of_command() -> void:
	var ai := _ai(true)
	for _i in 4: put_battlefield(0, "Island")
	give_hand(0, "Counterspell")
	give_hand(0, "Ray of Command")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.players[0].life = 3
	_their_attack(bears)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var lines := _play_out_stack(ai)
	gut.p("Ice Age arm: AI did %s; our life %d" % [lines, g.players[0].life])
	assert_false(g.game_over, "died to a Bolt it held a Counterspell for: %s" % [lines])
	assert_true(not lines.is_empty() and str(lines[0]).contains("Counterspell"),
		"the counter answers first: %s" % [lines])


## THE HOMELANDS ARM (homelands_tactics.gd `respond`, Broken Visage's
## `attacker_destroy_token`): Broken Visage ({4}{B}) and Counterspell on
## two Islands and three Swamps.
func test_a_lethal_bolt_is_countered_not_answered_with_broken_visage() -> void:
	var ai := _ai(true)
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	for _i in 3: put_battlefield(0, "Swamp")
	give_hand(0, "Counterspell")
	give_hand(0, "Broken Visage")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.players[0].life = 3
	_their_attack(bears)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var lines := _play_out_stack(ai)
	gut.p("Homelands arm: AI did %s; our life %d" % [lines, g.players[0].life])
	assert_false(g.game_over, "died to a Bolt it held a Counterspell for: %s" % [lines])
	assert_true(not lines.is_empty() and str(lines[0]).contains("Counterspell"),
		"the counter answers first: %s" % [lines])


## The arms still answer when no counter is held (the order moved, not
## the arms): Diabolic Edict alone in response to their Fireball.
func test_the_portal_arm_still_answers_without_a_counter() -> void:
	var ai := _ai(true)
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(0, "Swamp")
	give_hand(0, "Diabolic Edict")
	put_battlefield(1, "Grizzly Bears")
	_their_main()
	var ball := give_hand(1, "Fireball")
	add_mana(1, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(1, ball, [TargetRef.player(0)], 2))
	assert_ok(g.pass_priority(1))
	var did := ai.act(g)
	gut.p("Edict alone: AI did '%s'" % did)
	assert_true(did.begins_with("cast Diabolic Edict"), did)


## The gate off: the per-set arms are silent and the counter answers, as
## it always did.
func test_gate_off_counters() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Island")
	put_battlefield(0, "Island")
	put_battlefield(0, "Swamp")
	give_hand(0, "Counterspell")
	give_hand(0, "Diabolic Edict")
	put_battlefield(1, "Grizzly Bears")
	_their_main()
	var ball := give_hand(1, "Fireball")
	add_mana(1, Mtg.ManaColor.R, 21)
	assert_ok(g.cast_spell(1, ball, [TargetRef.player(0)], 20))
	assert_ok(g.pass_priority(1))
	var did := ai.act(g)
	gut.p("gate off: AI did '%s'" % did)
	assert_true(did.contains("Counterspell"), did)


# ------------------------------------------------- the redirect that wins (r1b-1)
# The lead's ruling (2026-11-10): a response that WINS beats one that only
# saves. A redirect that moves a lethal spell onto the opponent and kills
# them (ice_age_tactics.gd `winning_redirect`) runs before the counter;
# every other Ice Age answer stays after it.

func _deflection_board(on: bool, x: int, our_life := 20, hidden := "Forest") -> Array:
	var ai := _ai(on)
	for _i in 4: put_battlefield(0, "Island")
	give_hand(0, "Counterspell")
	give_hand(0, "Deflection")
	put_battlefield(1, "Serra Angel")   # a creature a weaker reading would pick
	g.players[0].life = our_life
	_their_main()
	give_hand(1, hidden)
	var ball := give_hand(1, "Fireball")
	add_mana(1, Mtg.ManaColor.R, x + 1)
	assert_ok(g.cast_spell(1, ball, [TargetRef.player(0)], x))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return _play_out_stack(ai)


func test_a_lethal_fireball_is_redirected_when_the_redirect_wins() -> void:
	var lines := _deflection_board(true, 20)
	gut.p("Fireball 20, redirect: AI did %s; life us %d them %d" % [lines,
		g.players[0].life, g.players[1].life])
	assert_true(not lines.is_empty() and str(lines[0]).contains("Deflection"),
		"the redirect that wins comes before the counter: %s" % [lines])
	assert_true(g.game_over, "the Fireball went to their face")
	assert_lte(g.players[1].life, 0)
	assert_eq(g.players[0].life, 20)


## Fireball 3 at our last 3 life: lethal at us, not at them (20) — the
## counter still comes first.
func test_a_fireball_that_does_not_win_is_still_countered_first() -> void:
	var lines := _deflection_board(true, 3, 3)
	gut.p("Fireball 3: AI did %s; life us %d them %d" % [lines, g.players[0].life, g.players[1].life])
	assert_true(not lines.is_empty() and str(lines[0]).contains("Counterspell"),
		"no win in the redirect: the counter first: %s" % [lines])
	assert_eq(g.players[0].life, 3)
	assert_eq(g.players[1].life, 20)


## What their hand hides does not move the decision.
func test_the_winning_redirect_reads_no_hidden_card() -> void:
	var a := _deflection_board(true, 20, 20, "Forest")
	after_each()
	before_each()
	var b := _deflection_board(true, 20, 20, "Fog")
	assert_eq(a, b, "their hidden card moved the decision")


## The gate off: no winning-redirect reading, and the response order is
## the null arm's own — the Ice Age arm's Deflection (aimed by the old
## ranking) before the counter, as before the gap review.
func test_gate_off_keeps_the_old_order() -> void:
	var lines := _deflection_board(false, 20)
	gut.p("gate off: AI did %s; life us %d them %d" % [lines, g.players[0].life, g.players[1].life])
	assert_true(not lines.is_empty() and str(lines[0]).contains("Deflection"), str(lines))
