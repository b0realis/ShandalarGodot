extends GameTest
## THE WHOLE-GAME CAMPAIGN, fix-ai-c — the mistake model's two exemptions
## ([member AiProfile.mistake_chance], docs/ai-difficulty.md §1; gated by
## [member AiProfile.forecasts_tactics]):
##  * w6-6 a main-phase fumble is never rolled into mana already tapped —
##    a cast held while a tap trigger (City of Brass) resolved, a Dark
##    Ritual's three black — because that fumble is the pool burning at the
##    step's end, not a turn that "just stops developing";
##  * w6-14 an attack fumble never drops a LETHAL attack or a body that is
##    gone at end of turn anyway (Ball Lightning), and a block fumble never
##    drops the block that keeps us alive.
## The mistakes themselves stay: every exemption has a control in which
## the same profile still fumbles. Each with a null arm (the gate off) and
## a hidden-information permutation.


func _profile(mistakes := 1.0, on := true) -> AiProfile:
	var p := AiProfile.apprentice()
	p.mistake_chance = mistakes
	p.forecasts_tactics = on
	return p


func _ai(seat: int, p: AiProfile) -> AiPlayer:
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _burn_counter(seat: int) -> Array:
	var burned := [0]
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.MANA_BURN and int(e.data.get("player", -1)) == seat:
			burned[0] += int(e.data.get("amount", 0)))
	return burned


# ------------------------------------------------- w6-6: the tapped mana --

func test_a_fumble_is_not_rolled_into_floating_mana() -> void:
	# The pool as a resolved Dark Ritual leaves it: three black, and a
	# Hypnotic Specter it pays for. Every roll fumbles (mistake 1.0).
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai(0, _profile())
	var specter := give_hand(0, "Hypnotic Specter")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	var did := ai.act(g)
	assert_string_contains(did, "Hypnotic Specter", "the floating BBB is spent, not fumbled")
	resolve_stack()
	assert_eq(specter.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_with_no_mana_tapped_the_apprentice_still_fumbles() -> void:
	var ai := _ai(0, _profile())
	for k in 3: put_battlefield(0, "Swamp")
	var specter := give_hand(0, "Hypnotic Specter")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "nothing floats: the mistake model is kept")
	assert_eq(specter.zone, Mtg.Zone.HAND)


func test_null_arm_fumbles_into_the_floating_mana() -> void:
	g.rules.set_preset("modern_mana_burn")
	var ai := _ai(0, _profile(1.0, false))
	var specter := give_hand(0, "Hypnotic Specter")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_eq(ai.act(g), "pass", "gate off: the old roll fumbles whatever floats")
	assert_eq(specter.zone, Mtg.Zone.HAND)


## The probe's own duel shape at the shipped Apprentice rate: a City of
## Brass ping fills the stack while the Bears are paid for, the cast is
## held, and the retry is never fumbled into a mana burn.
## Since the fix-engine handover (w7-5) the cast is ANNOUNCED before the
## City of Brass is tapped, so its ping goes on the stack above the Bears
## and the cast is never held at all; whichever way a seed goes, nothing
## the Apprentice tapped is burned.
func test_the_city_of_brass_cast_is_never_burned() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		var holds := 0
		var casts := 0
		var burns: Array = []
		for s in 30:
			var r := _held_cast(1000 + s, preset)
			if r["held"]:
				holds += 1
			if r["cast"]:
				casts += 1
			if int(r["burned"]) > 0:
				burns.append(1000 + s)
		assert_gt(casts, 0, "%s: the Bears are cast" % preset)
		assert_eq(holds, 0, "%s: announced first, the cast is never held on the ping" % preset)
		assert_eq(burns, [], "%s: nothing tapped is burned" % preset)


func test_the_city_of_brass_ping_goes_above_the_announced_spell() -> void:
	var p := AiProfile.wizard()
	p.develops_late = false
	var ai := _ai(0, p)
	put_battlefield(0, "City of Brass")
	put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Grizzly Bears")
	assert_eq(g.stack.size(), 2, "the spell and the City's trigger")
	assert_eq(g.stack[0].card, bears, "the Bears at the bottom")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 19)


func _held_cast(seed_value: int, preset: String) -> Dictionary:
	var game := MtgGame.new()
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	game.setup(filler, filler, "P0", "P1", 20, 20, seed_value)
	game.start(0)
	game.rules.set_preset(preset)
	var ai := AiPlayer.new(0, AiProfile.apprentice())
	game.set_agent(0, ai)
	for card_name in ["City of Brass", "Forest"]:
		var land := CardInstance.new(CardRegistry.get_card(card_name), game._next_instance_id, 0)
		game._next_instance_id += 1
		game._instances[land.id] = land
		game._put_on_battlefield(land, 0)
		land.summoning_sick = false
	var bears := CardInstance.new(CardRegistry.get_card("Grizzly Bears"), game._next_instance_id, 0)
	game._next_instance_id += 1
	game._instances[bears.id] = bears
	bears.zone = Mtg.Zone.HAND
	game.players[0].hand.append(bears)
	var p1 := AiPlayer.new(1, AiProfile.apprentice())
	game.set_agent(1, p1)
	var guard := 0
	while game.current_step() != Mtg.Step.MAIN1 and guard < 50:
		game.pass_priority(game.priority_player)
		guard += 1
	var held := false
	var burned := [0]
	game.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.MANA_BURN and int(e.data.get("player", -1)) == 0:
			burned[0] += int(e.data.get("amount", 0)))
	guard = 0
	while game.turn_number == 1 and game.current_step() == Mtg.Step.MAIN1 \
			and guard < 40 and not game.game_over:
		if game.priority_player == 0:
			if ai.act(game).contains("holds Grizzly Bears"):
				held = true
		elif p1.act(game) == "":
			game.pass_priority(game.priority_player)
		guard += 1
	return {"held": held, "burned": burned[0], "cast": bears.zone != Mtg.Zone.HAND}


## The same exemption at instant speed: the Magician's reaction roll is
## not taken into mana already floating either.
func _their_end_step_with_red_floating(p: AiProfile) -> String:
	var ai := _ai(0, p)
	g.players[1].life = 3
	give_hand(0, "Lightning Bolt")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.END) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	add_mana(0, Mtg.ManaColor.R, 1)
	return ai.act(g)


func test_a_reaction_is_not_fumbled_into_floating_mana() -> void:
	var p := AiProfile.magician()
	p.mistake_chance = 1.0
	var did := _their_end_step_with_red_floating(p)
	assert_string_contains(did, "Lightning Bolt", "the floating R is the Bolt's: three at three life")


func test_null_arm_fumbles_the_reaction_into_floating_mana() -> void:
	var p := AiProfile.magician()
	p.mistake_chance = 1.0
	p.forecasts_tactics = false
	assert_eq(_their_end_step_with_red_floating(p), "pass", "gate off: the old roll")


func test_the_floating_mana_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai(0, _profile())
		give_hand(0, "Hypnotic Specter")
		give_hand(1, "Lightning Bolt" if variant == 0 else "Counterspell")
		if variant == 1: g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		add_mana(0, Mtg.ManaColor.B, 3)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])


# ---------------------------- the 1997 damage step (fix-engine handover) --

class WindowAgent extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


## Fifth rules: their Lightning Bolt at our face opens the prevention step
## (any card in a hand opens it — public information since w4-3). The AI
## (seat 0, every roll a fumble) holds [param card]. Returns
## `[the AI's action, whether game.rng moved]`.
func _bolted_window(card: String) -> Array:
	g.rules.set_edition("fifth")
	var ai := _ai(0, _profile())
	g.set_agent(1, WindowAgent.new())
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, card)
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))
	assert_true(g.awaiting_damage_prevention, "precondition: the step is open")
	assert_eq(g.priority_player, 0)
	var state_before: int = g.rng.state
	var did := ai.act(g)
	return [did, g.rng.state != state_before]


func test_a_window_with_nothing_to_use_is_passed_without_a_roll() -> void:
	var r := _bolted_window("Grizzly Bears")
	assert_eq(r[0], "ends damage prevention")
	assert_false(r[1], "the seeded stream is not spent on a fumble of nothing")


func test_a_window_with_a_prevention_card_still_rolls_its_fumble() -> void:
	var r := _bolted_window("Healing Salve")
	assert_true(r[1], "a window it could use is the mistake model's as before")


# ------------------------------------------- w6-14: the lethal main phase --

func test_the_burn_that_wins_is_never_fumbled() -> void:
	var ai := _ai(0, _profile())
	g.players[1].life = 3
	put_battlefield(0, "Mountain")
	give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Lightning Bolt", "three at three life is the game")
	resolve_stack()
	assert_true(g.game_over)


func test_burn_that_does_not_win_is_still_fumbled() -> void:
	var ai := _ai(0, _profile())
	put_battlefield(0, "Mountain")
	give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "twenty life: the mistake model is kept")


func test_null_arm_fumbles_the_winning_burn() -> void:
	var ai := _ai(0, _profile(1.0, false))
	g.players[1].life = 3
	put_battlefield(0, "Mountain")
	give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "gate off: the old roll")


func test_the_winning_burn_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai(0, _profile())
		g.players[1].life = 3
		put_battlefield(0, "Mountain")
		give_hand(0, "Lightning Bolt")
		give_hand(1, "Healing Salve" if variant == 0 else "Counterspell")
		if variant == 1: g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])


# --------------------------------------------- w6-14: the lethal attack --

func _to_attacks(ai: AiPlayer) -> void:
	var guard := 0
	while not g.awaiting_attackers and guard < 50 and not g.game_over:
		if g.priority_player == 0:
			ai.act(g)
		else:
			g.pass_priority(g.priority_player)
		guard += 1
	assert_true(g.awaiting_attackers)
	ai.act(g)


func test_a_lethal_attack_is_never_fumbled() -> void:
	var ai := _ai(0, _profile())
	g.players[1].life = 4
	var ball := put_battlefield(0, "Ball Lightning", true)   # haste
	_to_attacks(ai)
	assert_true(g.combat.attackers.has(ball.id), "6 trample at 4 life is the game")


func test_a_body_gone_at_end_of_turn_is_never_left_home() -> void:
	# Not lethal (20 life), but Ball Lightning is sacrificed at the end
	# step whether it attacks or not: staying home throws the card away.
	var ai := _ai(0, _profile())
	var ball := put_battlefield(0, "Ball Lightning", true)
	_to_attacks(ai)
	assert_true(g.combat.attackers.has(ball.id))


func test_an_ordinary_attack_is_still_fumbled() -> void:
	var ai := _ai(0, _profile())
	var bears := put_battlefield(0, "Grizzly Bears")
	_to_attacks(ai)
	assert_false(g.combat.attackers.has(bears.id), "the mistake model is kept for a plain swing")


func test_null_arm_fumbles_the_lethal_attack() -> void:
	var ai := _ai(0, _profile(1.0, false))
	g.players[1].life = 4
	var ball := put_battlefield(0, "Ball Lightning", true)
	_to_attacks(ai)
	assert_false(g.combat.attackers.has(ball.id), "gate off: the old fumble")


func test_the_lethal_attack_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai(0, _profile())
		g.players[1].life = 4
		var ball := put_battlefield(0, "Ball Lightning", true)
		give_hand(1, "Fog" if variant == 0 else "Lightning Bolt")
		if variant == 1: g.players[1].library.reverse()
		_to_attacks(ai)
		answers.append(g.combat.attackers.has(ball.id))
	assert_eq(answers[0], answers[1])


# ---------------------------------------------- w6-14: the lethal block --

func _their_attack(attacker_ids: Array) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	advance_to_next_turn()   # their turn (seat 1 active)
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, attacker_ids))
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_blockers)


func test_the_block_that_keeps_us_alive_is_never_fumbled() -> void:
	var ai := _ai(0, _profile())
	g.players[0].life = 4
	var wall := put_battlefield(0, "Wall of Stone")
	var wurm := put_battlefield(1, "Craw Wurm")
	_their_attack([wurm.id])
	ai.act(g)
	assert_true(g.combat.blocks.has(wall.id), "six through at four life: the wall blocks")


func test_a_block_we_survive_without_is_still_fumbled() -> void:
	var ai := _ai(0, _profile())
	var wall := put_battlefield(0, "Wall of Stone")
	var wurm := put_battlefield(1, "Craw Wurm")
	_their_attack([wurm.id])
	ai.act(g)
	assert_false(g.combat.blocks.has(wall.id), "twenty life: the mistake model is kept")


func test_null_arm_fumbles_the_lethal_block() -> void:
	var ai := _ai(0, _profile(1.0, false))
	g.players[0].life = 4
	var wall := put_battlefield(0, "Wall of Stone")
	var wurm := put_battlefield(1, "Craw Wurm")
	_their_attack([wurm.id])
	ai.act(g)
	assert_false(g.combat.blocks.has(wall.id), "gate off: the old fumble")
