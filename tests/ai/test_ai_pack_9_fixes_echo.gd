extends GameTest
## ECHO CHAMBER, READ BY THE FAIR AI (Pack 9 study fix, 2026-10-06; CR
## 115.1, 602.2b; [member AiProfile.forecasts_tactics];
## engine/ai/alliances_tactics.gd, role `hasty_token`).
##
## "{4}, {T}: An opponent chooses target creature they control. Create a
## token that's a copy of that creature. That token gains haste until end
## of turn. Exile the token at the beginning of the next end step.
## Activate only as a sorcery."
##
## The duel audit (pack_9_duel_audit index 55, turn 20) saw the AI pay
## {4} into an Echo Chamber with no creature across the table: the
## `hasty_token` reading (Balduvian Dead's flat 6.0) never asked for a
## legal target, and the engine refused the activation after the lands
## were tapped. Now a targeted token maker needs a legal target, and the
## copy the OPPONENT names is worth the body they would miss least (the
## card's own chooser order, public) — the role's `opponent_chooses`.
## The null arm (gate off) never reaches the reading; the opponent's
## hidden hand and library do not move a decision.

const A := preload("res://engine/ai/alliances_tactics.gd")


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


func _chamber_board() -> CardInstance:
	var chamber := put_battlefield(0, "Echo Chamber")
	for _i in 4: put_battlefield(0, "Plains")
	return chamber


func _refusals() -> int:
	var n := 0
	for line in g.log_lines:
		if String(line).contains("activation of Echo Chamber refused"):
			n += 1
	return n


func test_no_activation_while_they_control_no_creature() -> void:
	var ai := _ai()
	var chamber := _chamber_board()
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(A.option(g, ai, chamber, 0, "MAIN"), {}, "no legal target, no reading")
	ai.act(g)
	assert_eq(_refusals(), 0, "nothing paid into a refusal")
	assert_false(chamber.tapped)
	for inst in g.players[0].battlefield:
		assert_false(inst.tapped, "%s stayed untapped" % inst.data.card_name)


func test_the_copy_they_name_is_their_weakest_body() -> void:
	var ai := _ai()
	var chamber := _chamber_board()
	put_battlefield(1, "Serra Angel")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var option: Dictionary = A.option(g, ai, chamber, 0, "MAIN")
	assert_eq(float(option["value"]), Evaluator.permanent_value(bears, ai.profile),
		"they hand over the Bears, not the Angel")
	assert_eq(option["targets"], [], "the opponent names it, not us")
	assert_ne(ai.act(g), "activated Echo Chamber", "a one-turn Bears is not worth {4}")


func test_a_copy_worth_the_mana_is_made() -> void:
	var ai := _ai()
	var chamber := _chamber_board()
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Echo Chamber")
	assert_true(chamber.tapped)
	assert_eq(_refusals(), 0)


func test_the_null_arm_never_reaches_the_reading() -> void:
	var ai := _ai(false)
	var chamber := _chamber_board()
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_null(A.option(g, ai, chamber, 0, "MAIN"))


func test_the_reading_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_chamber_board()
		put_battlefield(1, "Serra Angel")
		put_battlefield(1, "Grizzly Bears")
		give_hand(1, "Shatter" if variant == 0 else "Craw Wurm")
		g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
