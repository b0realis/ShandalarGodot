extends GameTest
## The 0.60.19 bug pass (Pack 10): Thran Turbine's upkeep mana with the
## Turbine gone, and Interdict's "activated ability from an artifact,
## creature, enchantment, or land".
##
## - Thran Turbine: the trigger is independent of its source once on the
##   stack (CR 113.7a) — a Turbine destroyed in response still adds
##   {C}{C} to the trigger's controller (Forge resolves it too).
## - Interdict (CR 109.2: "an artifact, creature, enchantment, or land" means
##   a permanent): a cycling ability, activated from a hand, is a card's
##   and no legal target; and "that permanent's activated abilities can't
##   be activated" binds the permanent — bounced to the hand it is a new
##   object (CR 400.7) and its cycling may be activated.

const U := Mtg.ManaColor.U
const W := Mtg.ManaColor.W
const C := Mtg.ManaColor.C


class Seat extends DecisionAgent:
	var yes := -1
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

var me: Seat


func before_each() -> void:
	CardPacks.set_enabled_many(["pack-9", "pack-10"] as Array[String], true)
	super()
	me = Seat.new()
	g.set_agent(0, me)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


static func _cycling_index(card: CardInstance) -> int:
	for i in card.cur_activated_abilities.size():
		if card.cur_activated_abilities[i].is_cycling:
			return i
	return -1


# ----------------------------------------------------------- Thran Turbine --

func test_thran_turbine_destroyed_in_response_still_adds_its_mana() -> void:
	var turbine := put_battlefield(0, "Thran Turbine")
	me.yes = 1
	advance_to_next_turn()   # the opponent's turn
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 0)
	var waiting := false
	for item in g.stack:
		if item.card == turbine: waiting = true
	assert_true(waiting, "the upkeep trigger is on the stack")
	g.destroy(turbine)
	assert_eq(turbine.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(me.asked.size(), 1, "still asked: the trigger resolves without its source (CR 113.7a)")
	assert_eq(g.players[0].mana_pool.total_of(C), 2, "{C}{C} for the trigger's controller")
	assert_false(g.players[0].mana_pool.can_pay(ManaCost.parse("{2}"), 0, ["spell"]),
		"still mana no spell may spend")


# --------------------------------------------------------------- Interdict --

func _interdict(target: TargetRef) -> String:
	var interdict := give_hand(1, "Interdict")
	add_mana(1, U)
	add_mana(1, C)
	if g.priority_player != 1:
		assert_ok(g.pass_priority(g.priority_player))
	return g.cast_spell(1, interdict, [target])


func test_interdict_cannot_target_a_cycling_ability() -> void:
	var rune := give_hand(0, "Rune of Protection: Red")
	g.recalculate()
	var index := _cycling_index(rune)
	assert_gt(index, -1)
	add_mana(0, C, 2)
	assert_ok(g.activate_ability(0, rune, index))
	assert_eq(rune.zone, Mtg.Zone.GRAVEYARD, "discarded as the cost")
	assert_refused(_interdict(TargetRef.ability(g.stack[0])))


func test_interdict_still_targets_an_ability_whose_permanent_was_sacrificed_for_it() -> void:
	var gnomes := put_battlefield(0, "Bottle Gnomes")
	assert_ok(g.activate_ability(0, gnomes, 0))
	assert_eq(gnomes.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	assert_ok(_interdict(TargetRef.ability(g.stack[0])))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "countered: no life")


func test_an_interdicted_permanent_bounced_to_the_hand_may_cycle() -> void:
	var rune := put_battlefield(0, "Rune of Protection: Red")
	add_mana(0, W)
	assert_ok(g.activate_ability(0, rune, 0))
	assert_ok(_interdict(TargetRef.ability(g.stack[0])))
	resolve_stack()
	add_mana(0, W)
	if g.priority_player != 0:
		assert_ok(g.pass_priority(g.priority_player))
	assert_refused(g.activate_ability(0, rune, 0), "Interdict")
	g.return_to_hand(rune)
	assert_eq(rune.zone, Mtg.Zone.HAND)
	g.recalculate()
	add_mana(0, C, 2)
	if g.priority_player != 0:
		assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.activate_ability(0, rune, _cycling_index(rune)))
	resolve_stack()
	assert_eq(rune.zone, Mtg.Zone.GRAVEYARD, "a new object (CR 400.7): it cycled")
