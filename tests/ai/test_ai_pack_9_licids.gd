extends GameTest
## LICIDS AND VOLRATH'S CURSE, READ BY THE FAIR AI (Pack 9, engine package
## E3; CR 116.2c-d; [member AiProfile.forecasts_tactics];
## engine/ai/tempest_tactics.gd).
##
## E3 pinned the minimum (a licid dresses OUR attacker:
## tests/unit/test_pack_9_engine_E3_ai.gd). This file pins the rest:
##  * a licid whose Aura half hurts its host goes on THEIR creature — the
##    steal on their best creature, "can't block" on the blocker that holds
##    our attacker back, "can't attack" on the flier our life cannot afford;
##  * the effect is ENDED (the special action) when the host is about to
##    leave — their removal names the host or the licid, or the host dies
##    in the combat damage — so the licid lives on as a creature; a steal
##    with a healthy host is never ended;
##  * Volrath's Curse is ignored (a permanent sacrificed) only for an
##    attack worth more than the cheapest body — a lethal one.
## The null arm (gate off) does none of it; the opponent's hidden hand and
## library do not move a decision.


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


func _lands(name: String, n: int, seat := 0) -> void:
	for _i in n: put_battlefield(seat, name)


## Seat 1's main phase, seat 1 holding priority.
func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


## Seat 1 casts [param spell] at [param target] in its main phase; seat 0
## holds priority over it.
func _they_cast_at(spell: String, target: CardInstance, colours: Array) -> CardInstance:
	_their_main()
	var card := give_hand(1, spell)
	for c in colours: add_mana(1, c)
	assert_ok(g.cast_spell(1, card, [TargetRef.card(target)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return card


# ------------------------------------------------------- their creature --

func test_dominating_licid_steals_their_best_creature() -> void:
	var ai := _ai()
	var licid := put_battlefield(0, "Dominating Licid")
	_lands("Island", 3)
	var angel := put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Dominating Licid")
	resolve_stack()
	assert_true(g.is_licid_aura(licid))
	assert_eq(licid.attached_to, angel.id)
	assert_eq(angel.controller_id, 0, "you control enchanted creature")


func test_the_null_arm_never_steals() -> void:
	var ai := _ai(false)
	var licid := put_battlefield(0, "Dominating Licid")
	_lands("Island", 3)
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_false(g.is_licid_aura(licid))


func test_convulsing_licid_takes_the_wall_out_of_the_way() -> void:
	var ai := _ai()
	var licid := put_battlefield(0, "Convulsing Licid")
	put_battlefield(0, "Craw Wurm")
	_lands("Mountain", 1)
	var wall := put_battlefield(1, "Wall of Stone")
	g.players[1].life = 12
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Convulsing Licid")
	resolve_stack()
	assert_eq(licid.attached_to, wall.id, "the wall can't block")


func test_calming_licid_grounds_the_flier_our_life_cannot_afford() -> void:
	var ai := _ai()
	var licid := put_battlefield(0, "Calming Licid")
	_lands("Plains", 1)
	var angel := put_battlefield(1, "Serra Angel")
	g.players[0].life = 6
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Calming Licid")
	resolve_stack()
	assert_eq(licid.attached_to, angel.id)


## (Calming Licid on a Serra Angel is now ACTIVATED — the Pack 9 study's fix;
## the even-board case is test_ai_pack_9_fixes_auras.gd.)

func test_the_steal_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Dominating Licid")
		_lands("Island", 3)
		put_battlefield(1, "Serra Angel")
		put_battlefield(1, "Grizzly Bears")
		give_hand(1, "Disenchant" if variant == 0 else "Terror")
		g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(ai.act(g))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")


# --------------------------------------------------------- the end action --

## Our Hill Giant wearing our Gliding Licid, an Island open for its {U}.
func _dressed_giant() -> Array:
	var giant := put_battlefield(0, "Hill Giant")
	var licid := put_battlefield(0, "Gliding Licid")
	_lands("Island", 1)
	assert_true(g.become_licid_aura(licid, giant))
	assert_true(giant.has_keyword(Mtg.Keyword.FLYING))
	return [giant, licid]


func test_the_licid_leaves_a_host_their_terror_is_killing() -> void:
	var ai := _ai()
	var pair := _dressed_giant()
	var licid: CardInstance = pair[1]
	_they_cast_at("Terror", pair[0], [Mtg.ManaColor.B, Mtg.ManaColor.C])
	assert_string_contains(ai.act(g), "ends Gliding Licid's effect")
	assert_false(g.is_licid_aura(licid))
	resolve_stack()
	assert_eq((pair[0] as CardInstance).zone, Mtg.Zone.GRAVEYARD)
	assert_eq(licid.zone, Mtg.Zone.BATTLEFIELD, "a creature again, the Aura SBA never reached it")


func test_the_licid_dodges_a_disenchant() -> void:
	var ai := _ai()
	var pair := _dressed_giant()
	var licid: CardInstance = pair[1]
	_they_cast_at("Disenchant", licid, [Mtg.ManaColor.W, Mtg.ManaColor.C])
	assert_string_contains(ai.act(g), "ends Gliding Licid's effect")
	resolve_stack()
	assert_eq(licid.zone, Mtg.Zone.BATTLEFIELD, "no longer an enchantment: the target is gone")


func test_the_null_arm_lets_the_licid_die_with_its_host() -> void:
	var ai := _ai(false)
	var pair := _dressed_giant()
	var licid: CardInstance = pair[1]
	_they_cast_at("Terror", pair[0], [Mtg.ManaColor.B, Mtg.ManaColor.C])
	assert_false(ai.act(g).contains("ends"))
	resolve_stack()
	assert_eq(licid.zone, Mtg.Zone.GRAVEYARD)


func test_a_healthy_steal_is_never_ended() -> void:
	var ai := _ai()
	var licid := put_battlefield(0, "Dominating Licid")
	_lands("Island", 2)
	var angel := put_battlefield(1, "Serra Angel")
	assert_true(g.become_licid_aura(licid, angel))
	assert_eq(angel.controller_id, 0)
	_their_main()
	assert_ok(g.pass_priority(1))
	var guard := 0
	while not (g.current_step() == Mtg.Step.END and g.priority_player == 0) and guard < 60:
		if g.priority_player == 0:
			var line := ai.act(g)
			assert_false(line.contains("ends"), line)
		else:
			_advance_once()
		guard += 1
	assert_false(ai.act(g).contains("ends"))
	assert_true(g.is_licid_aura(licid))


# ---------------------------------------------------------- the Curse --

func _cursed(name: String) -> CardInstance:
	var body := put_battlefield(0, name)
	var curse := give_hand(1, "Volrath's Curse")
	g.attach_aura_from_anywhere(curse, body, 1)
	g.recalculate()
	assert_true(body.cur_cant_attack)
	return body


func test_the_curse_is_ignored_for_a_lethal_attack() -> void:
	var ai := _ai()
	var angel := _cursed("Serra Angel")
	_lands("Plains", 3)
	g.players[1].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "ignores Volrath's Curse")
	assert_false(angel.cur_cant_attack)
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	var lands := 0
	for p in g.players[0].battlefield:
		if p.is_land(): lands += 1
	assert_eq(lands, 2, "a Plains was the price")


func test_the_curse_is_not_ignored_for_two_points() -> void:
	var ai := _ai()
	_cursed("Grizzly Bears")
	_lands("Plains", 3)
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(ai.act(g).contains("ignores"))


func test_the_null_arm_never_ignores_the_curse() -> void:
	var ai := _ai(false)
	_cursed("Serra Angel")
	_lands("Plains", 3)
	g.players[1].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(ai.act(g).contains("ignores"))
