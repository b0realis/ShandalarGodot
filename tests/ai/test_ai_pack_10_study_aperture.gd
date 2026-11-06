extends GameTest
## TEMPORAL APERTURE, USED BY THE FAIR AI (Pack 10 study, 2026-11-06;
## [member AiProfile.forecasts_tactics]; engine/ai/urza_spells.gd
## `aperture`).
##
## "{5}, {T}: Shuffle your library, then reveal the top card. Until end of
## turn, for as long as that card remains on top of your library, play
## with the top card of your library revealed and you may play that card
## without paying its mana cost." The policy read it as worth 2.5 against
## the main phase's bar of 3.0 — after the activation's own price of 2.0 —
## so it never cleared: the Pack 10 duel audit (seed 99000, twelve rounds)
## cast 80 Apertures and activated none. Now it is a mana sink of our own
## main phase, its casts done, worth an unseen card; and the card it shows
## is then played through its free row. Null arm (gate off) and the
## opponent's hidden hand and library changed (docs/fair-play.md).

const US := preload("res://engine/ai/urza_spells.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


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


func _lands(n: int) -> void:
	for _i in n: put_battlefield(0, "Island")


## [param pid]'s library as [param n] copies of [param card_name], so the
## shuffle's top card is known to the TEST (never to the AI).
func _library_of(pid: int, card_name: String, n := 12) -> void:
	g.players[pid].library.clear()
	for _i in n:
		var inst := _make_instance(pid, card_name)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(inst)


func _act_until_quiet(ai: AiPlayer) -> Array:
	var lines: Array = []
	for _i in 8:
		var line := ai.act(g)
		lines.append(line)
		resolve_stack()
		if line == "pass" or line == "":
			break
	return lines


func _bears(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == "Grizzly Bears": n += 1
	return n


# -------------------------------------------------------------- the sink --

func test_the_aperture_is_activated_with_five_to_spare_and_its_card_played() -> void:
	var ai := _ai()
	var aperture := put_battlefield(0, "Temporal Aperture")
	_lands(5)
	_library_of(0, "Grizzly Bears")
	var option: Dictionary = US.option(g, ai, aperture, 0, "MAIN")
	assert_false(option.is_empty())
	var lines := _act_until_quiet(ai)
	assert_true(lines.has("activated Temporal Aperture"), str(lines))
	assert_eq(_bears(0), 1, "the revealed Bears are cast through the free row: %s" % str(lines))
	var free := false
	for line in g.log_lines:
		if line.contains("casts Grizzly Bears (Temporal Aperture)"): free = true
	assert_true(free, "without paying its mana cost")


func test_four_lands_are_not_five() -> void:
	var ai := _ai()
	put_battlefield(0, "Temporal Aperture")
	_lands(4)
	_library_of(0, "Grizzly Bears")
	var lines := _act_until_quiet(ai)
	assert_false(lines.has("activated Temporal Aperture"), str(lines))


func test_never_on_their_turn() -> void:
	var ai := _ai()
	var aperture := put_battlefield(0, "Temporal Aperture")
	for window in ["SINK", "UPKEEP", "RESPONSE"]:
		assert_eq(US.option(g, ai, aperture, 0, window), {}, window)


func test_a_thin_library_keeps_its_cards() -> void:
	var ai := _ai()
	var aperture := put_battlefield(0, "Temporal Aperture")
	_lands(5)
	_library_of(0, "Grizzly Bears", 4)
	assert_eq(US.option(g, ai, aperture, 0, "MAIN"), {})


# ---------------------------------------------------- null arm, fair play --

func test_the_null_arm_reads_the_aperture_as_before() -> void:
	var ai := _ai(false)
	var aperture := put_battlefield(0, "Temporal Aperture")
	assert_null(US.option(g, ai, aperture, 0, "MAIN"))


func test_their_hidden_hand_and_library_do_not_move_the_answer() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		var aperture := put_battlefield(0, "Temporal Aperture")
		_lands(5)
		_library_of(0, "Grizzly Bears")
		if variant == 1:
			for card_name in ["Counterspell", "Lightning Bolt", "Shivan Hellkite"]:
				give_hand(1, card_name)
			_library_of(1, "Island")
		answers.append(US.option(g, ai, aperture, 0, "MAIN"))
		after_each()
	assert_eq(answers[0], answers[1])
