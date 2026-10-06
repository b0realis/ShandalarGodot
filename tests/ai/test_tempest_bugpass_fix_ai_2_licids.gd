extends GameTest
## THE PACK 9 BUG PASS, fix-ai-2 — licids and Volrath's Curse, read by the
## fair AI (engine/ai/tempest_tactics.gd; [member AiProfile.forecasts_tactics]):
##  * h3-2 (the curse_action half): the Curse's ignore is priced against
##    the body the sacrifice actually takes — the cheapest permanent the
##    engine offers other than the cursed creature — read GONE from the
##    attack it pays for (a creature the cost eats is no attacker);
##  * h3-3: a Nurturing Licid's host that "{G}: Regenerate enchanted
##    creature" can still shield is regenerated, not abandoned by ending
##    the licid's effect (a Terror, which forbids regeneration, still ends
##    it);
##  * h3-4: a Dominating Licid's stolen creature dying in a block FOR US is
##    not handed back alive by ending the steal.
## Null arms (gate off) and a hidden-information permutation.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
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


## Seat 1's main phase, seat 1 holding priority.
func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


func _they_cast_at(spell: String, target: CardInstance, colours: Array) -> CardInstance:
	_their_main()
	var card := give_hand(1, spell)
	for c in colours: add_mana(1, c)
	assert_ok(g.cast_spell(1, card, [TargetRef.card(target)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return card


func _cursed(pid: int, card_name: String) -> Array:
	var body := put_battlefield(pid, card_name)
	var curse := give_hand(1 - pid, "Volrath's Curse")
	g.attach_aura_from_anywhere(curse, body, 1 - pid)
	g.recalculate()
	assert_true(body.cur_cant_attack)
	return [body, curse]


# ------------------------------------------------------------- h3-2: the Curse --

## The probe's board: the cursed Lions and one Plains, their life 2. The
## ignore frees a lethal attack; the Plains is its price, never the Lions.
## (The cost question's own pick is fix-ai-1's half: AiPlayer.answer_card.)
func test_the_curse_ignore_does_not_sacrifice_the_freed_attacker() -> void:
	var ai := _ai()
	var pair := _cursed(0, "Savannah Lions")
	var lions: CardInstance = pair[0]
	put_battlefield(0, "Plains")
	g.players[1].life = 2
	advance_to_step(Mtg.Step.MAIN1)
	var line := ai.act(g)
	assert_string_contains(line, "ignores Volrath's Curse")
	assert_eq(lions.zone, Mtg.Zone.BATTLEFIELD,
		"the attacker the ignore was bought for must not be its price (line: %s)" % line)


## The price is the body the cost takes: with the Bears the cheapest other
## body, the Lions freed and the Bears sacrificed attack for 2 — not the 4
## the two of them would deal. Not lethal, not worth a creature.
func test_the_curse_is_priced_with_the_sacrificed_body_gone() -> void:
	var ai := _ai()
	var pair := _cursed(0, "Savannah Lions")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.players[1].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	var tactics := preload("res://engine/ai/tempest_tactics.gd")
	assert_eq(tactics.curse_price_body(g, ai, pair[1], pair[0]), bears,
		"the cheapest body other than the cursed Lions")
	var line := tactics.curse_action(g, ai)
	assert_eq(line, "", "the Bears' sacrifice leaves a 2-point attack at 4 life")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_null(g.undo_log, "the pricing left no journal open")
	assert_eq(g.players[0].battlefield.size(), 2, "the pricing left the board as it was")


func test_the_curse_with_only_its_host_to_give_is_never_ignored() -> void:
	var ai := _ai()
	_cursed(0, "Serra Angel")
	g.players[1].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(ai.act(g).contains("ignores"), "the Angel is the only body: nothing to pay with")


func test_the_null_arm_never_ignores_the_curse() -> void:
	var ai := _ai(false)
	_cursed(0, "Savannah Lions")
	put_battlefield(0, "Plains")
	g.players[1].life = 2
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(ai.act(g).contains("ignores"))


func test_the_curse_answer_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		_cursed(0, "Savannah Lions")
		put_battlefield(0, "Grizzly Bears")
		g.players[1].life = 4
		give_hand(1, "Fog" if variant == 0 else "Lightning Bolt")
		if variant == 1: g.players[1].library.reverse()
		advance_to_step(Mtg.Step.MAIN1)
		answers.append(preload("res://engine/ai/tempest_tactics.gd").curse_action(g, ai))
	assert_eq(answers[0], answers[1], "hidden cards changed the answer")


# ------------------------------------------------- h3-3: Nurturing Licid's host --

func _nurtured_giant() -> Array:
	var giant := put_battlefield(0, "Hill Giant")
	var licid := put_battlefield(0, "Nurturing Licid")
	var forest := put_battlefield(0, "Forest")
	assert_true(g.become_licid_aura(licid, giant))
	return [giant, licid, forest]


func test_nurturing_licid_regenerates_a_host_a_bolt_would_kill() -> void:
	var ai := _ai()
	var pair := _nurtured_giant()
	var giant: CardInstance = pair[0]
	var licid: CardInstance = pair[1]
	_they_cast_at("Lightning Bolt", giant, [Mtg.ManaColor.R])
	var line := ai.act(g)
	assert_false(line.contains("ends Nurturing Licid's effect"), line)
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "{G} regenerates the Giant; the AI did: %s" % line)
	assert_true(g.is_licid_aura(licid), "the Aura stays on its host")


func test_nurturing_licid_still_leaves_a_host_a_terror_is_killing() -> void:
	var ai := _ai()
	var pair := _nurtured_giant()
	var licid: CardInstance = pair[1]
	_they_cast_at("Terror", pair[0], [Mtg.ManaColor.B, Mtg.ManaColor.C])
	assert_string_contains(ai.act(g), "ends Nurturing Licid's effect",
		"Terror forbids regeneration: the licid saves itself")
	resolve_stack()
	assert_eq(licid.zone, Mtg.Zone.BATTLEFIELD)


## In a combat the same: the Giant blocking their Craw Wurm dies in the
## damage about to be dealt, and {G} regenerates it — the Aura stays.
func test_nurturing_licid_regenerates_a_host_dying_in_a_block() -> void:
	var ai := _ai()
	var pair := _nurtured_giant()
	var giant: CardInstance = pair[0]
	var licid: CardInstance = pair[1]
	_their_main()
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [wurm.id]))
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(0, {giant.id: wurm.id}))
	guard = 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	var lines: Array = []
	guard = 0
	while g.current_step() == Mtg.Step.DECLARE_BLOCKERS and not g.game_over and guard < 10:
		if g.priority_player == 0:
			var line := ai.act(g)
			lines.append(line)
			if line == "" or line == "pass":
				if g.priority_player == 0 and g.current_step() == Mtg.Step.DECLARE_BLOCKERS:
					assert_ok(g.pass_priority(0))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_false(str(lines).contains("ends Nurturing Licid's effect"), str(lines))
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "regenerated: %s" % [lines])
	assert_true(g.is_licid_aura(licid))


func test_the_null_arm_does_not_end_the_nurturing_licid() -> void:
	var ai := _ai(false)
	var pair := _nurtured_giant()
	_they_cast_at("Lightning Bolt", pair[0], [Mtg.ManaColor.R])
	assert_false(ai.act(g).contains("ends"))


# ---------------------------------------------- h3-4: Dominating Licid's steal --

func _stolen_bears_blocking() -> Array:
	var licid := put_battlefield(0, "Dominating Licid")
	put_battlefield(0, "Island")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_true(g.become_licid_aura(licid, bears))
	assert_eq(bears.controller_id, 0)
	_their_main()
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(0, {bears.id: giant.id}))
	guard = 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	return [licid, bears, giant]


func test_dominating_licid_does_not_hand_back_the_creature_dying_for_us() -> void:
	var ai := _ai()
	var trio := _stolen_bears_blocking()
	var bears: CardInstance = trio[1]
	var line := ai.act(g)
	assert_false(line.contains("ends Dominating Licid's effect"),
		"the stolen Bears dies blocking for us; ended, it goes home alive (line: %s)" % line)
	# The AI's pass ends the step: the combat damage is dealt. Kept, the
	# steal ends with the Bears' death (an owner's graveyard, CR 400.3);
	# ended, the Bears would be back on their battlefield, alive.
	var guard := 0
	while g.current_step() == Mtg.Step.DECLARE_BLOCKERS and not g.game_over and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "line: %s" % line)


func test_the_null_arm_keeps_the_steal_in_the_block() -> void:
	var ai := _ai(false)
	_stolen_bears_blocking()
	assert_false(ai.act(g).contains("ends"))
