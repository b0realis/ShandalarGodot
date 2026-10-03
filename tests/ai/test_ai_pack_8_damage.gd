extends GameTest
## THE DAMAGE SUITE, READ BY THE FAIR AI (Pack 8, 2026-10-03; engine
## package E5; [member AiProfile.forecasts_tactics]).
##
##  * KILLS ARE PREDICTED where the table changes damage: burn aimed by
##    [method AiPlayer._kills_by_damage] and combat read by
##    [method AiPlayer._dies_to] ask [method MtgGame.predict_damage] with
##    OUR seat as the viewer (a face-down creature stays the 2/2 it shows)
##    whenever a damage-replacement entry is on the table — a Benevolent
##    Unicorn's "minus 1", Blind Fury's double.
##  * THE SOURCE SHIELD (Honorable Passage, Shadowbane, Circle of Despair)
##    answers a burn spell aimed at what it covers, and their combat when
##    the damage through is lethal (mirage_tactics.gd `shield_response`).
##  * THE RANSOM: Sabertooth Cobra's {2} is paid at their end step.
##  * TORRENT OF LAVA'S SHIELD: a creature the sweep kills by exactly one
##    point taps for the point.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) and guard < 400:
		_advance_once()
		guard += 1


func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


static func _creature_to_creature(_g: MtgGame, p: DamagePacket) -> bool:
	return p.source.is_creature() and not p.target.is_player


# ---------------------------------------------------- the predicted kill --

func test_a_bolt_is_not_aimed_where_the_unicorn_saves_it() -> void:
	# The Unicorn (ours — it shaves every spell's damage, both sides of the
	# table) makes the Bolt a two: no kill on a 3/3, so the face.
	var ai := _ai()
	put_battlefield(0, "Benevolent Unicorn")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(0, "Lightning Bolt")
	var e: EffectBase = bolt.data.spell_effects[0]
	var pick: TargetRef = ai._pick_for_spec(g, bolt, e.target_spec, e, 0)
	assert_not_null(pick)
	assert_true(pick.is_player, "three minus one does not kill a 3/3")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


func test_null_arm_aims_at_the_giant() -> void:
	var ai := _ai(_null())
	put_battlefield(0, "Benevolent Unicorn")
	var giant := put_battlefield(1, "Hill Giant")
	var bolt := give_hand(0, "Lightning Bolt")
	var e: EffectBase = bolt.data.spell_effects[0]
	var pick: TargetRef = ai._pick_for_spec(g, bolt, e.target_spec, e, 0)
	assert_eq(pick.instance_id, giant.id, "the pilot as it was")


func test_blind_fury_doubles_what_the_combat_reads() -> void:
	var ai := _ai()
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	assert_false(ai._dies_to(g, giant, bears), "2 into a 3/3")
	g.add_damage_effect({"kind": &"modify", "factor": 2, "combat_only": true,
		"controller": 1, "card": "Blind Fury", "desc": "test double",
		"filter": _creature_to_creature})
	assert_true(ai._dies_to(g, giant, bears), "4 into a 3/3")


func test_the_prediction_reads_a_face_down_body_as_its_face() -> void:
	# Fairness: our seat as the viewer sees a face-down creature of theirs
	# as a 2/2 — the prediction does not read its hidden printed card.
	var ai := _ai()
	var hidden := put_battlefield(1, "Craw Wurm")
	hidden.face_down = true
	g.recalculate()
	var bolt := give_hand(0, "Lightning Bolt")
	var told := g.predict_damage(bolt, TargetRef.card(hidden), 3, false, -1, 0)
	assert_true(bool(told["dies"]), "a 2/2 to our eyes")
	assert_not_null(ai)


# --------------------------------------------------------- the shields --

func test_honorable_passage_turns_a_bolt_around() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var giant := put_battlefield(0, "Hill Giant")
	var passage := give_hand(0, "Honorable Passage")
	_their_main()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(giant)]))
	assert_ok(g.pass_priority(1))
	assert_string_contains(ai.act(g), "Honorable Passage")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "the Bolt's damage was prevented")
	assert_eq(g.players[1].life, 17, "red: dealt back to its controller")
	assert_eq(passage.zone, Mtg.Zone.GRAVEYARD)


func test_shadowbane_stops_a_lethal_attacker() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	give_hand(0, "Shadowbane")
	var wurm := put_battlefield(1, "Craw Wurm")
	g.players[0].life = 6
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [wurm.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		if g.priority_player == 0: ai.act(g)
		else: assert_ok(g.pass_priority(1))
		guard += 1
	assert_ok(g.declare_blockers(0, {}))
	assert_ok(g.pass_priority(1))
	assert_string_contains(ai.act(g), "Shadowbane")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 6, "the Wurm's six were prevented")


func test_no_shield_spent_on_damage_that_kills_nothing() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var angel := put_battlefield(0, "Serra Angel")
	var passage := give_hand(0, "Honorable Passage")
	_their_main()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(angel)]))
	assert_ok(g.pass_priority(1))
	ai.act(g)
	assert_eq(passage.zone, Mtg.Zone.HAND, "a 4/4 lives through three")


# ------------------------------------------------------------ the ransom --

func test_the_cobra_s_ransom_is_paid_at_their_end_step() -> void:
	var ai := _ai()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var cobra := put_battlefield(1, "Sabertooth Cobra")
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [cobra.id]))
	guard = 0
	while g.current_step() != Mtg.Step.END and guard < 60:
		if g.awaiting_blockers: assert_ok(g.declare_blockers(0, {}))
		elif g.priority_player == 0: ai.act(g)
		else: assert_ok(g.pass_priority(1))
		guard += 1
	assert_eq(g.players[0].poison, 1, "the bite")
	assert_false(g.settleable_delayed_triggers(0).is_empty(), "the ransom is due")
	assert_ok(g.pass_priority(1))
	assert_string_contains(ai.act(g), "pays")
	assert_true(g.settleable_delayed_triggers(0).is_empty())
	advance_to_next_turn()
	assert_eq(g.players[0].poison, 1, "no second counter at our upkeep")


# ------------------------------------------------------ the torrent shield --

func test_a_creature_taps_out_of_a_torrent_of_lava() -> void:
	var ai := _ai()
	var giant := put_battlefield(0, "Hill Giant")
	_their_main()
	var torrent := give_hand(1, "Torrent of Lava")
	add_mana(1, Mtg.ManaColor.R, 2)
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(1, torrent, [], 3))
	assert_ok(g.pass_priority(1))
	assert_string_contains(ai.act(g), "Hill Giant")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "three minus the one it prevented")
	assert_true(giant.tapped)


# ------------------------------------- a shield is a RESPONSE (audit, A) --
#
# The Pack 8 duel audit (seed 87000): Reflect Damage was cast six times and
# Shadowbane twice, all in the pilot's own main phase, naming a LAND as the
# source ("Reflect Damage watches Mountain") — not one point stopped. The
# card-local shield read as an unknown, untargeted spell and the main
# planner cast it for its printed worth. A "source of your choice" shield
# is held for the damage it answers, and the source it names is one that
# can deal damage.

func _shield_lands() -> void:
	for _i in 3: put_battlefield(0, "Plains")
	for _i in 2: put_battlefield(0, "Mountain")


func test_reflect_damage_is_never_cast_into_an_empty_main_phase() -> void:
	var ai := _ai()
	_shield_lands()
	var reflect := give_hand(0, "Reflect Damage")
	var shadowbane := give_hand(0, "Shadowbane")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 4: ai.act(g)
	assert_eq(reflect.zone, Mtg.Zone.HAND, "nothing is threatening: held")
	assert_eq(shadowbane.zone, Mtg.Zone.HAND)


func test_reflect_damage_turns_their_big_attacker_around() -> void:
	var ai := _ai()
	_shield_lands()
	var reflect := give_hand(0, "Reflect Damage")
	var wurm := put_battlefield(1, "Craw Wurm")
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [wurm.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		if g.priority_player == 0: ai.act(g)
		else: assert_ok(g.pass_priority(1))
		guard += 1
	assert_ok(g.declare_blockers(0, {}))
	assert_ok(g.pass_priority(1))
	assert_string_contains(ai.act(g), "Reflect Damage")
	resolve_stack()
	assert_string_contains(g.damage_effect(g.damage_effects[0]["id"]).get("desc", ""), "Craw Wurm",
		"the source named is the attacker, never a land")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "the Wurm's six went to its controller")
	assert_eq(g.players[1].life, 14)
	assert_eq(reflect.zone, Mtg.Zone.GRAVEYARD)


func test_a_source_question_never_names_a_land() -> void:
	var ai := _ai()
	var land := put_battlefield(1, "Mountain")
	var bears := put_battlefield(1, "Grizzly Bears")
	var asked: Array[CardInstance] = [land, bears]
	var picked := ai.choose_card(g, 0, asked, "Reflect Damage: Select a source.", false, false, true)
	assert_eq(picked, bears, "the land is ranked first by nothing that can deal damage")


func test_one_shield_per_source() -> void:
	# The audit: Shadowbane and then Reflect Damage on the same Canopy
	# Dragon — the second watched nothing. With a shield already waiting
	# for the attacker, the second card stays in hand.
	var ai := _ai()
	_shield_lands()
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var reflect := give_hand(0, "Reflect Damage")
	var shadowbane := give_hand(0, "Shadowbane")
	var wurm := put_battlefield(1, "Craw Wurm")
	g.players[0].life = 6
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [wurm.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		if g.priority_player == 0: ai.act(g)
		else: assert_ok(g.pass_priority(1))
		guard += 1
	assert_ok(g.declare_blockers(0, {}))
	assert_ok(g.pass_priority(1))
	var first := ai.act(g)
	resolve_stack()
	assert_true(first.contains("Shadowbane") or first.contains("Reflect Damage"), first)
	if g.priority_player == 1:
		assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS)
	var second := ai.act(g)
	assert_false(second.contains("Shadowbane") or second.contains("Reflect Damage"),
		"the Wurm is already watched: %s" % second)
	assert_true(reflect.zone == Mtg.Zone.HAND or shadowbane.zone == Mtg.Zone.HAND)
