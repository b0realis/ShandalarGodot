extends GameTest
## Pack 10 (the Urza block), batch B5: the combat triggers of
## cards/sets/usg/_triggers.gd and cards/sets/uds/_triggers.gd — attacks,
## blocks and becomes blocked (once each; "by a creature" once per
## blocker), damage dealt to a player or to "a creature or opponent" (one
## trigger per damage event), damage dealt TO a creature, end-of-combat
## delayed effects, and Karn's animation.

class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


## P0 attacks with [param attackers]; P1 blocks per [param blocks]
## (blocker id -> attacker id); stops in the declare-blockers step with the
## block triggers resolved.
func _attack_and_block(attackers: Array, blocks: Dictionary) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, blocks))
	resolve_stack()

## Run the rest of the combat to its end step, triggers resolved.
func _finish_combat() -> void:
	advance_to_step(Mtg.Step.COMBAT_END)
	resolve_stack()


# ------------------------------------------------------ Hollow Dogs, Ravenous Skirge --

func test_hollow_dogs_and_ravenous_skirge_get_two_power_when_attacking() -> void:
	var dogs := put_battlefield(0, "Hollow Dogs")
	var skirge := put_battlefield(0, "Ravenous Skirge")
	_attack_and_block([dogs, skirge], {})
	assert_eq(dogs.cur_power, 5)
	assert_eq(dogs.cur_toughness, 3)
	assert_eq(skirge.cur_power, 3)
	assert_true(skirge.has_keyword(Mtg.Keyword.FLYING))


# ------------------------------------------------------------------------ Vebulid --

func test_vebulid_that_attacks_is_destroyed_at_end_of_combat() -> void:
	var vebulid := put_battlefield(0, "Vebulid")
	g.add_counters(vebulid, "+1/+1", 3)
	assert_eq(vebulid.cur_power, 4, "its enters counter and three more")
	_attack_and_block([vebulid], {})
	_finish_combat()
	assert_eq(vebulid.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 16)

func test_vebulid_that_blocks_is_destroyed_at_end_of_combat() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var vebulid := put_battlefield(1, "Vebulid")
	g.add_counters(vebulid, "+1/+1", 4)
	_attack_and_block([bear], {vebulid.id: bear.id})
	_finish_combat()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(vebulid.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------------------- Dromosaur --

func test_dromosaur_gets_plus_two_minus_two_when_it_blocks() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var dromo := put_battlefield(1, "Dromosaur")
	_attack_and_block([bear], {dromo.id: bear.id})
	assert_eq(dromo.cur_power, 4)
	assert_eq(dromo.cur_toughness, 1)
	_finish_combat()
	assert_eq(dromo.zone, Mtg.Zone.GRAVEYARD, "a 4/1 trades with the Bears")

func test_dromosaur_gets_plus_two_minus_two_when_it_becomes_blocked() -> void:
	var dromo := put_battlefield(0, "Dromosaur")
	var wall := put_battlefield(1, "Wall of Stone")
	_attack_and_block([dromo], {wall.id: dromo.id})
	assert_eq(dromo.cur_power, 4)
	assert_eq(dromo.cur_toughness, 1)


# ------------------------------------------------------------------ Goblin Cadets --

func test_goblin_cadets_change_sides_when_blocked_and_leave_combat() -> void:
	var cadets := put_battlefield(0, "Goblin Cadets")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([cadets], {bear.id: cadets.id})
	assert_eq(cadets.controller_id, 1, "target opponent gains control of it")
	assert_false(g.combat.attackers.has(cadets.id), "removed from combat")
	_finish_combat()
	assert_eq(cadets.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.damage, 0)

func test_goblin_cadets_change_sides_when_they_block() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var cadets := put_battlefield(1, "Goblin Cadets")
	_attack_and_block([bear], {cadets.id: bear.id})
	assert_eq(cadets.controller_id, 0, "the blocker goes to ITS controller's opponent")
	_finish_combat()
	assert_eq(g.players[1].life, 20, "the Bears stay blocked (CR 509.1h)")


# ---------------------------------------------------- Viashino Weaponsmith, Cave Tiger --

func test_viashino_weaponsmith_grows_once_per_blocking_creature() -> void:
	var smith := put_battlefield(0, "Viashino Weaponsmith")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	_attack_and_block([smith], {a.id: smith.id, b.id: smith.id})
	assert_eq(smith.cur_power, 6, "+2/+2 twice")
	assert_eq(smith.cur_toughness, 6)

func test_cave_tiger_grows_when_blocked() -> void:
	var tiger := put_battlefield(0, "Cave Tiger")
	var bear := put_battlefield(1, "Grizzly Bears")
	_attack_and_block([tiger], {bear.id: tiger.id})
	assert_eq(tiger.cur_power, 3)
	assert_eq(tiger.cur_toughness, 3)
	_finish_combat()
	assert_eq(tiger.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------------- Karn, Silver Golem --

func test_karn_gets_minus_four_plus_four_when_it_blocks() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var karn := put_battlefield(1, "Karn, Silver Golem")
	_attack_and_block([giant], {karn.id: giant.id})
	assert_eq(karn.cur_power, 0)
	assert_eq(karn.cur_toughness, 8)

func test_karn_animates_a_noncreature_artifact_by_its_mana_value() -> void:
	var karn := put_battlefield(0, "Karn, Silver Golem")
	var mine := put_battlefield(0, "Jade Monolith")   # mana value 4
	var bird := put_battlefield(1, "Ornithopter")
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_refused(g.activate_ability(0, karn, 0, [TargetRef.card(bird)]))
	assert_ok(g.activate_ability(0, karn, 0, [TargetRef.card(mine)]))
	resolve_stack()
	assert_true(mine.is_creature())
	assert_true(mine.is_type(Mtg.CardType.ARTIFACT))
	assert_eq(mine.cur_power, 4)
	assert_eq(mine.cur_toughness, 4)
	advance_to_next_turn()
	assert_false(mine.is_creature(), "until end of turn")


# -------------------------------------------------------------------- Wall of Junk --

func test_wall_of_junk_returns_to_its_owners_hand_after_blocking() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wall := put_battlefield(1, "Wall of Junk")
	_attack_and_block([giant], {wall.id: giant.id})
	assert_eq(wall.zone, Mtg.Zone.BATTLEFIELD, "not until end of combat")
	_finish_combat()
	assert_eq(wall.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 20, "and it blocked")


# ---------------------------------------------------------------------- Electryte --

func test_electryte_hits_the_player_then_every_blocking_creature() -> void:
	var electryte := put_battlefield(0, "Electryte")
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	_attack_and_block([electryte, bear], {giant.id: bear.id})
	_finish_combat()
	assert_eq(g.players[1].life, 17)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "2 from the Bears, then 3 from the Electryte")

func test_electryte_blocked_without_trample_never_triggers() -> void:
	var electryte := put_battlefield(0, "Electryte")
	var wall := put_battlefield(1, "Wall of Stone")
	_attack_and_block([electryte], {wall.id: electryte.id})
	_finish_combat()
	assert_eq(wall.damage, 3, "only its combat damage")


# ------------------------------------------------------------------- Flesh Reaver --

func test_flesh_reaver_hurts_its_controller_for_damage_to_the_opponent() -> void:
	var reaver := put_battlefield(0, "Flesh Reaver")
	_attack_and_block([reaver], {})
	_finish_combat()
	assert_eq(g.players[1].life, 16)
	assert_eq(g.players[0].life, 16)

func test_flesh_reaver_hurts_its_controller_for_damage_to_blockers_once() -> void:
	var reaver := put_battlefield(0, "Flesh Reaver")
	var a := put_battlefield(1, "Grizzly Bears")
	var b := put_battlefield(1, "Llanowar Elves")
	_attack_and_block([reaver], {a.id: reaver.id, b.id: reaver.id})
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	var triggers := g.stack.filter(func(item: StackItem) -> bool: return item.card == reaver)
	assert_eq(triggers.size(), 1, "one trigger for the damage event")
	_finish_combat()
	assert_eq(g.players[0].life, 16, "4 damage dealt among the blockers")


# --------------------------------------------------------------- Order of Yawgmoth --

func test_order_of_yawgmoth_makes_the_damaged_player_discard() -> void:
	var order := put_battlefield(0, "Order of Yawgmoth")
	give_hand(1, "Forest")
	give_hand(1, "Lightning Bolt")
	_attack_and_block([order], {})
	_finish_combat()
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(g.players[1].graveyard.size(), 1)


# -------------------------------------------------------------------- Goblin Lackey --

func test_goblin_lackey_puts_a_goblin_from_hand_onto_the_battlefield() -> void:
	var lackey := put_battlefield(0, "Goblin Lackey")
	var raider := give_hand(0, "Mons's Goblin Raiders")
	give_hand(0, "Grizzly Bears")
	_attack_and_block([lackey], {})
	_finish_combat()
	assert_eq(raider.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(raider.controller_id, 0)

func test_goblin_lackey_may_decline() -> void:
	var lackey := put_battlefield(0, "Goblin Lackey")
	var raider := give_hand(0, "Mons's Goblin Raiders")
	me.yes = 0
	_attack_and_block([lackey], {})
	_finish_combat()
	assert_eq(raider.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------------ Thieving Magpie --

func test_thieving_magpie_draws_on_damage_to_an_opponent() -> void:
	var magpie := put_battlefield(0, "Thieving Magpie")
	var hand := g.players[0].hand.size()
	_attack_and_block([magpie], {})
	_finish_combat()
	assert_eq(g.players[0].hand.size(), hand + 1)


# ---------------------------------------------------------------- Phyrexian Negator --

func test_phyrexian_negator_sacrifices_one_permanent_per_damage() -> void:
	var negator := put_battlefield(0, "Phyrexian Negator")
	var lands: Array = []
	for n in 3: lands.append(put_battlefield(0, "Swamp"))
	put_battlefield(0, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(negator)]))
	resolve_stack()
	assert_eq(negator.zone, Mtg.Zone.BATTLEFIELD, "a 5/5 survives 3")
	assert_eq(g.players[0].battlefield.size(), 2, "three of its five permanents went")
	assert_eq(g.players[0].graveyard.size(), 3)
	assert_true(g.players[0].battlefield.has(negator), "the Negator itself is offered last")

func test_phyrexian_negator_dying_still_costs_its_controller() -> void:
	var negator := put_battlefield(0, "Phyrexian Negator")
	var swamp := put_battlefield(0, "Swamp")
	var giant := put_battlefield(1, "Shivan Dragon")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [negator.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: negator.id}))
	_finish_combat()
	assert_eq(negator.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(swamp.zone, Mtg.Zone.GRAVEYARD, "five to pay; the Swamp was all that was left")


func test_phyrexian_negator_pays_per_damage_event() -> void:
	var negator := put_battlefield(0, "Phyrexian Negator")
	put_battlefield(1, "Pestilence")
	for n in 4: put_battlefield(0, "Swamp")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B, 2)
	var pest: CardInstance = g.players[1].battlefield.filter(
		func(i: CardInstance) -> bool: return i.data.card_name == "Pestilence")[0]
	assert_ok(g.activate_ability(1, pest, 0))
	assert_ok(g.activate_ability(1, pest, 0))
	resolve_stack()
	assert_eq(negator.damage, 2)
	assert_eq(g.players[0].graveyard.size(), 2, "two events of 1: one permanent each")
