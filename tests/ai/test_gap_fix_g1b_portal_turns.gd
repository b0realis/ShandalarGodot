extends GameTest
## Gap review 2026-11-10: the Portal / Portal Second Age turn spells.
##  * r1b-3 — Relentless Assault ("Untap all creatures that attacked this
##    turn. After this main phase, there is an additional combat phase
##    followed by an additional main phase.") was priced at every untapped
##    creature in ANY main phase, so it went in the first main phase,
##    before anything had attacked: the extra combat came first and the
##    turn's own combat had nobody left (one attack for the card, not two).
##  * r1b-5 — Last Chance ("Take an extra turn after this one. At the
##    beginning of that turn's end step, you lose the game.") was bought
##    whenever the extra turn's unblockable damage reached their life —
##    also when THIS turn's attack already did, adding nothing but the
##    loss if they survive.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-6", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(seat: int, profile: AiProfile) -> AiPlayer:
	profile.mistake_chance = 0.0
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


## Our whole turn with the Assault in hand; [param hidden] goes into their
## hand (a card our seat cannot see).
func _assault_turn(profile: AiProfile, hidden := "Forest") -> Dictionary:
	var ai := _ai(0, profile)
	var other := _ai(1, AiProfile.wizard())
	for _i in 4: put_battlefield(0, "Mountain")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Relentless Assault")
	give_hand(1, hidden)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.active_player, 0)
	var lines: Array = []
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and not g.game_over and guard < 400:
		guard += 1
		var did := ai.act(g)
		if did != "pass" and did != "":
			lines.append("%s@%s" % [did, Mtg.step_name(g.current_step())])
		other.act(g)
	return {"lines": lines, "life": g.players[1].life}


func test_wizard_takes_two_attacks_for_the_assault() -> void:
	var out := _assault_turn(AiProfile.wizard())
	gut.p("Wizard: %s; their life %d" % [out["lines"], out["life"]])
	assert_eq(int(out["life"]), 12, "two attacks of 4 for the card: %s" % [out["lines"]])
	assert_false(str(out["lines"][0]).begins_with("cast Relentless"),
		"not cast before anything attacked: %s" % [out["lines"]])


func test_apprentice_takes_two_attacks_for_the_assault() -> void:
	var out := _assault_turn(AiProfile.apprentice())
	gut.p("Apprentice: %s; their life %d" % [out["lines"], out["life"]])
	assert_eq(int(out["life"]), 12, "two attacks of 4 for the card: %s" % [out["lines"]])


## What their hand hides does not move the plan.
func test_the_assault_reads_no_hidden_card() -> void:
	var a := _assault_turn(AiProfile.wizard(), "Forest")
	after_each()
	before_each()
	var b := _assault_turn(AiProfile.wizard(), "Fog")
	assert_eq(a["lines"], b["lines"], "their hidden card moved the plan")


## The reading itself: nothing has attacked in the first main phase.
func test_the_assault_is_worth_nothing_before_an_attack() -> void:
	var ai := _ai(0, AiProfile.wizard())
	for _i in 4: put_battlefield(0, "Mountain")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	var assault := give_hand(0, "Relentless Assault")
	advance_to_step(Mtg.Step.MAIN1)
	var choice: Variant = preload("res://engine/ai/second_age_tactics.gd").spell_choice(g, ai, assault)
	assert_true(choice is Dictionary and (choice as Dictionary).is_empty(), str(choice))
	# The null arm reads nothing.
	ai.profile.forecasts_tactics = false
	assert_null(preload("res://engine/ai/second_age_tactics.gd").spell_choice(g, ai, assault))


func _last_chance_board(sick: bool, hidden := "Forest") -> String:
	var ai := _ai(0, AiProfile.wizard())
	put_battlefield(0, "Grizzly Bears", sick)
	put_battlefield(0, "Grizzly Bears", sick)
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	give_hand(0, "Last Chance")
	give_hand(1, hidden)
	g.players[1].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.active_player, 0)
	for c in g.players[0].creatures():
		c.summoning_sick = sick
	return ai.act(g)


func test_last_chance_is_not_bought_when_this_turn_is_lethal() -> void:
	var did := _last_chance_board(false)
	gut.p("Last Chance, lethal now: '%s'" % did)
	assert_false(did.begins_with("cast Last Chance"), "two unblocked Bears already kill this turn")


## Control: the Bears cannot attack this turn, the extra turn is the kill.
func test_last_chance_is_bought_when_only_the_extra_turn_kills() -> void:
	var did := _last_chance_board(true)
	gut.p("Last Chance, sick Bears: '%s'" % did)
	assert_true(did.begins_with("cast Last Chance"), did)


## What their hand hides does not move the decision.
func test_last_chance_reads_no_hidden_card() -> void:
	var a := _last_chance_board(false, "Forest")
	after_each()
	before_each()
	var b := _last_chance_board(false, "Fog")
	assert_eq(a, b, "their hidden card moved the decision")
