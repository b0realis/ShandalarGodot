extends GameTest
## Pack 10 (the Urza block), batch B3: the white and blue Urza's Destiny
## creatures of cards/sets/uds/_creatures.gd — Capashen Knight, Capashen
## Templar, Field Surgeon, Master Healer, Serra Advocate, Bubbling Beebles,
## Fledgling Osprey, Metathran Elite, Metathran Soldier and Temporal Adept.
## Each test pins the clause that makes the card that card, with its
## refused case; Master Healer's also in the 1997 damage-prevention step.

const CLAIMED := ["Capashen Knight", "Capashen Templar", "Field Surgeon", "Master Healer",
	"Serra Advocate", "Bubbling Beebles", "Fledgling Osprey", "Metathran Elite",
	"Metathran Soldier", "Temporal Adept"]


## FIFO card picks; an empty queue takes the first candidate.
class Scripted extends DecisionAgent:
	var picks: Array = []
	var window := false

	func wants_damage_prevention_window() -> bool:
		return window

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		for c in candidates:
			if want is CardInstance and c == want:
				return c
		return null


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a

func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

func cast(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card

## P0 attacks with [param attacker]; P1 is to declare blockers.
func _attack(attacker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func test_claimed_cards_are_no_longer_pending() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_eq(c.set_code, "uds", card_name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# --- Capashen Knight / Capashen Templar -------------------------------------

func test_capashen_knight_strikes_first_and_pumps_its_power() -> void:
	var knight := put_battlefield(0, "Capashen Knight")
	assert_true(knight.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.activate_ability(0, knight, 0), "mana")
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, knight, 0))
	resolve_stack()
	assert_eq([knight.cur_power, knight.cur_toughness], [2, 1])

func test_capashen_templar_pumps_its_toughness() -> void:
	var templar := put_battlefield(0, "Capashen Templar")
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.activate_ability(0, templar, 0))
	assert_ok(g.activate_ability(0, templar, 0))
	resolve_stack()
	assert_eq([templar.cur_power, templar.cur_toughness], [2, 4])
	advance_to_next_turn()
	assert_eq([templar.cur_power, templar.cur_toughness], [2, 2])


# --- Field Surgeon ----------------------------------------------------------

## "Tap an untapped creature you control" is not {T}: a summoning-sick
## creature — the Surgeon itself included — may pay it (CR 302.6).
func test_field_surgeon_taps_a_sick_creature_to_shield_one() -> void:
	var p0 := seat(0)
	var surgeon := put_battlefield(0, "Field Surgeon", true)
	var giant := put_battlefield(0, "Hill Giant", true)
	p0.picks = [surgeon]
	assert_ok(g.activate_ability(0, surgeon, 0, [TargetRef.card(giant)]))
	assert_true(surgeon.tapped)
	assert_false(giant.tapped)
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(giant)], 1)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.damage, 2, "3 - 1")

func test_field_surgeon_needs_an_untapped_creature_and_targets_only_creatures() -> void:
	var p0 := seat(0)
	var surgeon := put_battlefield(0, "Field Surgeon")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_refused(g.activate_ability(0, surgeon, 0, [TargetRef.player(0)]))
	p0.picks = [bear]
	assert_ok(g.activate_ability(0, surgeon, 0, [TargetRef.card(surgeon)]))
	assert_true(bear.tapped)
	assert_false(surgeon.tapped)
	p0.picks = [surgeon]
	assert_ok(g.activate_ability(0, surgeon, 0, [TargetRef.card(bear)]))
	assert_refused(g.activate_ability(0, surgeon, 0, [TargetRef.card(bear)]), "untapped")


# --- Master Healer ----------------------------------------------------------

func test_master_healer_prevents_four() -> void:
	var healer := put_battlefield(0, "Master Healer")
	var giant := put_battlefield(0, "Hill Giant")
	assert_ok(g.activate_ability(0, healer, 0, [TargetRef.card(giant)]))
	resolve_stack()
	cast("Lightning Bolt", [TargetRef.card(giant)], 1)
	assert_eq(giant.damage, 0)
	assert_true(CardRegistry.get_card("Master Healer").activated_abilities[0].effects[0].is_damage_prevention)

## The 1997 damage-prevention step (fifth): the Giant's damage waits, and
## Master Healer — a prevention ability — may be used inside the window.
func test_master_healer_works_inside_the_1997_damage_prevention_window() -> void:
	var p1 := seat(1)
	g.rules.set_preset("fifth")
	g.rules.damage_prevention_window = true
	p1.window = true
	var giant := put_battlefield(0, "Hill Giant")
	var healer := put_battlefield(1, "Master Healer")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the damage waits")
	if g.priority_player != 1:
		assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.activate_ability(1, healer, 0, [TargetRef.player(1)]))
	var guard := 0
	while (g.awaiting_damage_prevention or not g.stack.is_empty()) and guard < 20:
		if g.stack.is_empty():
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.players[1].life, 20, "the Healer's 4 covers the Giant's 3")


# --- Serra Advocate ---------------------------------------------------------

func test_serra_advocate_lifts_a_blocker_by_two() -> void:
	var advocate := put_battlefield(1, "Serra Advocate")
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	assert_true(advocate.has_keyword(Mtg.Keyword.FLYING))
	_attack(giant)
	assert_ok(g.declare_blockers(1, {bear.id: giant.id}))
	if g.priority_player == 0:
		assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, advocate, 0, [TargetRef.card(advocate)]))
	assert_ok(g.activate_ability(1, advocate, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [4, 4])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


# --- Bubbling Beebles -------------------------------------------------------

func test_bubbling_beebles_unblockable_while_the_defender_has_an_enchantment() -> void:
	var beebles := put_battlefield(0, "Bubbling Beebles")
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Crusade")
	assert_false(beebles.has_keyword(Mtg.Keyword.UNBLOCKABLE), "our own enchantment does not count")
	var moon := put_battlefield(1, "Bad Moon")
	assert_true(beebles.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	g.destroy(moon)
	assert_false(beebles.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	put_battlefield(1, "Bad Moon")
	_attack(beebles)
	assert_refused(g.declare_blockers(1, {bear.id: beebles.id}))
	assert_ok(g.declare_blockers(1, {}))

func test_bubbling_beebles_can_be_blocked_without_an_enchantment_across() -> void:
	var beebles := put_battlefield(0, "Bubbling Beebles")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack(beebles)
	assert_ok(g.declare_blockers(1, {bear.id: beebles.id}))


# --- Fledgling Osprey / Metathran Elite -------------------------------------

func test_fledgling_osprey_flies_only_while_enchanted() -> void:
	var osprey := put_battlefield(0, "Fledgling Osprey")
	assert_false(osprey.has_keyword(Mtg.Keyword.FLYING))
	var aura := cast("Holy Strength", [TargetRef.card(osprey)])
	assert_true(osprey.has_keyword(Mtg.Keyword.FLYING))
	g.destroy(aura)
	assert_false(osprey.has_keyword(Mtg.Keyword.FLYING))

func test_metathran_elite_is_unblockable_while_enchanted() -> void:
	var elite := put_battlefield(0, "Metathran Elite")
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_false(elite.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	cast("Holy Strength", [TargetRef.card(elite)])
	assert_true(elite.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	_attack(elite)
	assert_refused(g.declare_blockers(1, {bear.id: elite.id}))

func test_metathran_elite_without_an_aura_can_be_blocked() -> void:
	var elite := put_battlefield(0, "Metathran Elite")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack(elite)
	assert_ok(g.declare_blockers(1, {bear.id: elite.id}))


# --- Metathran Soldier ------------------------------------------------------

func test_metathran_soldier_cannot_be_blocked() -> void:
	var soldier := put_battlefield(0, "Metathran Soldier")
	var bear := put_battlefield(1, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	assert_true(soldier.has_keyword(Mtg.Keyword.UNBLOCKABLE))
	assert_true(soldier.data.keywords.has(Mtg.Keyword.UNBLOCKABLE), "a printed ability")
	_attack(soldier)
	assert_refused(g.declare_blockers(1, {bear.id: soldier.id}))
	assert_refused(g.declare_blockers(1, {wall.id: soldier.id}))
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 19)


# --- Temporal Adept ---------------------------------------------------------

func test_temporal_adept_returns_any_permanent() -> void:
	var adept := put_battlefield(0, "Temporal Adept")
	var land := put_battlefield(1, "Mountain")
	var sick := put_battlefield(0, "Temporal Adept", true)
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.activate_ability(0, adept, 0, [TargetRef.card(land)]), "mana")
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.activate_ability(0, sick, 0, [TargetRef.card(land)]))
	assert_refused(g.activate_ability(0, adept, 0, [TargetRef.player(1)]))
	assert_ok(g.activate_ability(0, adept, 0, [TargetRef.card(land)]))
	resolve_stack()
	assert_eq(land.zone, Mtg.Zone.HAND)
	assert_true(g.players[1].hand.has(land), "its owner's hand")
