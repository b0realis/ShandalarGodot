extends GameTest
## Pack 10 (the Urza block), batch B10: the 34 echo cards of
## cards/sets/{usg,ulg,uds}/_echo.gd. This script pins what they share —
## each is claimed, carries ONE echo ability with exactly its printed echo
## cost, keeps the keywords its Oracle text prints, and owes that echo at
## its controller's next upkeep and never again. The cards' other clauses
## are pinned in test_pack_10_B10_triggers.gd and
## test_pack_10_B10_artifacts.gd; echo itself in
## tests/unit/test_pack_10_engine_E1_echo.gd.

## [name, echo cost, keywords the card must have]
const CLAIMED := [
	["Herald of Serra", "{2}{W}{W}", [Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE]],
	["Crater Hellion", "{4}{R}{R}", []],
	["Goblin Patrol", "{R}", []],
	["Goblin War Buggy", "{1}{R}", [Mtg.Keyword.HASTE]],
	["Lightning Dragon", "{2}{R}{R}", [Mtg.Keyword.FLYING]],
	["Shivan Raptor", "{2}{R}", [Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.HASTE]],
	["Viashino Outrider", "{2}{R}", []],
	["Vug Lizard", "{1}{R}{R}", []],
	["Acridian", "{1}{G}", []],
	["Albino Troll", "{1}{G}", []],
	["Citanul Centaurs", "{3}{G}", []],
	["Cradle Guard", "{1}{G}{G}", [Mtg.Keyword.TRAMPLE]],
	["Pouncing Jaguar", "{G}", []],
	["Winding Wurm", "{4}{G}", []],
	["Karmic Guide", "{3}{W}{W}", [Mtg.Keyword.FLYING]],
	["Radiant's Dragoons", "{3}{W}", []],
	["Raven Familiar", "{2}{U}", [Mtg.Keyword.FLYING]],
	["Bone Shredder", "{2}{B}", [Mtg.Keyword.FLYING]],
	["Avalanche Riders", "{3}{R}", [Mtg.Keyword.HASTE]],
	["Ghitu Slinger", "{2}{R}", []],
	["Deranged Hermit", "{3}{G}{G}", []],
	["Multani's Acolyte", "{G}{G}", []],
	["Simian Grunts", "{2}{G}", [Mtg.Keyword.FLASH]],
	["Yavimaya Granger", "{2}{G}", []],
	["Ring of Gix", "{3}", []],
	["Thran War Machine", "{4}", [Mtg.Keyword.MUST_ATTACK]],
	["Thran Weaponry", "{4}", []],
	["Ticking Gnomes", "{3}", []],
	["Urza's Blueprints", "{6}", []],
	["Goblin Marshal", "{4}{R}{R}", []],
	["Keldon Champion", "{2}{R}{R}", [Mtg.Keyword.HASTE]],
	["Keldon Vandals", "{2}{R}", []],
	["Hunting Moa", "{2}{G}", []],
	["Extruder", "{4}", []],
]


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


## Exactly [param cost]'s mana in [param pid]'s pool (no burn left over).
func _mana_for(pid: int, cost: String) -> void:
	var parsed := ManaCost.parse(cost)
	for color in parsed.colored:
		add_mana(pid, int(color), int(parsed.colored[color]))
	if parsed.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, parsed.generic)


## Lands that pay [param cost]: one basic per colored symbol, Mountains
## for the generic part.
func _lands_for(pid: int, cost: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	var parsed := ManaCost.parse(cost)
	var basic := {Mtg.ManaColor.W: "Plains", Mtg.ManaColor.U: "Island", Mtg.ManaColor.B: "Swamp",
		Mtg.ManaColor.R: "Mountain", Mtg.ManaColor.G: "Forest"}
	for color in parsed.colored:
		for _i in int(parsed.colored[color]):
			out.append(put_battlefield(pid, basic[int(color)]))
	for _i in parsed.generic:
		out.append(put_battlefield(pid, "Mountain"))
	return out


func _tapped_lands(pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.is_land() and i.tapped: n += 1
	return n


func _echo_paid_lines(card_name: String) -> int:
	var n := 0
	for line in g.log_lines:
		if String(line).contains("pays echo for %s" % card_name):
			n += 1
	return n


func test_every_echo_card_is_claimed_with_its_printed_echo() -> void:
	assert_eq(CLAIMED.size(), 34)
	for row in CLAIMED:
		var card_name := String(row[0])
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending",
			"%s is claimed" % card_name)
		var echoes := 0
		var cost := ""
		for trig in c.triggered_abilities:
			if trig is EchoAbility.EchoTrigger:
				echoes += 1
				cost = (trig as EchoAbility.EchoTrigger).echo_cost
		assert_eq(echoes, 1, "%s has one echo" % card_name)
		assert_eq(cost, String(row[1]), card_name)
		assert_true(c.oracle_text.contains("Echo %s (" % cost),
			"%s: the echo cost is the printed one" % card_name)
		assert_eq(ManaCost.parse(cost).text, c.cost.text,
			"%s: in the Urza block the echo cost is the mana cost" % card_name)
		for kw in row[2]:
			assert_true(c.keywords.has(kw), "%s has keyword %d" % [card_name, kw])


func test_each_is_cast_and_owes_its_echo_once() -> void:
	for row in CLAIMED:
		var card_name := String(row[0])
		var cost := String(row[1])
		g = MtgGame.new()
		var filler: Array = []
		for i in 30:
			filler.append("Forest")
		g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
		g.start(0)
		advance_to_step(Mtg.Step.MAIN1)
		var card := give_hand(0, card_name)
		_mana_for(0, cost)
		assert_ok(g.cast_spell(0, card))
		resolve_stack()
		assert_eq(card.zone, Mtg.Zone.BATTLEFIELD, card_name)
		assert_true(EchoAbility.due_next_upkeep(g, card), "%s owes echo" % card_name)
		_lands_for(0, cost)
		advance_to_next_turn()
		_to_upkeep_resolved(3)
		assert_eq(_echo_paid_lines(card_name), 1, "%s: echo asked and paid once" % card_name)
		assert_eq(card.zone, Mtg.Zone.BATTLEFIELD, "%s stays" % card_name)
		assert_eq(_tapped_lands(0), ManaCost.parse(cost).mana_value(),
			"%s: paid from the lands" % card_name)
		assert_false(EchoAbility.due_next_upkeep(g, card), "%s: settled" % card_name)
		# Tapped, so a creature that must attack (Thran War Machine) has
		# nothing to declare on the way to the next upkeep.
		g.tap_permanent(card)
		_to_upkeep_resolved(5)
		assert_eq(_echo_paid_lines(card_name), 1, "%s: never asked again" % card_name)


func test_an_unpaid_echo_is_a_sacrifice_for_every_card_type() -> void:
	# A creature, a noncreature artifact and an artifact creature.
	for card_name in ["Pouncing Jaguar", "Urza's Blueprints", "Ticking Gnomes"]:
		var inst := put_battlefield(0, card_name)
		advance_to_next_turn()
		advance_to_next_turn()
		assert_eq(inst.zone, Mtg.Zone.GRAVEYARD, "%s: no mana, no echo, sacrificed" % card_name)


func test_citanul_centaurs_has_shroud() -> void:
	var centaurs := put_battlefield(0, "Citanul Centaurs")
	assert_true(centaurs.cur_shroud, "shroud")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(centaurs)]))


func test_thran_war_machine_attacks_each_combat() -> void:
	var machine := put_battlefield(0, "Thran War Machine")
	assert_true(machine.has_keyword(Mtg.Keyword.MUST_ATTACK))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, []))


func test_a_heuristic_ai_seat_pays_an_affordable_echo() -> void:
	# The null arm: until the Urza AI (A1) prices echo, every seat pays an
	# echo it can afford (DecisionAgent.echo_hint) — the AiPlayer included.
	var ai := AiPlayer.new(0)
	g.set_agent(0, ai)
	var herald := put_battlefield(0, "Herald of Serra")
	_lands_for(0, "{2}{W}{W}")
	assert_true(ai.echo_hint(g, 0, herald, ManaCost.parse("{2}{W}{W}")))
	advance_to_next_turn()
	_to_upkeep_resolved(3)
	assert_eq(herald.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(_echo_paid_lines("Herald of Serra"), 1)


func _to_upkeep_resolved(turn: int) -> void:
	var guard := 0
	while not (g.turn_number == turn and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	resolve_stack()


func test_a_test_hands_position_marked_echo_due_owes_it() -> void:
	# DuelPosition's "echo_due" (Test hands): the permanent owes its echo at
	# its controller's next upkeep, as if it had just come under control;
	# unmarked it owes nothing (MtgGame.begin_from_position).
	var position := DuelPosition.new()
	position.add(0, DuelPosition.TABLE, "Albino Troll")
	position.add(0, DuelPosition.TABLE, "Herald of Serra")
	position.set_echo_due(0, 0, true)
	var game := MtgGame.new()
	var filler: Array = []
	for i in 30:
		filler.append("Forest")
	game.setup(filler, filler, "P0", "P1", 20, 20, 7)
	assert_eq(game.begin_from_position(position), "")
	var troll: CardInstance = null
	var herald: CardInstance = null
	for inst in game.players[0].battlefield:
		if inst.data.card_name == "Albino Troll": troll = inst
		if inst.data.card_name == "Herald of Serra": herald = inst
	assert_not_null(troll)
	assert_not_null(herald)
	if troll == null or herald == null:
		return
	assert_true(game.came_under_control_since_last_upkeep(troll), "marked: owes its echo")
	assert_false(game.came_under_control_since_last_upkeep(herald), "unmarked: owes nothing")
