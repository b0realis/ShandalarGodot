extends GameTest
## WHO ORDERS THE DAMAGE EFFECTS — a rules fork (the owner's ruling of
## 2026-10-12, campaign 2026-10-12 f-order).
##
## When several replacement and prevention effects would modify the same
## damage, the order can change what lands. A Lightning Bolt into a
## Forethought Amulet ("if an instant or sorcery source would deal 3 or
## more damage to you, it deals 2 damage to you instead") and a Furnace of
## Rath ("double that damage"): the Amulet first gives 4, the Furnace first
## gives 2.
##
## The owner's ruling keeps both answers as a switch
## (`RulesOptions.damage_effects_fixed_order`):
##  * the 1997 game asked nobody — a fixed order (the "1997 — Fifth
##    Edition" preset);
##  * modern Magic, CR 616.1, puts it to the affected player or the
##    affected creature's controller, and then the rule is applied again
##    (both modern presets).
##
## Both branches of MtgGame._land_damage_impl walk it — the player branch
## and the creature branch — and both are pinned here, with the engine's
## look-ahead for agents (MtgGame.damage_order_outcomes) and the question
## a person is shown.

const PACKS := ["pack-9"]
const MODERN := ["modern_mana_burn", "modern"]
const DOUBLED := "Furnace of Rath: the damage is doubled"


## Answers the ordering question with the line whose label contains
## [param want] (the hint when none does, or when [param want] is ""),
## and records every question: its prompt and its lines.
class Orderer extends DecisionAgent:
	var want := ""
	var prompts: Array[String] = []
	var asked: Array = []
	var forecasts: Array = []
	var look_ahead := false
	var picks: Array = []

	func answer_option(game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		prompts.append(prompt)
		asked.append(Array(options))
		if look_ahead:
			forecasts.append(game.damage_order_outcomes())
		if not picks.is_empty():
			var wanted := String(picks.pop_front())
			for i in options.size():
				if options[i].contains(wanted):
					return i
			return hint
		if want == "":
			return hint
		for i in options.size():
			if options[i].contains(want):
				return i
		return hint


func before_each() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	CardRegistry.ensure_loaded()
	super.before_each()


func after_each() -> void:
	g = null
	for p in PACKS: CardPacks.set_enabled(p, false)


func _fresh(preset: String) -> Orderer:
	super.before_each()
	g.rules.set_preset(preset)
	var orderer := Orderer.new()
	g.set_agent(0, orderer)
	advance_to_step(Mtg.Step.MAIN1)
	return orderer


## P1, with a Furnace of Rath, aims a Lightning Bolt at [param target].
func _bolt(target: TargetRef) -> void:
	put_battlefield(1, "Furnace of Rath")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [target]))
	resolve_stack()


# ======================================================== the fork itself ==

func test_the_1997_preset_fixes_the_order_and_both_modern_presets_ask() -> void:
	var options := RulesOptions.new()
	assert_false(options.damage_effects_fixed_order, "the engine's own default is modern")
	options.set_preset("fifth")
	assert_true(options.damage_effects_fixed_order, "1997 — Fifth Edition: nobody is asked")
	assert_eq(options.preset(), "fifth", "and the preset is still named")
	for preset in MODERN:
		options.set_preset(preset)
		assert_false(options.damage_effects_fixed_order, "%s: the affected one chooses" % preset)
		assert_eq(options.preset(), preset)
	options.set_preset("fifth")
	options.damage_effects_fixed_order = false
	assert_eq(options.preset(), "custom", "one fork off the 1997 answers is Custom")


func test_the_fork_is_live_and_explains_both_answers() -> void:
	assert_true(RulesOptions.IMPLEMENTED.has("damage_effects_fixed_order"))
	var fork := {}
	for entry in RulesOptions.FORKS:
		if entry["key"] == "damage_effects_fixed_order":
			fork = entry
	assert_false(fork.is_empty(), "on the Options list")
	assert_eq(fork["label"], "Fixed order for damage effects")
	assert_true(bool(fork["fifth_value"]))
	assert_false(RulesOptions.modern_answer(fork))
	assert_string_contains(String(fork["fifth"]), "nobody is asked")
	assert_string_contains(String(fork["modern"]), "chooses which effect applies first")
	assert_string_contains(String(fork["source"]), "616.1")
	assert_string_contains(String(fork["source"]), "2026-10-12")
	# The player-facing lines carry no rules citation or file name (the
	# Help and Options rule): those stay in `source`.
	for side in ["fifth", "modern"]:
		assert_false(String(fork[side]).contains("CR "), side)
		assert_false(String(fork[side]).contains("docs/"), side)


# ===================================================== the player branch ==

func test_modern_the_damaged_seat_is_asked_and_its_order_is_kept() -> void:
	for preset in MODERN:
		var orderer := _fresh(preset)
		orderer.want = "Furnace"
		put_battlefield(0, "Forethought Amulet")
		_bolt(TargetRef.player(0))
		assert_eq(orderer.asked.size(), 1, "%s: one question" % preset)
		assert_eq(orderer.prompts[0], "Which applies first to the 3 damage from Lightning Bolt?",
			"%s: the prompt names the damage and its source" % preset)
		assert_eq(orderer.asked[0], ["Forethought Amulet", DOUBLED],
			"%s: both effects are lines, the fixed order's first on top" % preset)
		assert_eq(g.players[0].life, 18, "%s: Furnace first (6), then the Amulet: 2" % preset)

		orderer = _fresh(preset)
		orderer.want = "Amulet"
		put_battlefield(0, "Forethought Amulet")
		_bolt(TargetRef.player(0))
		assert_eq(g.players[0].life, 16, "%s: the Amulet first (2), then the Furnace: 4" % preset)


func test_1997_nobody_is_asked_and_the_fixed_order_applies() -> void:
	var orderer := _fresh("fifth")
	orderer.want = "Furnace"
	put_battlefield(0, "Forethought Amulet")
	_bolt(TargetRef.player(0))
	assert_eq(orderer.asked.size(), 0, "no question under the 1997 rules")
	assert_eq(g.players[0].life, 16, "the fixed order: the Amulet, then the Furnace")


func test_a_custom_table_follows_the_fork_alone() -> void:
	# The 1997 preset with only this fork back on the modern answer: asked.
	var orderer := _fresh("fifth")
	g.rules.damage_effects_fixed_order = false
	orderer.want = "Furnace"
	put_battlefield(0, "Forethought Amulet")
	_bolt(TargetRef.player(0))
	assert_eq(orderer.asked.size(), 1)
	assert_eq(g.players[0].life, 18)
	# And the modern preset with it on: nobody.
	orderer = _fresh("modern_mana_burn")
	g.rules.damage_effects_fixed_order = true
	orderer.want = "Furnace"
	put_battlefield(0, "Forethought Amulet")
	_bolt(TargetRef.player(0))
	assert_eq(orderer.asked.size(), 0)
	assert_eq(g.players[0].life, 16)


# =================================================== the creature branch ==

## A Craw Wurm (6/4) of P0's with two points of prevention on it.
func _shielded_wurm() -> CardInstance:
	var wurm := put_battlefield(0, "Craw Wurm")
	wurm.prevention = 2
	return wurm


func test_modern_the_creature_s_controller_is_asked() -> void:
	for preset in MODERN:
		var orderer := _fresh(preset)
		orderer.want = "Furnace"
		var wurm := _shielded_wurm()
		_bolt(TargetRef.card(wurm))
		assert_eq(orderer.asked.size(), 1, "%s: one question" % preset)
		assert_eq(orderer.prompts[0],
			"Which applies first to the 3 damage from Lightning Bolt to Craw Wurm?",
			"%s: the prompt names the damage, its source and the creature" % preset)
		assert_eq(orderer.asked[0], ["2 prevented damage", DOUBLED], preset)
		assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD,
			"%s: doubled to 6, two prevented: 4 is lethal" % preset)

		orderer = _fresh(preset)
		orderer.want = "prevented"
		wurm = _shielded_wurm()
		_bolt(TargetRef.card(wurm))
		assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, preset)
		assert_eq(wurm.damage, 2, "%s: two prevented, the 1 left doubled" % preset)


func test_1997_the_creature_s_controller_is_not_asked() -> void:
	var orderer := _fresh("fifth")
	orderer.want = "Furnace"
	var wurm := _shielded_wurm()
	_bolt(TargetRef.card(wurm))
	assert_eq(orderer.asked.size(), 0, "no question under the 1997 rules")
	assert_eq(wurm.damage, 2, "the fixed order: the shield, then the Furnace")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)


# ============================================== the look-ahead for agents ==

func test_the_outcomes_name_what_each_first_pick_would_land() -> void:
	var orderer := _fresh("modern_mana_burn")
	orderer.look_ahead = true
	put_battlefield(0, "Forethought Amulet")
	_bolt(TargetRef.player(0))
	assert_eq(orderer.forecasts.size(), 1)
	var outcomes: Array = orderer.forecasts[0]
	assert_eq(outcomes.size(), 2, "one per line")
	assert_eq(int(outcomes[0]["pick"]), 0)
	assert_eq(String(outcomes[0]["label"]), "Forethought Amulet")
	assert_eq(int(outcomes[0]["damage"]), 4, "the Amulet first: 4")
	assert_eq(int(outcomes[1]["damage"]), 2, "the Furnace first: 2")
	assert_false(bool(outcomes[1]["gone"]))
	assert_eq(g.players[0].life, 16, "looking changed nothing: the hint was taken")


func test_the_creature_outcomes() -> void:
	var orderer := _fresh("modern_mana_burn")
	orderer.look_ahead = true
	var wurm := _shielded_wurm()
	_bolt(TargetRef.card(wurm))
	var outcomes: Array = orderer.forecasts[0]
	assert_eq(int(outcomes[0]["damage"]), 2, "the shield first")
	assert_eq(int(outcomes[1]["damage"]), 4, "the Furnace first")
	assert_eq(wurm.damage, 2, "the hint was taken for real")
	assert_eq(wurm.prevention, 0)


## The probe a test agent runs while the question is open, with the
## board read either side of it.
class Looker extends DecisionAgent:
	var before := {}
	var after := {}
	var outcomes: Array = []
	var question := {}

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == "Lightning Bolt":
				return inst
		return null if candidates.is_empty() else candidates[0]

	func answer_option(game: MtgGame, _pid: int, _prompt: String,
			_options: Array[String], hint: int) -> int:
		question = game.damage_order_question()
		before = Looker.read(game)
		outcomes = game.damage_order_outcomes()
		after = Looker.read(game)
		return hint

	static func read(game: MtgGame) -> Dictionary:
		var field := []
		for p in game.players:
			for inst in p.battlefield:
				field.append("%d:%s:%d" % [p.id, inst.data.card_name, inst.damage])
		var q := game.damage_order_question()
		var packet: DamagePacket = q.get("packet")
		return {"log": game.log_lines.size(), "rng": game.rng.state,
			"life": [game.players[0].life, game.players[1].life],
			"field": field, "graveyards": [game.players[0].graveyard.size(), game.players[1].graveyard.size()],
			"replacements": game.players[0].damage_replacements.size(),
			"shields": game.players[0].prevention_shield_filters.size(),
			"packet": [packet.amount, packet.prevented, packet.redirected] if packet != null else [],
			"stack": game.stack.size(), "probing": game._probing,
			"journal": game.undo_log != null, "choices": game.choice_log.size()}


## A REDIRECTION, rewound: a Circle of Protection: Red and a Nova Pentacle
## both apply to a Bolt at P0 (tests/unit/test_damage_gate_order_2026_09_11.gd).
## The Pentacle first sends all three onto P1's Grizzly Bears, which die in
## the look-ahead — and are on the battlefield again after it. What lands
## on P0 is counted, not what lands elsewhere: 0 either way.
func test_a_redirection_is_counted_where_it_lands_and_rewound() -> void:
	super.before_each()
	g.rules.set_preset("modern_mana_burn")
	var looker := Looker.new()
	g.set_agent(0, looker)
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var pentacle := put_battlefield(0, "Nova Pentacle")
	var bears := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, pentacle, 0))
	var guard := 0
	while g.stack.size() > 1 and guard < 40:
		guard += 1
		if g.pass_priority(g.priority_player) != "":
			break
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0))
	resolve_stack()
	assert_false(looker.question.is_empty(), "the question was open")
	assert_eq(int(looker.question["seat"]), 0)
	assert_eq(looker.outcomes.size(), 2)
	for outcome in looker.outcomes:
		assert_eq(int(outcome["damage"]), 0, "%s: nothing lands on P0" % outcome["label"])
	assert_eq(looker.after, looker.before, "the look-ahead left no trace: %s / %s" % [looker.before, looker.after])
	assert_false(looker.before["journal"], "no search journal was left open")
	# The hint is the Pentacle (the fixed order's first): the Bears die for real.
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


## CR 614.5 ACROSS A LOOK-AHEAD. An effect that stays in its seat's list
## for the turn ("all_turn") and lets the event carry on is named by its
## place among the lasting ones, not by the Dictionary — the search
## journal restores a list as COPIES — so after the computer has looked
## ahead it is still not offered a second time.
func test_a_lasting_effect_once_applied_is_not_offered_again_after_a_look_ahead() -> void:
	var orderer := _fresh("modern_mana_burn")
	orderer.look_ahead = true
	orderer.picks = ["Test: one less", "prevented"]
	g.players[0].damage_replacements.append({
		"desc": "Test: one less", "all_turn": true,
		"filter": func(_game: MtgGame, _packet: DamagePacket) -> bool: return true,
		"apply": func(game: MtgGame, packet: DamagePacket) -> int:
			game._rec(packet, &"amount")
			packet.amount -= 1
			return -1})
	g.players[0].damage_prevention = 1
	_bolt(TargetRef.player(0))
	assert_eq(orderer.asked.size(), 2, "two questions: %s" % [orderer.asked])
	assert_eq(orderer.asked[0], ["Test: one less", "1 prevented damage", DOUBLED])
	assert_eq(orderer.asked[1], ["1 prevented damage", DOUBLED],
		"the lasting effect is not offered a second time")
	assert_eq((orderer.forecasts[1] as Array).size(), 2, "nor in the look-ahead")
	assert_eq(g.players[0].life, 18, "3, one less: 2, one prevented: 1, doubled: 2")
	assert_eq(g.players[0].damage_replacements.size(), 1, "it lasts the turn")
