extends GameTest
## THE SECOND BUG HUNT (2026-10-21), the handover: a creature under an
## Illusionary Mask ("If the creature would assign or deal damage, be dealt
## damage, or become tapped, instead it's turned face up and assigns or
## deals damage, is dealt damage, or becomes tapped.").
##
## WAS: only `MtgGame.tap_permanent` (an Icy Manipulator) turned a masked
## creature up as it became tapped. Attacking with it, its regeneration
## shield's tap, a {T} cost it was given and tapping it for granted mana all
## tapped it FACE DOWN, so it stayed a nameless 2/2 — a masked Shivan Dragon
## attacked for 2 and stayed hidden. And a masked BLOCKER (or an attacker
## that did not tap) assigned its combat damage as the 2/2: the step
## collected every creature's power first and the creature was turned up
## only as the packet landed, so a masked Craw Wurm blocking a Hill Giant
## dealt it 2 and both lived.
## NOW every tap of a face-down creature turns it face up first, and the
## combat damage step turns up every face-down creature that will assign
## damage before the damage is divided (`MtgGame._combat_damage_step`).


## A static granting every creature "{T}: You gain 1 life." — a {T} cost a
## face-down creature can carry (CR 708.2 removes only its own abilities).
func _grant_tap_ability(_game: MtgGame, _source: CardInstance) -> void:
	for inst in g.all_battlefield():
		if inst.is_creature():
			inst.cur_activated_abilities.append(ActivatedAbility.new(
				"", true, [GainLifeEffect.new(1)], "{T}: You gain 1 life."))


## A static granting every creature "{T}: Add {G}."
func _grant_mana_ability(_game: MtgGame, _source: CardInstance) -> void:
	for inst in g.all_battlefield():
		if inst.is_creature():
			inst.cur_mana_abilities.append(ManaAbility.new(Mtg.ManaColor.G, 1))


## A static granting every creature vigilance: it attacks without tapping.
func _grant_vigilance(_game: MtgGame, _source: CardInstance) -> void:
	for inst in g.all_battlefield():
		if inst.is_creature():
			inst.cur_keywords.append(Mtg.Keyword.VIGILANCE)


func _granting(apply: Callable) -> void:
	put_synthetic(0, CardData.new("Test Grant", "", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(apply, "Creatures have it.").changing_abilities()))


func _masked(pid: int, card_name: String) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.put_from_hand_face_down(inst, pid)
	inst.summoning_sick = false
	g.recalculate()
	assert_true(inst.face_down, "control: it is masked")
	return inst


func test_a_masked_attacker_turns_face_up_as_it_taps() -> void:
	var dragon := _masked(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [dragon.id]))
	assert_true(dragon.tapped, "attacking taps it")
	assert_false(dragon.face_down, "it would become tapped: turned face up instead, and tapped")
	assert_eq(dragon.cur_power, 5, "the Dragon attacks as itself")
	assert_true(g.combat.attackers.has(dragon.id), "and is still attacking")


func test_a_masked_attacker_hits_for_its_real_power() -> void:
	var dragon := _masked(0, "Shivan Dragon")
	run_combat([dragon.id])
	assert_eq(g.players[1].life, 15, "5 from the Dragon, not 2 from a mask")


func test_a_masked_creature_regenerating_turns_face_up() -> void:
	var dragon := _masked(0, "Shivan Dragon")
	dragon.regeneration_shields = 1
	g.destroy(dragon)
	assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(dragon.tapped)
	assert_false(dragon.face_down, "regeneration taps it, so it is turned face up")


func test_a_masked_creature_paying_a_tap_cost_turns_face_up() -> void:
	_granting(_grant_tap_ability)
	var dragon := _masked(0, "Shivan Dragon")
	assert_eq(dragon.cur_activated_abilities.size(), 1, "control: it was given the ability")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, dragon, 0))
	assert_true(dragon.tapped)
	assert_false(dragon.face_down, "paying {T} taps it: turned face up")


func test_a_masked_creature_tapped_for_mana_turns_face_up() -> void:
	_granting(_grant_mana_ability)
	var dragon := _masked(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, dragon))
	assert_true(dragon.tapped)
	assert_false(dragon.face_down, "tapped for mana: turned face up")


func test_a_masked_blocker_assigns_its_real_power() -> void:
	var giant := put_battlefield(0, "Hill Giant")       # 3/3
	var wurm := _masked(1, "Craw Wurm")                  # 6/4 under the mask
	run_combat([giant.id], {wurm.id: giant.id})
	assert_false(wurm.face_down, "it assigned damage: turned face up")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD,
		"turned face up and THEN assigns its damage: 6 to a 3/3 Giant")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "3 damage on a 6/4")


func test_a_masked_attacker_that_did_not_tap_assigns_its_real_power() -> void:
	_granting(_grant_vigilance)
	var dragon := _masked(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [dragon.id]))
	assert_true(dragon.face_down, "control: vigilance — it never tapped, so still masked")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_false(dragon.face_down)
	assert_eq(g.players[1].life, 15, "5 from the Dragon, not 2")


func test_a_masked_blocker_with_nothing_left_to_fight_stays_masked() -> void:
	# Control: a blocker whose attacker has left combat assigns no damage
	# (CR 510.1c), so nothing turns it up.
	var giant := put_battlefield(0, "Hill Giant")
	var wurm := _masked(1, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wurm.id: giant.id}))
	g.return_to_hand(giant)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_true(wurm.face_down, "it assigned nothing and was dealt nothing")
