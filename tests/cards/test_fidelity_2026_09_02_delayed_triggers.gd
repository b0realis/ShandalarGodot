extends GameTest
## The three cards lifted from the fidelity ledger on DELAYED triggered
## abilities (CR 603.7 — MtgGame.schedule_delayed_trigger; the mechanism
## is pinned by tests/unit/test_delayed_triggers.gd). Each is pinned on
## what its row denied it: Hazezon Tamar's sandstorm survives him leaving
## by ANY door and pays out to the player who cast him; Nafs Asp's bite is
## a debt that outlives the Asp, stacks per bite, and can be paid off
## early (settle_delayed_trigger) or as it comes due; Cyclopean Tomb's
## mired lands stay Swamps after it is gone and revert one per upkeep, the
## controller's choice, until the list is spent — and an exiled Tomb never
## reverts anything.


## Picks named cards, in order; records what it was offered.
class ListSeat extends DecisionAgent:
	var picks: Array = []
	var offered: Array = []

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		var names: Array = []
		for inst in candidates:
			names.append(inst.data.card_name)
		offered.append(names)
		if picks.is_empty():
			return null
		var wanted := String(picks.pop_front())
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null


## Says no to everything — a bitten player who will not pay.
class MiserSeat extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return false


func _log_has(text: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(text):
			return true
	return false


func _count(pid: int, card_name: String) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.data.card_name == card_name:
			n += 1
	return n


## From anywhere to P0's NEXT upkeep, with priority.
func _to_own_upkeep() -> void:
	if g.active_player == 0:
		advance_to_next_turn()                   # through the opponent's turn
	elif g.current_step() == Mtg.Step.UPKEEP:
		advance_to_step(Mtg.Step.MAIN1)          # off the opponent's upkeep
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 0)


## The Tomb (P0's, already on the battlefield) mires [param land] in the
## current upkeep of P0's turn.
func _mire(tomb: CardInstance, land: CardInstance) -> void:
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tomb, 0, [TargetRef.card(land)]))
	resolve_stack()
	assert_eq(int(land.counters.get("mire", 0)), 1)
	assert_true(land.has_subtype("swamp"))


# ----------------------------------------------------------- Hazezon Tamar --

func test_hazezon_exiled_in_response_still_raises_the_sands() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var hazezon := put_battlefield(0, "Hazezon Tamar")
	resolve_stack()                              # arms the delayed trigger
	g.exile_permanent(hazezon)
	resolve_stack()                              # his leave-trigger: nothing to exile
	assert_eq(hazezon.zone, Mtg.Zone.EXILE)
	_to_own_upkeep()
	resolve_stack()
	assert_eq(_count(0, "Sand Warrior"), 2, "the trigger lives on the game, not on him")


func test_hazezon_bounced_in_response_still_raises_the_sands() -> void:
	put_battlefield(0, "Forest")
	var hazezon := put_battlefield(0, "Hazezon Tamar")
	resolve_stack()
	g.return_to_hand(hazezon)
	resolve_stack()
	assert_eq(hazezon.zone, Mtg.Zone.HAND)
	_to_own_upkeep()
	resolve_stack()
	assert_eq(_count(0, "Sand Warrior"), 1)


func test_stolen_hazezon_pays_out_to_the_player_who_cast_him() -> void:
	# "Your next upkeep" is fixed when the delayed trigger is created (CR
	# 603.7d): the thief's upkeep is not the caster's.
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Island")
	var hazezon := put_battlefield(0, "Hazezon Tamar")
	resolve_stack()
	g.change_control(hazezon, 1)
	advance_to_next_turn()                       # the thief's turn goes by ...
	resolve_stack()
	assert_eq(_count(1, "Sand Warrior"), 0, "not at the thief's upkeep")
	advance_to_step(Mtg.Step.UPKEEP)             # ... then the caster's upkeep
	assert_eq(g.active_player, 0)
	resolve_stack()
	assert_eq(_count(0, "Sand Warrior"), 3, "the caster's lands, the caster's tokens")
	assert_eq(_count(1, "Sand Warrior"), 0)


# ----------------------------------------------------------------- Nafs Asp --

func test_nafs_asp_debt_survives_the_asp_dying() -> void:
	var asp := put_battlefield(0, "Nafs Asp")
	run_combat([asp.id])
	resolve_stack()
	g.destroy(asp, false)
	assert_eq(asp.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.settleable_delayed_triggers(1).size(), 1, "the debt is not the Asp's")
	advance_to_next_turn()
	resolve_stack()
	assert_eq(g.players[1].life, 18, "1 combat damage plus the unpaid 1")


func test_two_bites_are_two_debts() -> void:
	var asp := put_battlefield(0, "Nafs Asp")
	var other := put_battlefield(0, "Nafs Asp")
	run_combat([asp.id, other.id])
	resolve_stack()
	assert_eq(g.settleable_delayed_triggers(1).size(), 2)
	advance_to_next_turn()
	resolve_stack()
	assert_eq(g.players[1].life, 16, "2 combat damage plus two unpaid debts")
	assert_eq(g.delayed_triggers.size(), 0, "both collected")


func test_nafs_asp_debt_can_be_paid_off_before_the_draw_step() -> void:
	# "unless they pay {1} before that draw step": paid in the biter's own
	# turn, from mana the bitten player would otherwise lose.
	var asp := put_battlefield(0, "Nafs Asp")
	run_combat([asp.id])
	resolve_stack()
	assert_ok(g.pass_priority(0))                # the bitten player gets priority
	assert_eq(g.priority_player, 1)
	var debt := g.settleable_delayed_triggers(1)[0]
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.settle_delayed_trigger(1, int(debt["id"])))
	assert_eq(g.delayed_triggers.size(), 0, "paid off: nothing left to collect")
	assert_true(_log_has("pays {1}"))
	advance_to_next_turn()
	resolve_stack()
	assert_eq(g.players[1].life, 19, "the combat damage only")


func test_nafs_asp_settlement_is_the_bitten_players_and_needs_priority() -> void:
	var asp := put_battlefield(0, "Nafs Asp")
	run_combat([asp.id])
	resolve_stack()
	var debt := g.settleable_delayed_triggers(1)[0]
	add_mana(0, Mtg.ManaColor.G)
	add_mana(1, Mtg.ManaColor.G)
	assert_refused(g.settle_delayed_trigger(0, int(debt["id"])), "not yours")
	assert_refused(g.settle_delayed_trigger(0, 9999), "no such")
	assert_refused(g.settle_delayed_trigger(1, int(debt["id"])), "priority")
	assert_eq(g.delayed_triggers.size(), 1)


func test_nafs_asp_unpaid_debt_is_the_1997_line() -> void:
	# `@NAFS_ASP`, Program/prompts.txt:611. A player who could pay but
	# declines loses the life.
	g.set_agent(1, MiserSeat.new())
	var asp := put_battlefield(0, "Nafs Asp")
	put_battlefield(1, "Forest")
	run_combat([asp.id])
	resolve_stack()
	advance_to_next_turn()
	resolve_stack()
	assert_eq(g.players[1].life, 18)
	assert_true(_log_has("Naf's Asp takes 1 life!"))


# ----------------------------------------------------------- Cyclopean Tomb --

func test_cyclopean_tomb_destroyed_leaves_the_mired_land_a_swamp() -> void:
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var island := put_battlefield(1, "Island")
	_mire(tomb, island)
	g.destroy(tomb, false)
	resolve_stack()                              # the dies-trigger arms the reversion
	assert_eq(tomb.zone, Mtg.Zone.GRAVEYARD)
	assert_true(island.has_subtype("swamp"), "a Swamp for as long as it has the counter")
	assert_ok(g.tap_for_mana(1, island))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.B), 1)
	assert_eq(g.delayed_triggers.size(), 1, "the reversion is pending")


func test_cyclopean_tomb_reverts_one_land_per_upkeep_then_retires() -> void:
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var island := put_battlefield(1, "Island")
	var plains := put_battlefield(1, "Plains")
	_mire(tomb, island)
	_to_own_upkeep()                             # the Tomb has untapped
	_mire(tomb, plains)
	g.destroy(tomb, false)
	resolve_stack()
	_to_own_upkeep()
	assert_eq(g.stack.size(), 1, "the reversion triggers at our upkeep")
	resolve_stack()
	var reverted := int(island.has_subtype("swamp") == false) \
		+ int(plains.has_subtype("swamp") == false)
	assert_eq(reverted, 1, "exactly one land reverts per upkeep")
	assert_eq(g.delayed_triggers.size(), 1, "one land still to revert")
	advance_to_step(Mtg.Step.END)
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 1)
	assert_eq(g.stack.size(), 0, "the opponent's upkeep is not ours")
	_to_own_upkeep()
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_false(island.has_subtype("swamp"))
	assert_false(plains.has_subtype("swamp"))
	assert_eq(int(island.counters.get("mire", 0)) + int(plains.counters.get("mire", 0)), 0)
	assert_eq(g.delayed_triggers.size(), 0, "spent: the entry retires")
	_to_own_upkeep()
	assert_eq(g.stack.size(), 0, "nothing left to trigger")


func test_cyclopean_tomb_reversion_is_the_controllers_choice() -> void:
	# `@CYCLOPEAN_TOMB_EFFECT`: "Cyclopean Tomb: Select land to revert."
	var seat := ListSeat.new()
	seat.picks = ["Island"]
	g.set_agent(0, seat)
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var forest := put_battlefield(0, "Forest")
	var island := put_battlefield(1, "Island")
	_mire(tomb, forest)
	_to_own_upkeep()
	_mire(tomb, island)
	g.destroy(tomb, false)
	resolve_stack()
	_to_own_upkeep()
	resolve_stack()
	assert_eq(seat.offered.size(), 1)
	assert_eq(seat.offered[0], ["Forest", "Island"], "own land first, then theirs")
	assert_false(island.has_subtype("swamp"), "the seat's pick reverted")
	assert_true(forest.has_subtype("swamp"), "the other stays a Swamp")
	assert_true(_log_has("Cyclopean Tomb: Island reverts"))


func test_cyclopean_tomb_heuristic_reverts_its_own_lands_first() -> void:
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var forest := put_battlefield(0, "Forest")
	var island := put_battlefield(1, "Island")
	_mire(tomb, island)                          # theirs first, on purpose
	_to_own_upkeep()
	_mire(tomb, forest)
	g.destroy(tomb, false)
	resolve_stack()
	_to_own_upkeep()
	resolve_stack()
	assert_false(forest.has_subtype("swamp"), "our own Forest is given back first")
	assert_true(island.has_subtype("swamp"), "their Island stays mired longest")


func test_cyclopean_tomb_exiled_never_reverts_anything() -> void:
	# "When this artifact is put into a graveyard from the battlefield":
	# exile is not that door, and the lands stay Swamps for good.
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var island := put_battlefield(1, "Island")
	_mire(tomb, island)
	g.exile_permanent(tomb)
	resolve_stack()
	assert_eq(g.delayed_triggers.size(), 0, "no reversion was armed")
	_to_own_upkeep()
	assert_eq(g.stack.size(), 0)
	resolve_stack()
	assert_true(island.has_subtype("swamp"))
	assert_eq(int(island.counters.get("mire", 0)), 1)


func test_cyclopean_tomb_forgets_a_mired_land_that_left() -> void:
	# A land that left the battlefield is a new object when it returns (CR
	# 400.7): it is no longer "a land a mire counter was put onto".
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var island := put_battlefield(1, "Island")
	_mire(tomb, island)
	g.destroy(tomb, false)
	resolve_stack()
	g.return_to_hand(island)
	assert_eq(g.delayed_triggers.size(), 1)
	_to_own_upkeep()
	resolve_stack()
	assert_eq(g.delayed_triggers.size(), 0, "nothing left to revert: retired")
	assert_eq(int(island.counters.get("mire", 0)), 0, "counters do not follow a card to hand")
