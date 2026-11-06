extends GameTest
## Pack 10 (the Urza block), batch B13: Archery Training — an Aura whose
## granted ability reads ITS arrow counters (Pack 10 E2's grantor link,
## `ActivatedAbility.granted_by` / `grantor_counters`, CR 613.7, 608.2h).
##
## "Enchant creature / At the beginning of your upkeep, you may put an
## arrow counter on this Aura. / Enchanted creature has "{T}: This creature
## deals X damage to target attacking or blocking creature, where X is the
## number of arrow counters on Archery Training.""

const W := Mtg.ManaColor.W

## A seat whose yes/no answers a test scripts (-1 follows the hint).
class Seat extends DecisionAgent:
	var yes := -1
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
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


func test_archery_training_is_claimed() -> void:
	var c := CardRegistry.get_card("Archery Training")
	assert_not_null(c)
	if c == null: return
	assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending")
	assert_true(c.is_aura())


## Enchant [param host] with a fresh Archery Training of P0's, cast for real.
func _train(host: CardInstance) -> CardInstance:
	advance_to_step(Mtg.Step.MAIN1)
	var aura := give_hand(0, "Archery Training")
	add_mana(0, W)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD)
	return aura


func _shot_index(host: CardInstance, aura: CardInstance) -> int:
	for i in host.cur_activated_abilities.size():
		if host.cur_activated_abilities[i].grantor_id == aura.id:
			return i
	return -1


## P1 attacks with [param attacker] on their turn; we stop with P0 holding
## priority in the declare-blockers step after [param blocks].
func _p1_attacks(attacker: CardInstance, blocks: Dictionary = {}) -> void:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, blocks))
	if g.priority_player != 0:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, 0)


func test_an_arrow_counter_at_each_of_your_upkeeps_if_you_choose() -> void:
	var archer := put_battlefield(0, "Grizzly Bears")
	var aura := _train(archer)
	assert_eq(int(aura.counters.get("arrow", 0)), 0)
	advance_to_next_turn()   # P1's turn: not your upkeep
	advance_to_next_turn()   # P0's upkeep
	assert_eq(int(aura.counters.get("arrow", 0)), 1)
	me.yes = 0
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(int(aura.counters.get("arrow", 0)), 1, "declined")


func test_the_enchanted_creature_shoots_x_at_an_attacker() -> void:
	var archer := put_battlefield(0, "Grizzly Bears")
	var aura := _train(archer)
	g.add_counters(aura, "arrow", 2)
	var raider := put_battlefield(1, "Hill Giant")
	var index := _shot_index(archer, aura)
	assert_gt(index, -1, "the creature has the ability")
	_p1_attacks(raider)
	assert_ok(g.activate_ability(0, archer, index, [TargetRef.card(raider)]))
	resolve_stack()
	assert_eq(raider.damage, 2, "X = 2 arrow counters")
	assert_true(archer.tapped)


func test_only_attacking_or_blocking_creatures_are_targets() -> void:
	var archer := put_battlefield(0, "Grizzly Bears")
	var aura := _train(archer)
	g.add_counters(aura, "arrow", 1)
	var idle := put_battlefield(1, "Hill Giant")
	assert_refused(g.activate_ability(0, archer, _shot_index(archer, aura), [TargetRef.card(idle)]))


func test_the_ability_leaves_with_the_aura_and_reads_the_last_count() -> void:
	var archer := put_battlefield(0, "Grizzly Bears")
	var aura := _train(archer)
	g.add_counters(aura, "arrow", 3)
	var raider := put_battlefield(1, "Craw Wurm")
	_p1_attacks(raider)
	assert_ok(g.activate_ability(0, archer, _shot_index(archer, aura), [TargetRef.card(raider)]))
	g.destroy(aura)   # in response, the Aura goes (setup)
	resolve_stack()
	assert_eq(raider.damage, 3, "the counters it had as the ability was activated (CR 608.2h)")
	assert_eq(_shot_index(archer, aura), -1, "the creature no longer has it")


func test_two_trainings_are_two_abilities_each_with_its_own_count() -> void:
	var archer := put_battlefield(0, "Grizzly Bears")
	var first := _train(archer)
	var second := _train(archer)
	g.add_counters(first, "arrow", 1)
	g.add_counters(second, "arrow", 2)
	var one := _shot_index(archer, first)
	var two := _shot_index(archer, second)
	assert_gt(one, -1)
	assert_gt(two, -1)
	assert_ne(one, two)
	var raider := put_battlefield(1, "Hill Giant")
	_p1_attacks(raider)
	assert_ok(g.activate_ability(0, archer, two, [TargetRef.card(raider)]))
	resolve_stack()
	assert_eq(raider.damage, 2)
