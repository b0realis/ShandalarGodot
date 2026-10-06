extends GameTest
## SLIVERS, READ BY THE FAIR AI (Pack 9, card batch B3;
## [member AiProfile.forecasts_tactics]).
##
## A Sliver lord's grant reaches EVERY Sliver, the opponent's too. Keyword
## and P/T grants were always priced (the board reads live values, and
## [AiContextValue] measures a lord against the board without it, both
## seats). A granted ACTIVATED ability was not: [method
## Evaluator.granted_ability_value] now prices it on each creature that has
## it, so Clot Sliver arming our Slivers is worth more than Clot Sliver
## arming theirs. The granted abilities themselves reach the shared
## readers: Acidic Sliver's sacrifice-shot finishes the game, Hibernation
## Sliver's "pay 2 life: return" answers a Bolt. Null arm: the gate off
## prices a grant at nothing, as before.


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


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


func _profile(on: bool) -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = on
	return p


# ------------------------------------------------------------ the value --

func test_a_granted_regeneration_is_worth_a_point() -> void:
	put_battlefield(0, "Clot Sliver")
	var metallic := put_battlefield(0, "Metallic Sliver")
	var on := Evaluator.permanent_value(metallic, _profile(true))
	var off := Evaluator.permanent_value(metallic, _profile(false))
	assert_almost_eq(on - off, Evaluator.GRANTED_MAJOR, 0.001)
	var bare := put_battlefield(1, "Grizzly Bears")
	assert_eq(Evaluator.permanent_value(bare, _profile(true)),
		Evaluator.permanent_value(bare, _profile(false)), "no grant, no change")


func test_a_lord_arming_their_slivers_is_worth_less_than_one_arming_ours() -> void:
	var ours := put_battlefield(0, "Clot Sliver")
	for _i in 2: put_battlefield(0, "Metallic Sliver")
	var with_ours := AiContextValue.of(g, ours, _profile(true))
	before_each()
	var lone := put_battlefield(0, "Clot Sliver")
	for _i in 2: put_battlefield(1, "Metallic Sliver")
	var with_theirs := AiContextValue.of(g, lone, _profile(true))
	assert_gt(with_ours, with_theirs, "the grant on our Slivers is ours; on theirs, theirs")


func test_the_null_arm_prices_a_grant_at_nothing() -> void:
	var ours := put_battlefield(0, "Clot Sliver")
	for _i in 2: put_battlefield(0, "Metallic Sliver")
	var with_ours := AiContextValue.of(g, ours, _profile(false))
	before_each()
	var lone := put_battlefield(0, "Clot Sliver")
	for _i in 2: put_battlefield(1, "Metallic Sliver")
	assert_almost_eq(AiContextValue.of(g, lone, _profile(false)), with_ours, 0.001)


# ------------------------------------------------------- the abilities --

func test_acidic_sliver_finishes_the_game() -> void:
	var ai := _ai()
	put_battlefield(0, "Acidic Sliver")
	for _i in 2: put_battlefield(0, "Mountain")
	g.players[1].life = 2
	assert_string_contains(ai.act(g), "Acidic Sliver")
	resolve_stack()
	assert_true(g.game_over or g.players[1].life <= 0)


func test_hibernation_sliver_returns_a_sliver_from_a_bolt() -> void:
	var ai := _ai()
	put_battlefield(0, "Hibernation Sliver")
	var metallic := put_battlefield(0, "Metallic Sliver")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) and guard < 400:
		_advance_once()
		guard += 1
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(metallic)]))
	assert_ok(g.pass_priority(1))
	assert_string_contains(ai.act(g), "Metallic Sliver")
	resolve_stack()
	assert_eq(metallic.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].life, 18)


func test_the_shot_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Acidic Sliver")
		for _i in 2: put_battlefield(0, "Mountain")
		g.players[1].life = 2
		give_hand(1, "Fog" if variant == 0 else "Healing Salve")
		g.players[1].library.reverse()
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
