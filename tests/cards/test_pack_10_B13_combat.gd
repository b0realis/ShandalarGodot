extends GameTest
## Pack 10 (the Urza block), batch B13: the combat cards on Pack 10 E6 —
## Defensive Formation (the defending player divides each attacker's
## damage among its blockers), Okk (attacks and blocks only beside a
## creature with greater power) and Outmaneuver (X target blocked creatures
## deal their damage as though they weren't blocked) — and Serra's Hymn on
## Pack 10 E7 (a prevention divided by its verse counters).

const W := Mtg.ManaColor.W
const R := Mtg.ManaColor.R

const CLAIMED := ["Defensive Formation", "Okk", "Outmaneuver", "Serra's Hymn"]


## A seat that wants to be asked for every division (as a human is), and
## answers yes/no as scripted (-1: the hint).
class Seat extends DecisionAgent:
	var yes := -1
	func wants_to_assign_combat_damage() -> bool:
		return true
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, hint: bool) -> bool:
		return hint if yes < 0 else yes == 1

var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


func _to_blockers(attacker_ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)


# ----------------------------------------------------- Defensive Formation --

func test_defensive_formation_hands_the_division_to_the_defender() -> void:
	put_battlefield(1, "Defensive Formation")
	assert_true(g.players[1].assigns_attackers_damage)
	var giant := put_battlefield(0, "Hill Giant")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Grizzly Bears")
	_to_blockers([giant.id])
	assert_ok(g.declare_blockers(1, {a.id: giant.id, b.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	var request := g.damage_assignment_request()
	assert_eq(int(request.assigner), 1, "the defending player assigns")
	assert_true(bool(request.free_order))
	assert_ok(g.assign_combat_damage(1, {b.id: 3}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)


func test_defensive_formation_of_the_attacker_changes_nothing() -> void:
	put_battlefield(0, "Defensive Formation")
	var giant := put_battlefield(0, "Hill Giant")
	var a := put_battlefield(1, "Grizzly Bears")
	_to_blockers([giant.id])
	assert_ok(g.declare_blockers(1, {a.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	if g.awaiting_damage_assignment:
		assert_eq(int(g.damage_assignment_request().assigner), 0, "each creature attacking YOU")


# ------------------------------------------------------------------------ Okk --

func test_okk_cant_attack_alone_or_beside_a_smaller_creature() -> void:
	var okk := put_battlefield(0, "Okk")
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [okk.id]), "greater power")
	assert_refused(g.declare_attackers(0, [okk.id, bear.id]), "greater power")


func test_okk_attacks_beside_a_bigger_creature() -> void:
	var okk := put_battlefield(0, "Okk")
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [okk.id, wurm.id]))
	assert_true(g.combat.attackers.has(okk.id))


func test_okk_blocks_only_beside_a_bigger_blocker() -> void:
	var raider := put_battlefield(0, "Grizzly Bears")
	var okk := put_battlefield(1, "Okk")
	var wurm := put_battlefield(1, "Craw Wurm")
	_to_blockers([raider.id])
	assert_refused(g.declare_blockers(1, {okk.id: raider.id}), "greater power")
	assert_ok(g.declare_blockers(1, {okk.id: raider.id, wurm.id: raider.id}))


func test_okk_under_humility_has_no_restriction() -> void:
	CardPacks.set_enabled("pack-9", true)   # Humility (Tempest)
	var okk := put_battlefield(0, "Okk")
	put_battlefield(1, "Humility")
	g.recalculate()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [okk.id]))   # the ability is gone (layer 6)


# --------------------------------------------------------------- Outmaneuver --

func test_outmaneuver_sends_a_blocked_creatures_damage_to_the_player() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Stone")
	_to_blockers([giant.id])
	assert_ok(g.declare_blockers(1, {wall.id: giant.id}))
	if g.priority_player != 0:
		assert_ok(g.pass_priority(g.priority_player))
	var spell := give_hand(0, "Outmaneuver")
	add_mana(0, R, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(giant)], 1))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17, "all of it to the player")
	assert_eq(wall.damage, 0)
	assert_true(g.combat.blocked_attackers.has(giant.id), "it stays a blocked creature")


func test_outmaneuver_targets_only_blocked_creatures() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	_to_blockers([giant.id, bear.id])
	assert_ok(g.declare_blockers(1, {wall.id: giant.id}))
	if g.priority_player != 0:
		assert_ok(g.pass_priority(g.priority_player))
	var spell := give_hand(0, "Outmaneuver")
	add_mana(0, R, 2)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(bear)], 1))


# --------------------------------------------------------------- Serra's Hymn --

func test_serra_s_hymn_gains_a_verse_at_each_of_your_upkeeps() -> void:
	var hymn := put_battlefield(0, "Serra's Hymn")
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(int(hymn.counters.get("verse", 0)), 1)
	me.yes = 0
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(int(hymn.counters.get("verse", 0)), 1, "declined")


func test_serra_s_hymn_divides_x_prevention_among_its_targets() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var hymn := put_battlefield(0, "Serra's Hymn")
	g.add_counters(hymn, "verse", 3)
	var bear := put_battlefield(0, "Grizzly Bears")
	var a := TargetRef.player(0)
	a.amount = 2
	var b := TargetRef.card(bear)
	b.amount = 1
	assert_ok(g.activate_ability(0, hymn, 0, [a, b]))
	assert_eq(hymn.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	if g.priority_player != 1:
		assert_ok(g.pass_priority(g.priority_player))
	add_mana(1, R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 19, "2 of the Bolt's 3 prevented")


func test_serra_s_hymn_refuses_a_division_that_does_not_add_up() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var hymn := put_battlefield(0, "Serra's Hymn")
	g.add_counters(hymn, "verse", 2)
	var a := TargetRef.player(0)
	a.amount = 2
	var b := TargetRef.player(1)
	b.amount = 1
	assert_refused(g.activate_ability(0, hymn, 0, [a, b]))
	assert_eq(hymn.zone, Mtg.Zone.BATTLEFIELD, "nothing paid on a refusal")
