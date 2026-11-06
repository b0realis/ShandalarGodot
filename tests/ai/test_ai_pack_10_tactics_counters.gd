extends GameTest
## THE URZA BLOCK'S COUNTERS CASHED IN, READ BY THE FAIR AI (Pack 10;
## [member AiProfile.forecasts_tactics]; engine/ai/urza_tactics.gd
## `counter_cash_option`).
##
## "Where X is the number of <kind> counters on this" with a sacrifice cost
## — the verse cycle (cards/sets/usg/_enchantments.gd), Barrin's Codex's
## pages, Powder Keg's fuse: never at X = 0 (the probe that opened the
## module saw Midsummer Revel and Rumbling Crescendo sacrificed for
## nothing), cashed when X covers what the board shows or three of it, and
## at once when their removal names the permanent. Lilting Refrain counters
## what their open mana cannot pay for; War Dance turns a declared fight.
## Null arms (gate off) and, where a hidden zone could matter, the
## opponent's hand and library changed (docs/fair-play.md).

const UT := preload("res://engine/ai/urza_tactics.gd")


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


func _lands(pid: int, card_name: String, n: int) -> void:
	for _i in n: put_battlefield(pid, card_name)


## [param card_name] on [param pid]'s battlefield with [param n] counters.
func _charged(pid: int, card_name: String, n: int, kind := "verse") -> CardInstance:
	var i := put_battlefield(pid, card_name)
	if n > 0: g.add_counters(i, kind, n)
	return i


func _their_end_step() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.END \
			and g.priority_player == 0 and g.stack.is_empty()) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.END)


func _act_until(ai: AiPlayer, needle: String) -> String:
	for _i in 6:
		var line := ai.act(g)
		if line.contains(needle) or line == "pass" or line == "":
			return line
		resolve_stack()
	return ""


func _restack(pid: int, names: Array) -> void:
	g.players[pid].library.clear()
	for n in names:
		var inst := _make_instance(pid, n)
		inst.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(inst)


func _tokens(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_token: n += 1
	return n


# ------------------------------------------------------------ Midsummer Revel --

func test_midsummer_revel_is_never_sacrificed_for_no_beast() -> void:
	var ai := _ai()
	var revel := _charged(0, "Midsummer Revel", 0)
	_lands(0, "Forest", 3)
	for window in ["MAIN", "SINK", "UPKEEP"]:
		assert_eq(UT.option(g, ai, revel, 0, window), {}, window)
	_their_end_step()
	ai.act(g)
	resolve_stack()
	assert_eq(revel.zone, Mtg.Zone.BATTLEFIELD)


func test_the_null_arm_reads_the_revel_as_before() -> void:
	var ai := _ai(false)
	var revel := _charged(0, "Midsummer Revel", 0)
	assert_null(UT.option(g, ai, revel, 0, "SINK"))


func test_midsummer_revel_makes_three_beasts_at_their_end_step() -> void:
	var ai := _ai()
	var revel := _charged(0, "Midsummer Revel", 3)
	_lands(0, "Forest", 1)
	_their_end_step()
	assert_eq(ai.act(g), "activated Midsummer Revel")
	resolve_stack()
	assert_eq(_tokens(0), 3)
	assert_eq(revel.zone, Mtg.Zone.GRAVEYARD)


func test_midsummer_revel_waits_for_more_verses_while_unpressed() -> void:
	var ai := _ai()
	var revel := _charged(0, "Midsummer Revel", 1)
	_lands(0, "Forest", 1)
	assert_eq(UT.option(g, ai, revel, 0, "SINK"), {})


# --------------------------------------------------------------- Vile Requiem --

func test_vile_requiem_waits_while_x_covers_one_of_two() -> void:
	var ai := _ai()
	var requiem := _charged(0, "Vile Requiem", 1)
	_lands(0, "Swamp", 2)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	assert_eq(UT.option(g, ai, requiem, 0, "MAIN"), {})


func test_vile_requiem_destroys_both_once_x_covers_them() -> void:
	var ai := _ai()
	_charged(0, "Vile Requiem", 2)
	_lands(0, "Swamp", 2)
	var bears := put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	assert_eq(_act_until(ai, "Vile Requiem"), "activated Vile Requiem")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)


func test_vile_requiem_cashes_in_as_a_disenchant_names_it() -> void:
	var ai := _ai()
	var requiem := _charged(0, "Vile Requiem", 1)
	_lands(0, "Swamp", 2)
	var angel := put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	assert_ok(g.pass_priority(0))
	var disenchant := give_hand(1, "Disenchant")
	add_mana(1, Mtg.ManaColor.W)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, disenchant, [TargetRef.card(requiem)]))
	assert_ok(g.pass_priority(1))
	assert_eq(ai.act(g), "activated Vile Requiem")
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD, "the one counter spent on their best")


# --------------------------------------------------------- Rumbling Crescendo --

func test_rumbling_crescendo_never_fires_empty() -> void:
	var ai := _ai()
	var crescendo := _charged(0, "Rumbling Crescendo", 0)
	_lands(0, "Mountain", 1)
	_lands(1, "Forest", 4)
	for window in ["MAIN", "SINK", "UPKEEP"]:
		assert_eq(UT.option(g, ai, crescendo, 0, window), {}, window)


func test_rumbling_crescendo_takes_three_lands() -> void:
	var ai := _ai()
	_charged(0, "Rumbling Crescendo", 3)
	_lands(0, "Mountain", 1)
	_lands(1, "Forest", 5)
	assert_eq(_act_until(ai, "Rumbling Crescendo"), "activated Rumbling Crescendo")
	resolve_stack()
	var left := 0
	for inst in g.players[1].battlefield:
		if inst.is_land(): left += 1
	assert_eq(left, 2)


# ------------------------------------------------------------ Lilting Refrain --

## Their main phase: they cast a Shivan Dragon with [param untapped]
## Mountains left open, and pass; seat 0 holds priority over it.
func _they_cast_a_dragon(untapped: int) -> CardInstance:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	_lands(1, "Mountain", untapped)
	var dragon := give_hand(1, "Shivan Dragon")
	add_mana(1, Mtg.ManaColor.R, 2)
	add_mana(1, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(1, dragon))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return dragon


func test_lilting_refrain_counters_what_they_cannot_pay_for() -> void:
	var ai := _ai()
	_charged(0, "Lilting Refrain", 2)
	var dragon := _they_cast_a_dragon(0)
	assert_eq(ai.act(g), "activated Lilting Refrain")
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD)


func test_lilting_refrain_is_not_wasted_on_open_mana() -> void:
	var ai := _ai()
	var refrain := _charged(0, "Lilting Refrain", 2)
	_they_cast_a_dragon(3)
	assert_eq(UT.option(g, ai, refrain, 0, "RESPONSE"), {})
	assert_ne(ai.act(g), "activated Lilting Refrain")


func test_the_refrain_ignores_their_hidden_hand() -> void:
	var answers: Array[String] = []
	for filler in ["Grizzly Bears", "Counterspell"]:
		before_each()
		var ai := _ai()
		_charged(0, "Lilting Refrain", 2)
		give_hand(1, filler)
		_restack(1, [filler, "Mountain"])
		_they_cast_a_dragon(0)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1])


# ----------------------------------------------------------- Discordant Dirge --

func test_discordant_dirge_waits_until_x_covers_their_hand() -> void:
	var ai := _ai()
	var dirge := _charged(0, "Discordant Dirge", 1)
	_lands(0, "Swamp", 1)
	for n in ["Grizzly Bears", "Hill Giant"]: give_hand(1, n)
	assert_eq(UT.option(g, ai, dirge, 0, "MAIN"), {})
	g.add_counters(dirge, "verse", 1)
	var opt: Variant = UT.option(g, ai, dirge, 0, "MAIN")
	assert_false((opt as Dictionary).is_empty(), "two verses for two cards")


## Their hand's SIZE is public, its contents are not: two different hands of
## the same size, the same answer.
func test_the_dirge_reads_their_hand_size_only() -> void:
	var answers: Array = []
	for pair in [["Grizzly Bears", "Hill Giant"], ["Shivan Dragon", "Counterspell"]]:
		before_each()
		var ai := _ai()
		var dirge := _charged(0, "Discordant Dirge", 2)
		_lands(0, "Swamp", 1)
		for n in pair: give_hand(1, n)
		_restack(1, [pair[0], "Forest"])
		answers.append(str(UT.option(g, ai, dirge, 0, "MAIN")))
	assert_eq(answers[0], answers[1])


# -------------------------------------------------- Barrin's Codex, Powder Keg --

func test_barrins_codex_waits_for_three_pages() -> void:
	var ai := _ai()
	var book := _charged(0, "Barrin's Codex", 2, "page")
	_lands(0, "Island", 4)
	assert_eq(UT.option(g, ai, book, 0, "MAIN"), {})
	g.add_counters(book, "page", 1)
	assert_eq(_act_until(ai, "Barrin's Codex"), "activated Barrin's Codex")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 3)


func test_powder_keg_blows_when_their_side_loses_more() -> void:
	var ai := _ai()
	_charged(0, "Powder Keg", 2, "fuse")
	var bears := put_battlefield(1, "Grizzly Bears")
	var other := put_battlefield(1, "Grizzly Bears")
	assert_eq(_act_until(ai, "Powder Keg"), "activated Powder Keg")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD)


func test_powder_keg_spares_a_board_that_costs_us_as_much() -> void:
	var ai := _ai()
	var keg := _charged(0, "Powder Keg", 2, "fuse")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	assert_eq(UT.option(g, ai, keg, 0, "MAIN"), {})


# ----------------------------------------------------------------- War Dance --

func test_war_dance_wins_the_fight_our_bears_would_lose() -> void:
	var ai := _ai()
	_charged(0, "War Dance", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(1, {giant.id: bears.id}))
	guard = 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(ai.act(g), "activated War Dance")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_war_dance_is_not_spent_in_the_main_phase() -> void:
	var ai := _ai()
	var dance := _charged(0, "War Dance", 3)
	put_battlefield(0, "Grizzly Bears")
	assert_eq(UT.option(g, ai, dance, 0, "MAIN"), {})
