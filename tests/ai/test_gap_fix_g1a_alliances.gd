extends GameTest
## GAP FIX G1a (gap review 2026-11-10, r1a-3): Phelddagrif's gifts.
##
## "{G}: Phelddagrif gains trample until end of turn. Target opponent
## creates a 1/1 green Hippo creature token. {W}: Phelddagrif gains flying
## until end of turn. Target opponent gains 2 life." The Alliances arm
## ([method AlliancesTactics.option], the `self_keyword_gift` shape) priced
## both at a flat 3.5 and never charged the gift: a permanent Hippo was
## handed over for one point of trample, and flying was bought (2 life for
## them) against a Storm Crow, which blocks a flyer as well as a walker.
##
## Now an evasion keyword is bought only when it escapes every creature of
## theirs that could block (asked under the search journal), trample is
## priced by the damage it pushes through, and the gift is charged. The
## whole module is [member AiProfile.forecasts_tactics]; its null is the
## shared scorer. Public board only.

const A := preload("res://engine/ai/alliances_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-5", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-5", false)
	CardPacks.set_enabled(CardPacks.ID, false)


func pilot(forecasts := true) -> AiPlayer:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.profile.develops_late = false
	ai.profile.forecasts_tactics = forecasts
	g.set_agent(0, ai)
	return ai


func _attack(grif: CardInstance, blocks: Dictionary = {}) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [grif.id]))
	resolve_stack()
	if not blocks.is_empty():
		advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
		assert_ok(g.declare_blockers(1, blocks))
		if g.priority_player == 1: assert_ok(g.pass_priority(1))


func _tokens(pid: int) -> int:
	var n := 0
	for body in g.players[pid].battlefield:
		if body.is_token: n += 1
	return n


static func _digest(option: Dictionary) -> Array:
	if option.is_empty(): return []
	return [snappedf(float(option["value"]), 0.001), option.get("targets", []).size()]


func test_no_flying_against_a_flying_blocker() -> void:
	var grif := put_battlefield(0, "Phelddagrif")
	put_battlefield(1, "Storm Crow")   # 1/2 flyer: blocks a flyer as well as a walker
	for _i in 2: put_battlefield(0, "Plains")
	_attack(grif)
	var ai := pilot()
	assert_true(ai._ability_option(g, grif, 1, AiPlayer.Moment.RESPONSE).is_empty(),
		"flying escapes nothing from a Storm Crow; it only gives them 2 life")
	assert_false(grif.has_keyword(Mtg.Keyword.FLYING), "the journal test leaves no flying behind")
	assert_null(g.undo_log, "and no search open")
	ai.act(g)
	resolve_stack()
	assert_eq(g.players[1].life, 20, "no gift of life")


func test_flying_over_a_ground_blocker_is_still_bought() -> void:
	var grif := put_battlefield(0, "Phelddagrif")
	put_battlefield(1, "Grizzly Bears")
	for _i in 2: put_battlefield(0, "Plains")
	_attack(grif)
	var ai := pilot()
	var option := ai._ability_option(g, grif, 1, AiPlayer.Moment.RESPONSE)
	assert_true(not option.is_empty() and float(option["value"]) >= AiPlayer.ABILITY_BAR_UPKEEP,
		"four sure damage past the Bears is worth their 2 life")
	assert_false(grif.has_keyword(Mtg.Keyword.FLYING), "the journal test leaves no flying behind")


func test_no_hippo_for_one_point_of_trample() -> void:
	var grif := put_battlefield(0, "Phelddagrif")   # 4/4
	var giant := put_battlefield(1, "Hill Giant")    # 3/3: one point tramples over
	for _i in 2: put_battlefield(0, "Forest")
	_attack(grif, {giant.id: grif.id})
	var ai := pilot()
	assert_true(ai._ability_option(g, grif, 0, AiPlayer.Moment.RESPONSE).is_empty())
	ai.act(g)
	resolve_stack()
	assert_eq(_tokens(1), 0, "a permanent 1/1 for them is dearer than one trample point at 20 life")


func test_no_hippo_for_two_points_at_twenty_life() -> void:
	var grif := put_battlefield(0, "Phelddagrif")
	var bears := put_battlefield(1, "Grizzly Bears")
	for _i in 2: put_battlefield(0, "Forest")
	_attack(grif, {bears.id: grif.id})
	var ai := pilot()
	var option := ai._ability_option(g, grif, 0, AiPlayer.Moment.RESPONSE)
	assert_true(option.is_empty() or float(option["value"]) < AiPlayer.ABILITY_BAR_UPKEEP,
		"two points of their twenty do not pay for a body that blocks next turn")
	ai.act(g)
	resolve_stack()
	assert_eq(_tokens(1), 0, "no Hippo")
	assert_false(grif.has_keyword(Mtg.Keyword.TRAMPLE))


func test_lethal_trample_is_bought_whatever_the_gift() -> void:
	var grif := put_battlefield(0, "Phelddagrif")
	var giant := put_battlefield(1, "Hill Giant")
	g.players[1].life = 1
	for _i in 2: put_battlefield(0, "Forest")
	_attack(grif, {giant.id: grif.id})
	var ai := pilot()
	var option := ai._ability_option(g, grif, 0, AiPlayer.Moment.RESPONSE)
	assert_false(option.is_empty(), "the point over the Giant is their last")
	assert_gte(float(option.get("value", 0.0)), AiPlayer.LETHAL_WORTH - 10.0)


func test_the_module_null_is_untouched() -> void:
	var grif := put_battlefield(0, "Phelddagrif")
	put_battlefield(1, "Storm Crow")
	_attack(grif)
	var ai := pilot(false)
	assert_null(A.option(g, ai, grif, 1, "RESPONSE"), "forecasts_tactics off: the shared scorer, as before")


func test_the_gift_reads_no_hidden_card() -> void:
	var grif := put_battlefield(0, "Phelddagrif")
	put_battlefield(1, "Grizzly Bears")
	var hidden := give_hand(1, "Giant Growth")
	for _i in 2: put_battlefield(0, "Plains")
	_attack(grif)
	var ai := pilot()
	var before := _digest(ai._ability_option(g, grif, 1, AiPlayer.Moment.RESPONSE))
	hidden.data = CardRegistry.get_card("Storm Crow")
	assert_eq(_digest(ai._ability_option(g, grif, 1, AiPlayer.Moment.RESPONSE)), before,
		"a flyer in their HAND is not a blocker on the table")
	assert_false(before.is_empty())
