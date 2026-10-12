extends GameTest
## THE LICID DECISION'S WORK, BOUNDED BY THE BOARD (bug-hunt campaign
## 2026-10-12, b5-8; engine/ai/tempest_tactics.gd `licid_plan`, [member
## AiProfile.forecasts_tactics]).
##
## The last campaign bounded a licid decision to ten attack readings at a
## shared node allowance — but a reading's cost is the pilot's attack
## planner, which grows with the board and not with the nodes: in an
## eighteen-licid mirror one Wizard decision still took 1.1–1.7 s (the
## hunt, seed 93301 turn 33), and every licid dressed every host on both
## sides first. Now one decision covers at most
## [constant TempestTactics.LICID_WORK] combat cells (our creatures times
## theirs) of readings, never fewer than [constant
## TempestTactics.LICID_MIN_READINGS]; each licid dresses at most that
## many hosts a side (a few more tried), and a host identical to one
## already dressed is not dressed again. Pinned here:
##  * the mirror decides within its work, under both rules presets;
##  * a board the old budget fitted (the 7-licid board) is read as before;
##  * twin hosts are dressed once;
##  * the opponent's hidden hand and both libraries' order move nothing,
##    and the game, its random stream and the profile's search budget are
##    left as they were;
##  * the gate off is the null arm.

const TT := preload("res://engine/ai/tempest_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
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


## The hunt's board (b5 licid mirror, seed 93301, turn 33, the Wizard at
## 7 life in its first main phase): twelve licids and a Jackal Pup
## against eight creatures of theirs.
func _mirror() -> void:
	for n in ["Forest", "Forest", "Mountain", "Plains", "Forest", "Forest"]:
		put_battlefield(0, n)
	for n in ["Tempting Licid", "Quickening Licid", "Jackal Pup", "Convulsing Licid",
			"Transmogrifying Licid", "Calming Licid", "Enraging Licid", "Tempting Licid",
			"Convulsing Licid", "Nurturing Licid", "Quickening Licid", "Convulsing Licid"]:
		put_battlefield(0, n)
	for n in ["Forest", "Plains", "Mountain", "Mountain", "Forest", "Forest", "Plains", "Plains", "Mountain"]:
		put_battlefield(1, n)
	for n in ["Tempting Licid", "Jackal Pup", "Enraging Licid", "Tempting Licid", "Enraging Licid",
			"Transmogrifying Licid", "Nurturing Licid", "Tempting Licid", "Rootwalla"]:
		put_battlefield(1, n)
	g.players[0].life = 7
	g.players[1].life = 15
	advance_to_step(Mtg.Step.MAIN1)


func _cells() -> int:
	return g.players[0].creatures().size() * g.players[1].creatures().size()


func _readings(plan: Dictionary) -> int:
	var readings := 1
	for id in plan["hosts"]:
		readings += plan["hosts"][id]["ours"].size() + plan["hosts"][id]["theirs"].size()
	return readings


func _licids() -> Array:
	var out: Array = []
	for inst in g.players[0].battlefield:
		for index in inst.cur_activated_abilities.size():
			var a: ActivatedAbility = inst.cur_activated_abilities[index]
			if not a.effects.is_empty() and a.effects[0].ai_role == TT.LICID_ROLE:
				out.append([inst, index])
	return out


# ------------------------------------------------------------ the work --

func _mirror_within_its_work(preset: String) -> void:
	g.rules.set_preset(preset)
	var ai := _ai()
	_mirror()
	var t := Time.get_ticks_usec()
	var did := ai.act(g)
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	gut.p("%s: did=%s in %.0f ms" % [preset, did, ms])
	var plan: Dictionary = ai.get_meta(TT.LICID_PLAN_META)
	var cells := _cells()
	assert_gt(cells, 48, "a board past the one the old budget was set on")
	var cap := TT.readings_cap(cells)
	assert_eq(int(plan["cap"]), cap)
	assert_lte(cap * cells, maxi(TT.LICID_WORK, TT.LICID_MIN_READINGS * cells),
		"%s: the readings cover at most the decision's combat cells" % preset)
	assert_lte(_readings(plan), cap, "%s: no more readings than the cap" % preset)
	assert_lte(int(plan["dressed"]), _licids().size() * 2 * (cap + TT.LICID_SPARE_DRESSINGS),
		"%s: each licid dresses at most its share a side" % preset)
	# A clock as well as the counts, generous for a loaded machine: the
	# unbounded decision took 1.1 s on the desk that set it, 1.7 s in the hunt.
	assert_lt(ms, 1500.0, "%s: one Wizard main-phase decision took %.0f ms" % [preset, ms])


func test_the_licid_mirror_decides_within_its_work() -> void:
	_mirror_within_its_work("modern_mana_burn")


func test_the_licid_mirror_decides_within_its_work_under_the_1997_rules() -> void:
	_mirror_within_its_work("fifth")


func test_the_cap_keeps_the_old_budget_on_the_board_it_was_set_on() -> void:
	assert_eq(TT.readings_cap(48), TT.LICID_READINGS, "eight of ours against six: ten readings")
	assert_eq(TT.readings_cap(1), TT.LICID_READINGS)
	assert_eq(TT.readings_cap(117), maxi(TT.LICID_MIN_READINGS, TT.LICID_WORK / 117))
	assert_eq(TT.readings_cap(100000), TT.LICID_MIN_READINGS)


## The last campaign's board (seven licids, eight creatures against six):
## the same activation it chose then.
func test_the_seven_licid_board_reads_as_before() -> void:
	var ai := _ai()
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
	assert_eq(ai.act(g), "activated Calming Licid")
	var plan: Dictionary = ai.get_meta(TT.LICID_PLAN_META)
	assert_eq(int(plan["cap"]), TT.LICID_READINGS)


# ------------------------------------------------------------- the twins --

func test_twin_hosts_are_dressed_once() -> void:
	var ai := _ai()
	var licid := put_battlefield(0, "Calming Licid")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var first := put_battlefield(1, "Grizzly Bears")
	var second := put_battlefield(1, "Grizzly Bears")
	var hawk := put_battlefield(1, "Welkin Hawk")
	advance_to_step(Mtg.Step.MAIN1)
	var a: ActivatedAbility = licid.cur_activated_abilities[0]
	var found: Dictionary = TT.licid_hosts(g, ai, licid, a)
	var theirs: Array = []
	for row in found["theirs"]:
		theirs.append(int(row["id"]))
	assert_true(theirs.has(first.id), "the first Bears is read")
	assert_false(theirs.has(second.id), "its twin is not dressed again")
	assert_true(theirs.has(hawk.id))
	assert_eq(int(found["dressed"]), 2 + 0, "two dressings on their side, none of ours to dress")
	# A twin that differs (tapped) is its own host.
	g.tap_permanent(second)
	found = TT.licid_hosts(g, ai, licid, a)
	theirs.clear()
	for row in found["theirs"]:
		theirs.append(int(row["id"]))
	assert_true(theirs.has(second.id), "a tapped Bears is not the untapped one's twin")


# -------------------------------------------------------- fair play, gate --

func test_their_hidden_hand_and_the_libraries_move_nothing() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_mirror()
		for n in 3:
			give_hand(1, "Disenchant" if variant == 0 else "Giant Growth")
		if variant == 1:
			g.players[0].library.reverse()
			g.players[1].library.reverse()
		var lines: Array = []
		for row in _licids():
			var got: Dictionary = TT.licid_option(g, ai, row[0], int(row[1]), "MAIN")
			lines.append("" if got.is_empty() else "%.4f@%d" % [float(got["value"]),
				(got["targets"][0] as TargetRef).instance_id])
		answers.append(lines)
		after_each()
	assert_eq(answers[0], answers[1], "hidden cards changed the licid readings")


func test_the_decision_leaves_the_game_and_the_profile_as_it_found_them() -> void:
	var ai := _ai()
	_mirror()
	var nodes := ai.profile.combat_search_nodes
	var state := g.rng.state
	var board := g.players[0].battlefield.size() + g.players[1].battlefield.size()
	for row in _licids():
		TT.licid_option(g, ai, row[0], int(row[1]), "MAIN")
	assert_eq(ai.profile.combat_search_nodes, nodes)
	assert_eq(g.rng.state, state)
	assert_null(g.undo_log, "no search journal left open")
	assert_eq(g.players[0].battlefield.size() + g.players[1].battlefield.size(), board)
	for row in _licids():
		assert_false(g.is_licid_aura(row[0]), "every licid is a creature again")


func test_the_null_arm_reads_no_licid() -> void:
	var ai := _ai(false)
	_mirror()
	for row in _licids():
		assert_null(TT.licid_option(g, ai, row[0], int(row[1]), "MAIN"))
	assert_false(ai.has_meta(TT.LICID_PLAN_META), "the null arm makes no plan")
