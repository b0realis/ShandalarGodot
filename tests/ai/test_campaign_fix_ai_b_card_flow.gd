extends GameTest
## THREE PRICES THE FAIR AI READ WRONG (whole-game campaign 2026-10-07;
## [member AiProfile.forecasts_tactics]):
##  * w2-2 NECROPOTENCE (engine/ai/ice_age_tactics.gd `necro_digs`): a flat
##    five life kept, a hand of `life - 5` — at 7 life with a dead hand and
##    nothing across the table it never drew again. The line kept is now the
##    swing the table shows plus a Bolt's margin, and above it the pilot
##    takes at least one card a turn.
##  * w3-6 ECHO CHAMBER (engine/ai/alliances_tactics.gd `hasty_token`): a
##    copy of their Phyrexian Dreadnought is a one-turn token whose arrival
##    trigger asks two Craw Wurms to keep it; a copy that does not stay is
##    worth nothing.
##  * w2-9 DEMONIC CONSULTATION (AI side): the pilot answers the card's own
##    name hint (cards/sets/ice/_more.gd `_consult_hint`) — a nonland — and
##    the library's hidden order changes nothing.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


# ------------------------------------------------------------ Necropotence --

func _necro(life: int, hand: Array, theirs: Array) -> void:
	put_battlefield(0, "Necropotence")
	for _n in 5: put_battlefield(0, "Snow-Covered Swamp")
	for name in hand: give_hand(0, name)
	for name in theirs: put_battlefield(1, name)
	g.players[0].life = life


func test_necropotence_digs_with_a_dead_hand_and_an_empty_table() -> void:
	_necro(7, ["Contagion", "Contagion"], [])
	var ai := _ai()
	assert_eq(ai._try_activate(g), "activated Necropotence",
		"a dead hand at 7 life with no threat on the table must still draw")


func test_necropotence_keeps_the_life_their_swing_asks_for() -> void:
	# Their Craw Wurm swings for 6 next turn: at 9 life the line is 10.
	_necro(9, ["Contagion"], ["Craw Wurm"])
	var ai := _ai()
	assert_ne(ai._try_activate(g), "activated Necropotence",
		"a life paid here is a life the Wurm's swing needs")


func test_necropotence_takes_one_card_a_turn_above_the_line() -> void:
	# Their 2/2 asks for 6 kept: at 10 life the fill is a hand of four,
	# which the four Contagions already make — and the one card a turn
	# still comes.
	_necro(10, ["Contagion", "Contagion", "Contagion", "Contagion"], ["Grizzly Bears"])
	var ai := _ai()
	assert_eq(ai._try_activate(g), "activated Necropotence")
	resolve_stack()
	assert_ne(ai._try_activate(g), "activated Necropotence", "one a turn, not more")


func test_the_null_arm_keeps_its_flat_five() -> void:
	_necro(7, ["Contagion", "Contagion"], [])
	var ai := _ai(false)
	assert_ne(ai._try_activate(g), "activated Necropotence",
		"gate off: the pre-campaign budget of life - 5 cards")


func test_necropotence_ignores_their_hidden_hand() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		_necro(9, ["Contagion"], ["Grizzly Bears"])
		give_hand(1, "Lightning Bolt" if variant == 0 else "Forest")
		if variant == 1:
			g.players[1].library.reverse()
		answers.append(_ai()._try_activate(g))
	assert_eq(answers[0], answers[1])


# ------------------------------------------------------------ Echo Chamber --

func _echo(copied: String) -> Dictionary:
	var ai := _ai()
	var chamber := put_battlefield(0, "Echo Chamber")
	var w1 := put_battlefield(0, "Craw Wurm")
	var w2 := put_battlefield(0, "Craw Wurm")
	for _k in 4: put_battlefield(0, "Mountain")
	put_battlefield(1, copied)
	g._waiting_triggers.clear()   # setup: it has been on the table a while
	g.stack.clear()
	var turn := g.turn_number
	for _k in 120:
		if g.game_over or g.turn_number != turn: break
		if g.awaiting_attackers and g.active_player != ai.pid: break
		if g.priority_player == ai.pid or (g.awaiting_blockers and g.active_player != ai.pid):
			if ai.act(g) == "" and g.priority_player == ai.pid:
				g.pass_priority(ai.pid)
		else:
			g.pass_priority(g.priority_player)
	var echoed := false
	for line in g.log_lines:
		if String(line).contains("activates Echo Chamber"): echoed = true
	return {"chamber": chamber, "w1": w1, "w2": w2, "echoed": echoed}


func test_echo_chamber_never_copies_a_dreadnought_it_must_feed() -> void:
	var seen := _echo("Phyrexian Dreadnought")
	assert_eq((seen["w1"] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)
	assert_eq((seen["w2"] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)
	assert_false(bool(seen["echoed"]), "a copy that does not stay is worth no activation")


func test_echo_chamber_reading_skips_only_a_copy_that_does_not_stay() -> void:
	var ai := _ai()
	var chamber := put_battlefield(0, "Echo Chamber")
	for _k in 4: put_battlefield(0, "Mountain")
	var wurm := put_battlefield(1, "Craw Wurm")
	var tactics := preload("res://engine/ai/alliances_tactics.gd")
	assert_false(tactics.keeps_only_for_a_price(wurm))
	var option: Variant = tactics.option(g, ai, chamber, 0, "MAIN")
	assert_false((option as Dictionary).is_empty(), "a Craw Wurm copy stays for its turn")
	var dread := put_battlefield(1, "Phyrexian Dreadnought")
	assert_true(tactics.keeps_only_for_a_price(dread))
	g.destroy(wurm)
	g._waiting_triggers.clear()
	g.stack.clear()
	assert_true((tactics.option(g, ai, chamber, 0, "MAIN") as Dictionary).is_empty())
	assert_null(tactics.option(g, _ai(false), chamber, 0, "MAIN"), "gate off: no reading")


# ----------------------------------------------------- Demonic Consultation --

func _consult(reverse: bool) -> String:
	var names: Array[String] = []
	for _n in 18: names.append("Swamp")
	for _n in 4: names.append("Necropotence")
	for _n in 4: names.append("Hypnotic Specter")
	for _n in 4: names.append("Demonic Consultation")
	g.players[0].deck_names = names
	for _n in 5: put_battlefield(0, "Swamp")
	var lib: Array = []
	for _n in 12: lib.append("Swamp")
	lib.append("Necropotence")
	lib.append("Hypnotic Specter")
	for name in lib:
		var inst := _make_instance(0, name)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[0].library.append(inst)
	if reverse:
		g.players[0].library.reverse()
	_ai()
	var dc := give_hand(0, "Demonic Consultation")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, dc, []))
	resolve_stack()
	for line in g.log_lines:
		if String(line).begins_with("Demonic Consultation names "):
			return String(line).trim_prefix("Demonic Consultation names ")
	return ""


func test_the_pilot_names_a_spell_not_a_basic_land() -> void:
	var named := _consult(false)
	assert_ne(named, "")
	assert_false(CardRegistry.get_card(named).is_land(), "named %s" % named)


func test_the_libraries_hidden_order_changes_no_name() -> void:
	var first := _consult(false)
	before_each()
	assert_eq(_consult(true), first)
