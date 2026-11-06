extends GameTest
## Pack 10 (the Urza block), batch B1: the red instants and sorceries of
## cards/sets/usg/_spells.gd and cards/sets/ulg/_spells.gd — every card
## claimed, its main effect, a refused or illegal case, and the
## interactions its text implies (simultaneous damage and the draw, divided
## damage, Falter read live, Raze's own land fizzling it, the X spells,
## Last-Ditch Effort's sacrifice that a fizzle never makes).

const CLAIMED := ["Acidic Soil", "Arc Lightning", "Disorder", "Falter", "Fault Line", "Gamble",
	"Goblin Offensive", "Headlong Rush", "Heat Ray", "Meltdown", "Raze", "Shower of Sparks",
	"Steam Blast", "About Face", "Last-Ditch Effort", "Rack and Ruin"]


## Scripted answers: a card by name from [member picks] (else the first
## candidate), an option by label from [member labels] (else the hint).
class Seat extends DecisionAgent:
	var picks: Array[String] = []
	var labels: Array[String] = []
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		for n in picks.size():
			for c in candidates:
				if c.data.card_name == picks[n]:
					picks.remove_at(n)
					return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, _prompt: String, options: Array[String], hint: int) -> int:
		for n in labels.size():
			var at := options.find(labels[n])
			if at >= 0:
				labels.remove_at(n)
				return at
		return hint


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _pay(pid: int, card_name: String, x := 0) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)

func _try(pid: int, card_name: String, targets: Array = [], x := 0) -> String:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name, x)
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	return g.cast_spell(pid, card, targets, x)

func _cast(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	assert_ok(_try(pid, card_name, targets, x))

func _cast_resolve(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	_cast(pid, card_name, targets, x)
	resolve_stack()

func _library_top(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.put_from_hand_on_top_of_library(card)
	return card

func _named(pid: int, card_name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: out.append(i)
	return out

## P0 attacks with [param attackers]; P1 blocks with [param blocks]
## (blocker id -> attacker id). Leaves the game in the declare-blockers
## step.
func _attack(attackers: Array[CardInstance], blocks := {}) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# -------------------------------------------------------------- Acidic Soil --

func test_acidic_soil_burns_each_player_for_their_lands() -> void:
	for _i in 3:
		put_battlefield(0, "Mountain")
	put_battlefield(1, "Island")
	put_battlefield(1, "Mishra's Factory")
	put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Acidic Soil")
	assert_eq(g.players[0].life, 17)
	assert_eq(g.players[1].life, 18)

func test_acidic_soil_lethal_to_both_is_a_draw() -> void:
	for pid in [0, 1]:
		put_battlefield(pid, "Mountain")
		put_battlefield(pid, "Mountain")
		g.players[pid].life = 2
	_cast_resolve(0, "Acidic Soil")
	assert_true(g.game_over)
	assert_true(g.is_draw, "one event: both lose at once (CR 104.4a)")

## Both rules presets: the 1997 profile checks life at the end of the
## phase (manual p.174), so the double kill waits for it, and is a draw
## there too. The sweepers and Raze themselves read no fork.
func test_red_spells_under_both_rules_presets() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		var bear := put_battlefield(1, "Grizzly Bears")
		_cast_resolve(0, "Steam Blast")
		assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, preset)
		var mine := put_battlefield(0, "Mountain")
		var theirs := put_battlefield(1, "Island")
		_cast_resolve(0, "Raze", [TargetRef.card(theirs)])
		assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, preset)
		assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, preset)
		for pid in [0, 1]:
			put_battlefield(pid, "Mountain")
			put_battlefield(pid, "Mountain")
			g.players[pid].life = 2
		_cast_resolve(0, "Acidic Soil")
		if preset == "fifth":
			assert_false(g.game_over, "the 1997 rule waits for the end of the phase")
			advance_to_step(Mtg.Step.COMBAT_BEGIN)
		assert_true(g.game_over, preset)
		assert_true(g.is_draw, preset)


# ------------------------------------------------------------ Arc Lightning --

func test_arc_lightning_divides_three_damage() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	_cast_resolve(0, "Arc Lightning", [TargetRef.card(bear, 2), TargetRef.card(elves, 1)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	var ogre := put_battlefield(1, "Gray Ogre")
	_cast_resolve(0, "Arc Lightning", [TargetRef.card(ogre, 2), TargetRef.player(1, 1)])
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 19)
	_cast_resolve(0, "Arc Lightning", [TargetRef.player(1, 3)])
	assert_eq(g.players[1].life, 16, "one target takes all three")

func test_arc_lightning_takes_at_most_three_targets() -> void:
	var a := put_battlefield(1, "Llanowar Elves")
	var b := put_battlefield(1, "Llanowar Elves")
	var c := put_battlefield(1, "Llanowar Elves")
	assert_refused(_try(0, "Arc Lightning", [TargetRef.card(a, 1), TargetRef.card(b, 1),
		TargetRef.card(c, 1), TargetRef.player(1, 1)]))


# ----------------------------------------------------------------- Disorder --

func test_disorder_burns_white_creatures_and_their_controllers() -> void:
	var lions := put_battlefield(1, "Savannah Lions")
	var bear := put_battlefield(1, "Grizzly Bears")
	var knight := put_battlefield(0, "White Knight")
	var giant := put_battlefield(0, "Hill Giant")
	_cast_resolve(0, "Disorder")
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.damage, 0)
	assert_eq(giant.damage, 0)
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[1].life, 18)

func test_disorder_spares_a_player_without_a_white_creature() -> void:
	put_battlefield(1, "Savannah Lions")
	put_battlefield(0, "Grizzly Bears")
	_cast_resolve(0, "Disorder")
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 18)


# ------------------------------------------------------------------- Falter --

func test_falter_creatures_without_flying_cant_block() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ogre := put_battlefield(1, "Gray Ogre")
	var angel := put_battlefield(1, "Serra Angel")
	_cast_resolve(0, "Falter")
	var late := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {ogre.id: bear.id}))
	assert_refused(g.declare_blockers(1, {late.id: bear.id}))
	assert_ok(g.declare_blockers(1, {angel.id: bear.id}))

func test_falter_reads_flying_as_blockers_are_declared() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ogre := put_battlefield(1, "Gray Ogre")
	_cast_resolve(0, "Falter")
	_cast_resolve(1, "Jump", [TargetRef.card(ogre)])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {ogre.id: bear.id}))   # it has flying now

func test_falter_lasts_only_this_turn() -> void:
	var ogre := put_battlefield(1, "Gray Ogre")
	_cast_resolve(0, "Falter")
	advance_to_next_turn()
	advance_to_next_turn()
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {ogre.id: bear.id}))


# --------------------------------------------------------------- Fault Line --

func test_fault_line_hits_each_creature_without_flying_and_each_player() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var ogre := put_battlefield(1, "Gray Ogre")
	var giant := put_battlefield(1, "Hill Giant")
	var angel := put_battlefield(1, "Serra Angel")
	_cast_resolve(0, "Fault Line", [], 2)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 2)
	assert_eq(angel.damage, 0, "flying")
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[1].life, 18)


# ------------------------------------------------------------------- Gamble --

func test_gamble_with_no_other_card_discards_what_it_found() -> void:
	var seat := _seat(0)
	var bolt := _library_top(0, "Lightning Bolt")
	seat.picks = ["Lightning Bolt"]
	var library := g.players[0].library.size()
	_cast_resolve(0, "Gamble")
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "the only card in hand is discarded at random")
	assert_eq(g.players[0].library.size(), library - 1)

func test_gamble_puts_the_card_in_hand_and_discards_one_at_random() -> void:
	var seat := _seat(0)
	var bolt := _library_top(0, "Lightning Bolt")
	var growth := give_hand(0, "Giant Growth")
	seat.picks = ["Lightning Bolt"]
	_cast_resolve(0, "Gamble")
	assert_eq(g.players[0].hand.size(), 1)
	assert_true(bolt.zone == Mtg.Zone.HAND or growth.zone == Mtg.Zone.HAND)
	assert_true(bolt.zone == Mtg.Zone.GRAVEYARD or growth.zone == Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Goblin Offensive --

func test_goblin_offensive_creates_x_goblins() -> void:
	_cast_resolve(0, "Goblin Offensive", [], 3)
	var goblins := _named(0, "Goblin")
	assert_eq(goblins.size(), 3)
	for t in goblins:
		assert_true(t.is_token)
		assert_eq([t.cur_power, t.cur_toughness], [1, 1])
		assert_eq(t.cur_colors, Mtg.ManaColor.R)
		assert_true(t.has_subtype("goblin"))
	_cast_resolve(0, "Goblin Offensive", [], 0)
	assert_eq(_named(0, "Goblin").size(), 3, "X = 0 makes none")


# ------------------------------------------------------------ Headlong Rush --

func test_headlong_rush_gives_attacking_creatures_first_strike() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var idle := put_battlefield(0, "Hill Giant")
	var blocker := put_battlefield(1, "Grizzly Bears")
	_attack([bear], {blocker.id: bear.id})
	_cast_resolve(0, "Headlong Rush")
	assert_true(bear.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_false(idle.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	assert_false(blocker.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(blocker.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "it struck first")


# ----------------------------------------------------------------- Heat Ray --

func test_heat_ray_deals_x_to_target_creature() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	_cast_resolve(0, "Heat Ray", [TargetRef.card(giant)], 3)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_refused(_try(0, "Heat Ray", [TargetRef.player(1)], 3))


# ----------------------------------------------------------------- Meltdown --

func test_meltdown_destroys_each_artifact_with_mana_value_x_or_less() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	var thopter := put_battlefield(1, "Ornithopter")
	var icy := put_battlefield(1, "Icy Manipulator")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Meltdown", [], 1)
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(thopter.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(icy.zone, Mtg.Zone.BATTLEFIELD, "mana value 4")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	_cast_resolve(0, "Meltdown", [], 4)
	assert_eq(icy.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------------------- Raze --

func test_raze_sacrifices_a_land_and_destroys_target_land() -> void:
	var mine := put_battlefield(0, "Mountain")
	var theirs := put_battlefield(1, "Island")
	_cast_resolve(0, "Raze", [TargetRef.card(theirs)])
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)

func test_raze_needs_a_land_to_sacrifice() -> void:
	var theirs := put_battlefield(1, "Island")
	assert_refused(_try(0, "Raze", [TargetRef.card(theirs)]), "land")

func test_raze_aimed_at_the_land_it_sacrifices_fizzles() -> void:
	var only := put_battlefield(0, "Mountain")
	var raze := give_hand(0, "Raze")
	_pay(0, "Raze")
	assert_ok(g.cast_spell(0, raze, [TargetRef.card(only)]))
	assert_eq(only.zone, Mtg.Zone.GRAVEYARD, "targets are chosen before the cost is paid (CR 601.2c, 601.2h)")
	resolve_stack()
	assert_eq(raze.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Shower of Sparks --

func test_shower_of_sparks_hits_a_creature_and_a_player() -> void:
	var elves := put_battlefield(1, "Llanowar Elves")
	_cast_resolve(0, "Shower of Sparks", [TargetRef.card(elves), TargetRef.player(1)])
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 19)
	assert_refused(_try(0, "Shower of Sparks", [TargetRef.player(1), TargetRef.card(put_battlefield(1, "Grizzly Bears"))]))

func test_shower_of_sparks_still_hits_the_player_when_the_creature_is_gone() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast(0, "Shower of Sparks", [TargetRef.card(bear), TargetRef.player(1)])
	g.return_to_hand(bear)
	resolve_stack()
	assert_eq(g.players[1].life, 19, "the other target is still legal (CR 608.2b)")


# --------------------------------------------------------------- Steam Blast --

func test_steam_blast_hits_each_creature_and_each_player() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var angel := put_battlefield(1, "Serra Angel")
	var ogre := put_battlefield(1, "Gray Ogre")
	_cast_resolve(0, "Steam Blast")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.damage, 2)
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[1].life, 18)


# --------------------------------------------------------------- About Face --

func test_about_face_switches_power_and_toughness() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")
	_cast_resolve(0, "About Face", [TargetRef.card(wurm)])
	assert_eq([wurm.cur_power, wurm.cur_toughness], [4, 6])
	var wall := put_battlefield(1, "Wall of Stone")
	_cast_resolve(0, "About Face", [TargetRef.card(wall)])
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "an 8/0 wall dies")
	advance_to_next_turn()
	assert_eq([wurm.cur_power, wurm.cur_toughness], [6, 4])


# -------------------------------------------------------- Last-Ditch Effort --

func test_last_ditch_effort_sacrifices_any_number_and_deals_that_much() -> void:
	var seat := _seat(0)
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(0, "Llanowar Elves")
	var giant := put_battlefield(0, "Hill Giant")
	seat.labels = ["2"]
	seat.picks = ["Grizzly Bears", "Llanowar Elves"]
	_cast_resolve(0, "Last-Ditch Effort", [TargetRef.player(1)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 18)

func test_last_ditch_effort_that_fizzles_sacrifices_nothing() -> void:
	var seat := _seat(0)
	var bear := put_battlefield(0, "Grizzly Bears")
	var victim := put_battlefield(1, "Gray Ogre")
	seat.labels = ["1"]
	_cast(0, "Last-Ditch Effort", [TargetRef.card(victim)])
	g.return_to_hand(victim)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "an illegal target: the spell does nothing (CR 608.2b)")

func test_last_ditch_effort_for_none_deals_none() -> void:
	var seat := _seat(0)
	put_battlefield(0, "Grizzly Bears")
	seat.labels = ["0"]
	_cast_resolve(0, "Last-Ditch Effort", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 20)


# ------------------------------------------------------------ Rack and Ruin --

func test_rack_and_ruin_destroys_two_target_artifacts() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var icy := put_battlefield(1, "Icy Manipulator")
	assert_refused(_try(0, "Rack and Ruin", [TargetRef.card(ring)]))
	assert_refused(_try(0, "Rack and Ruin", [TargetRef.card(ring), TargetRef.card(put_battlefield(1, "Grizzly Bears"))]))
	_cast_resolve(0, "Rack and Ruin", [TargetRef.card(ring), TargetRef.card(icy)])
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(icy.zone, Mtg.Zone.GRAVEYARD)
