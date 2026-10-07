extends GameTest
## THE LICID DECISION'S BUDGET (whole-game campaign 2026-10-07, w6-2;
## engine/ai/tempest_tactics.gd `licid_plan`, [member
## AiProfile.forecasts_tactics]).
##
## Seven licids took one Wizard main-phase decision to seconds: every licid
## read the whole attack again for every host on both sides. The arm now
## makes one plan per decision — the base readings once, a twin licid's
## answer reused, only the hosts the Aura half can matter on, at most
## [constant TempestTactics.LICID_READINGS] readings at a shared node
## allowance. Pinned here:
##  * the seven-licid board decides within a second, the same activation;
##  * an ordinary board answers exactly what reading every host at the
##    profile's full budget answers (the arm before the budget);
##  * two identical licids are read once;
##  * the opponent's hidden hand and library order move nothing;
##  * the gate off is the null arm, and the decision leaves the profile's
##    own search budget and the game's random stream as it found them.

const TT := preload("res://engine/ai/tempest_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
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


func _lands(name: String, n: int, seat := 0) -> void:
	for _i in n: put_battlefield(seat, name)


## The hunt's board (tests/_hunt/w6, Pack 9 audit seed 4051 turn 20): six
## licids that can act, a Youthful Knight, against six creatures.
func _seven_licids() -> void:
	for n in ["Forest", "Plains", "Forest", "Plains", "Forest", "Plains", "Forest", "Mountain"]:
		put_battlefield(0, n)
	for n in ["Youthful Knight", "Calming Licid", "Transmogrifying Licid", "Tempting Licid",
			"Tempting Licid", "Convulsing Licid", "Enraging Licid", "Nurturing Licid"]:
		put_battlefield(0, n)
	for n in ["Forest", "Forest", "Plains", "Plains", "Plains"]:
		put_battlefield(1, n)
	for n in ["Mirri, Cat Warrior", "Keeper of the Light", "Soul Warden", "Welkin Hawk",
			"Welkin Hawk", "Plated Rootwalla"]:
		put_battlefield(1, n)
	g.players[0].life = 5
	g.players[1].life = 29
	advance_to_step(Mtg.Step.MAIN1)


## Every licid ability of seat 0: `[licid, index]`.
func _licids() -> Array:
	var out: Array = []
	for inst in g.players[0].battlefield:
		for index in inst.cur_activated_abilities.size():
			var a: ActivatedAbility = inst.cur_activated_abilities[index]
			if not a.effects.is_empty() and a.effects[0].ai_role == TT.LICID_ROLE:
				out.append([inst, index])
	return out


## THE ARM BEFORE THE BUDGET: every legal host on both sides read at the
## profile's full search budget, the best gain kept (the first on a tie).
func _reference(ai: AiPlayer, s: CardInstance, index: int) -> Dictionary:
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	var spec: TargetSpec = a.effects[0].target_spec
	var defender := g.opponent_of(0)
	var before := TT.attack_worth(g, ai, defender)
	var toll := TT.toll_value(g, ai, s)
	var best := {}
	for host in g.players[0].battlefield:
		if host == s or not host.is_creature() or not spec.is_legal(g, TargetRef.card(host), s):
			continue
		var gain := TT.attack_worth_dressed(g, ai, s, host, defender) - before - toll
		if best.is_empty() or gain > float(best["value"]):
			best = {"value": gain, "target": host.id}
	var threat := TT.their_attack_worth(g, ai)
	var body: float = ai._own_value(g, s) * 0.5
	for host in g.players[defender].battlefield:
		if not host.is_creature() or not spec.is_legal(g, TargetRef.card(host), s):
			continue
		if preload("res://engine/ai/mirage_tactics.gd").dies_when_targeted(host, g):
			continue
		var gain := TT.hostile_gain(g, ai, s, host, before, threat) + toll - body
		if best.is_empty() or gain > float(best["value"]):
			best = {"value": gain, "target": host.id}
	return best


## Each licid's budgeted answer against the reference: the same host at the
## same value when the reference clears the main phase's bar, and nothing
## that clears it when the reference does not. Returns how many cleared it.
func _assert_reads_as_before(ai: AiPlayer) -> int:
	var cleared := 0
	for row in _licids():
		var s: CardInstance = row[0]
		var ref := _reference(ai, s, int(row[1]))
		var got: Variant = TT.licid_option(g, ai, s, int(row[1]), "MAIN")
		assert_true(got is Dictionary)
		var bar: float = AiPlayer.ABILITY_BAR_MAIN
		if not ref.is_empty() and float(ref["value"]) >= bar:
			cleared += 1
			assert_false((got as Dictionary).is_empty(), "%s lost its activation" % s.data.card_name)
			assert_almost_eq(float(got["value"]), float(ref["value"]), 0.001, s.data.card_name)
			assert_eq((got["targets"][0] as TargetRef).instance_id, int(ref["target"]), s.data.card_name)
		else:
			assert_true((got as Dictionary).is_empty() or float(got["value"]) < bar,
				"%s cleared the bar only under the budget" % s.data.card_name)
	return cleared


# ------------------------------------------------------------ the time --

func test_seven_licids_decide_within_a_second_and_the_same_way() -> void:
	var ai := _ai()
	_seven_licids()
	var t := Time.get_ticks_usec()
	var did := ai.act(g)
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	gut.p("did=%s in %.0f ms" % [did, ms])
	# The decision the unbudgeted arm made on this board (9.7 s → < 1 s).
	assert_eq(did, "activated Calming Licid")
	assert_lt(ms, 1000.0, "one Wizard main-phase decision took %.0f ms" % ms)
	# The bound itself is a count, not a clock: no machine reads more.
	var plan: Dictionary = ai.get_meta(TT.LICID_PLAN_META)
	var readings := 1
	for id in plan["hosts"]:
		readings += plan["hosts"][id]["ours"].size() + plan["hosts"][id]["theirs"].size()
	assert_lte(readings, TT.LICID_READINGS)
	assert_lte(int(plan["nodes"]) * readings, maxi(TT.LICID_NODES, TT.LICID_MIN_NODES * readings))


func test_the_fifth_preset_is_bounded_the_same_way() -> void:
	g.rules.set_preset("fifth")
	var ai := _ai()
	_seven_licids()
	var t := Time.get_ticks_usec()
	var did := ai.act(g)
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	gut.p("fifth: did=%s in %.0f ms" % [did, ms])
	assert_lt(ms, 1000.0)
	var plan: Dictionary = ai.get_meta(TT.LICID_PLAN_META)
	var readings := 1
	for id in plan["hosts"]:
		readings += plan["hosts"][id]["ours"].size() + plan["hosts"][id]["theirs"].size()
	assert_lte(readings, TT.LICID_READINGS)


func test_the_decision_restores_the_search_budget_and_the_random_stream() -> void:
	var ai := _ai()
	_seven_licids()
	var nodes := ai.profile.combat_search_nodes
	var state := g.rng.state
	for row in _licids():
		TT.licid_option(g, ai, row[0], int(row[1]), "MAIN")
	assert_eq(ai.profile.combat_search_nodes, nodes)
	assert_eq(g.rng.state, state)
	assert_null(g.undo_log, "no search journal left open")


# ---------------------------------------------- ordinary boards, as before --

func test_a_steal_reads_as_before() -> void:
	var ai := _ai()
	put_battlefield(0, "Dominating Licid")
	_lands("Island", 3)
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(_assert_reads_as_before(ai), 1, "the steal clears the bar")


func test_a_grounded_flier_and_a_wall_out_of_the_way_read_as_before() -> void:
	var ai := _ai()
	put_battlefield(0, "Calming Licid")
	put_battlefield(0, "Convulsing Licid")
	put_battlefield(0, "Craw Wurm")
	_lands("Plains", 1)
	_lands("Mountain", 1)
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Wall of Stone")
	g.players[0].life = 6
	advance_to_step(Mtg.Step.MAIN1)
	assert_gt(_assert_reads_as_before(ai), 0)


func test_our_own_attackers_dressed_read_as_before() -> void:
	var ai := _ai()
	put_battlefield(0, "Enraging Licid")
	put_battlefield(0, "Transmogrifying Licid")
	put_battlefield(0, "Hill Giant", true)   # haste is the point
	put_battlefield(0, "Grizzly Bears")
	_lands("Mountain", 3)
	put_battlefield(1, "Llanowar Elves")
	g.players[1].life = 7
	advance_to_step(Mtg.Step.MAIN1)
	_assert_reads_as_before(ai)


# ------------------------------------------------------------- the twins --

func test_two_identical_licids_are_read_once() -> void:
	var ai := _ai()
	var first := put_battlefield(0, "Tempting Licid")
	var second := put_battlefield(0, "Tempting Licid")
	put_battlefield(0, "Craw Wurm")
	_lands("Forest", 2)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Llanowar Elves")
	advance_to_step(Mtg.Step.MAIN1)
	var a: Dictionary = TT.licid_option(g, ai, first, 0, "MAIN")
	var plan: Dictionary = ai.get_meta(TT.LICID_PLAN_META)
	assert_false(plan["hosts"].has(second.id), "the twin has no readings of its own")
	var b: Dictionary = TT.licid_option(g, ai, second, 0, "MAIN")
	assert_eq(plan["answers"].size(), 1)
	assert_almost_eq(float(b["value"]), float(a["value"]), 0.0001)
	var aimed: int = (a["targets"][0] as TargetRef).instance_id
	var twin_aim: int = (b["targets"][0] as TargetRef).instance_id
	# Each dresses the other: the first on the second is the second on the first.
	assert_eq(twin_aim, first.id if aimed == second.id else aimed)


func test_the_answer_handed_out_is_a_copy() -> void:
	var ai := _ai()
	var licid := put_battlefield(0, "Dominating Licid")
	_lands("Island", 3)
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	var first: Dictionary = TT.licid_option(g, ai, licid, 0, "MAIN")
	var worth := float(first["value"])
	first["value"] = -100.0   # the scan prices pain into the option it is handed
	var again: Dictionary = TT.licid_option(g, ai, licid, 0, "MAIN")
	assert_almost_eq(float(again["value"]), worth, 0.0001)


# -------------------------------------------------------- fair play, gate --

func test_their_hidden_hand_and_library_order_move_nothing() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_seven_licids()
		give_hand(1, "Disenchant" if variant == 0 else "Giant Growth")
		if variant == 1:
			g.players[1].library.reverse()
			g.players[0].library.reverse()
		var lines: Array = []
		for row in _licids():
			var got: Dictionary = TT.licid_option(g, ai, row[0], int(row[1]), "MAIN")
			lines.append("" if got.is_empty() else "%.4f@%d" % [float(got["value"]),
				(got["targets"][0] as TargetRef).instance_id])
		answers.append(lines)
	assert_eq(answers[0], answers[1], "hidden cards changed the licid readings")


func test_the_null_arm_reads_no_licid() -> void:
	var ai := _ai(false)
	_seven_licids()
	for row in _licids():
		assert_null(TT.licid_option(g, ai, row[0], int(row[1]), "MAIN"))
	assert_false(ai.has_meta(TT.LICID_PLAN_META), "the null arm makes no plan")
