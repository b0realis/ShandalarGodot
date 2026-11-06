extends GameTest
## SERRA'S HYMN, READ BY THE FAIR AI (Pack 10 study, 2026-11-06;
## [member AiProfile.forecasts_tactics]; engine/ai/urza_tactics.gd
## `hymn_cash`).
##
## "Sacrifice this enchantment: Prevent the next X damage that would be
## dealt this turn to any number of targets, divided as you choose, where X
## is the number of verse counters on this enchantment." Its counted slot
## read like the up-to-X removal of the verse cycle, so the AI cashed it in
## its main phase ON THE OPPONENT'S CREATURES, one share each — prevention
## handed to their side, refused whenever the shares fell short of X (the
## Pack 10 duel audit, modern seed 99070: "divided amounts must add up to 6
## (got 2)", eight times in one duel). Now it is only an answer to damage
## the board shows coming, the whole X on our own side. Null arm (gate
## off) and the opponent's hidden hand and library changed
## (docs/fair-play.md).

const UT := preload("res://engine/ai/urza_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	g.rules.set_edition("modern")


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


func _hymn(verses: int) -> CardInstance:
	var hymn := put_battlefield(0, "Serra's Hymn")
	if verses > 0: g.add_counters(hymn, "verse", verses)
	return hymn


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## They cast Lightning Bolt at [param target] and pass; seat 0 holds priority.
func _they_bolt(target: TargetRef) -> void:
	_their_main()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [target]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func _answer_until_resolved(ai: AiPlayer) -> Array:
	var lines: Array = []
	var guard := 0
	while not g.stack.is_empty() and guard < 40:
		if g.priority_player == 0:
			lines.append(ai.act(g))
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	return lines


func _ids(targets: Array) -> Array:
	return targets.map(func(ref: TargetRef) -> String:
		return "player %d" % ref.player_id if ref.is_player else "card %d" % ref.instance_id)


# --------------------------------------------- never their side, never main --

func test_the_hymn_is_never_cashed_in_a_main_phase_on_their_creatures() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var ai := _ai()
	var hymn := _hymn(5)
	put_battlefield(1, "Goblin Matron")
	put_battlefield(1, "Goblin Raider")
	for window in ["MAIN", "SINK", "UPKEEP"]:
		assert_eq(UT.option(g, ai, hymn, 0, window), {}, window)
	for _i in 4:
		var line := ai.act(g)
		assert_false(line.contains("Serra's Hymn"), line)
		if line == "pass" or line == "":
			break
	assert_eq(hymn.zone, Mtg.Zone.BATTLEFIELD, "the verses wait for damage")
	for line in g.log_lines:
		assert_false(line.contains("divided amounts must add up"), line)


func test_no_verse_no_hymn_even_against_a_bolt() -> void:
	var ai := _ai()
	var hymn := _hymn(0)
	var unicorn := put_battlefield(0, "Pearled Unicorn")
	_they_bolt(TargetRef.card(unicorn))
	assert_eq(UT.option(g, ai, hymn, 0, "RESPONSE"), {})


# ------------------------------------------------ an answer to the damage --

func test_the_hymn_saves_our_creature_from_their_bolt() -> void:
	var ai := _ai()
	var hymn := _hymn(3)
	var unicorn := put_battlefield(0, "Pearled Unicorn")
	put_battlefield(1, "Goblin Matron")
	_they_bolt(TargetRef.card(unicorn))
	var cash: Dictionary = UT.option(g, ai, hymn, 0, "RESPONSE")
	assert_false(cash.is_empty(), "the bolt is the Hymn's moment")
	assert_eq(_ids(cash["targets"]), ["card %d" % unicorn.id],
		"the whole X on our own creature, one target")
	var lines := _answer_until_resolved(ai)
	assert_true(lines.has("activated Serra's Hymn"), str(lines))
	assert_eq(unicorn.zone, Mtg.Zone.BATTLEFIELD, "the bolt is prevented")
	assert_eq(hymn.zone, Mtg.Zone.GRAVEYARD)


func test_the_hymn_saves_us_from_a_lethal_bolt() -> void:
	var ai := _ai()
	var hymn := _hymn(3)
	g.players[0].life = 3
	_they_bolt(TargetRef.player(0))
	var cash: Dictionary = UT.option(g, ai, hymn, 0, "RESPONSE")
	assert_eq(_ids(cash.get("targets", [])), ["player 0"])
	assert_eq(float(cash["value"]), AiPlayer.LETHAL_WORTH)
	_answer_until_resolved(ai)
	assert_eq(g.players[0].life, 3)
	assert_false(g.game_over)


func test_a_bolt_at_their_own_creature_is_not_the_hymns_business() -> void:
	var ai := _ai()
	var hymn := _hymn(4)
	put_battlefield(0, "Pearled Unicorn")
	var matron := put_battlefield(1, "Goblin Matron")
	_they_bolt(TargetRef.card(matron))
	assert_eq(UT.option(g, ai, hymn, 0, "RESPONSE"), {})


# ---------------------------------------------------- null arm, fair play --

func test_the_null_arm_reads_the_hymn_as_before() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var ai := _ai(false)
	var hymn := _hymn(5)
	put_battlefield(1, "Goblin Matron")
	for window in ["MAIN", "RESPONSE"]:
		assert_null(UT.option(g, ai, hymn, 0, window), window)


func test_their_hidden_hand_and_library_do_not_move_the_answer() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		var hymn := _hymn(3)
		var unicorn := put_battlefield(0, "Pearled Unicorn")
		if variant == 1:
			for card_name in ["Lightning Bolt", "Shivan Hellkite", "Arc Lightning"]:
				give_hand(1, card_name)
			g.players[1].library.reverse()
			g.players[0].library.reverse()
		_they_bolt(TargetRef.card(unicorn))
		var cash: Dictionary = UT.option(g, ai, hymn, 0, "RESPONSE")
		answers.append([_ids(cash.get("targets", [])).map(func(s: String) -> String:
			return "ours" if s == "card %d" % unicorn.id else s), cash.is_empty()])
		after_each()
	assert_eq(answers[0], answers[1])
