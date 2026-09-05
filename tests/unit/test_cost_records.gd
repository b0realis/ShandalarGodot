extends GameTest
## WHAT A COST ATE, PER ACTIVATION — [member StackItem.cost_paid] and
## [method MtgGame.cost_paid] (the 2026-09-01 card audit's HIGH finding,
## fixed 2026-09-02).
##
## Four cards read what their activation cost consumed: Life Chisel and
## Diamond Valley the sacrificed body's toughness, Necropolis the exiled
## card's mana value, Land's Edge the discarded card's type. Those records
## used to live in `CardInstance.memory`, which is ONE slot per permanent
## — so the SECOND payment overwrote the first and two activations waiting
## on the stack together both read the second one's record.
##
## It is not a corner case for any of the four: Life Chisel and Necropolis
## cost no mana at all and Land's Edge lets ANY player activate it, so
## stacking two is the ordinary line rather than a trick. Every test below
## puts two activations on the stack before either resolves, which is the
## only shape that can tell the two implementations apart.


## An agent that answers the cost questions from a SCRIPT, so a test can
## say which body each activation eats. Everything else is the base agent.
class Scripted extends DecisionAgent:
	## Cards to hand back, in order, one per `answer_card` call.
	var cards: Array[CardInstance] = []
	## Cards to discard, in order, one per `answer_discard` call.
	var discards: Array[CardInstance] = []

	func answer_card(_game: MtgGame, _pid: int,
			candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		while not cards.is_empty():
			var pick: CardInstance = cards.pop_front()
			if candidates.has(pick):
				return pick
		return null if candidates.is_empty() else candidates[0]

	func answer_discard(_game: MtgGame, _pid: int,
			count: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		while out.size() < count and not discards.is_empty():
			out.append(discards.pop_front())
		return out


func _scripted(pid: int) -> Scripted:
	var agent := Scripted.new()
	g.set_agent(pid, agent)
	return agent


## Move [param inst] from hand to [param pid]'s graveyard (setup only).
func _bury(pid: int, inst: CardInstance) -> CardInstance:
	g.players[pid].hand.erase(inst)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


# ----------------------------------------------------- a sacrifice cost --

func test_two_life_chisels_on_the_stack_each_gain_their_own_body() -> void:
	# The Chisel costs no mana, so cashing in two creatures in one upkeep
	# is one click and then another. With the record on the PERMANENT both
	# resolutions read the Craw Wurm and gained 4 + 4; each activation now
	# carries its own.
	var chisel := put_battlefield(0, "Life Chisel")
	var bears := put_battlefield(0, "Grizzly Bears")      # 2/2
	var wurm := put_battlefield(0, "Craw Wurm")           # 6/4
	var agent := _scripted(0)
	agent.cards = [bears, wurm]
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, chisel, 0))
	assert_ok(g.activate_ability(0, chisel, 0))
	assert_eq(g.stack.size(), 2, "both activations are waiting")
	resolve_stack()
	assert_eq(g.players[0].life, 26, "2 from the Bears and 4 from the Wurm")


func test_one_chisel_activation_is_unaffected() -> void:
	# The single-activation case is what the old code got right; it must
	# still be right, or the fix traded one bug for another.
	var chisel := put_battlefield(0, "Life Chisel")
	var bears := put_battlefield(0, "Grizzly Bears")
	var agent := _scripted(0)
	agent.cards = [bears]
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, chisel, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 22)


func test_the_record_does_not_survive_into_a_later_activation() -> void:
	# A record parked on the permanent also LEAKED FORWARD: the next
	# activation that paid no sacrifice at all still found the old body's
	# toughness sitting there. Nothing in the pool pays this cost
	# optionally today, so this pins the invariant rather than a live bug:
	# a resolution outside any activation reads nothing.
	var chisel := put_battlefield(0, "Life Chisel")
	var bears := put_battlefield(0, "Grizzly Bears")
	var agent := _scripted(0)
	agent.cards = [bears]
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, chisel, 0))
	resolve_stack()
	assert_eq(g.cost_paid("_sacrificed_toughness", -1), -1,
		"the record dies with the stack item that owned it")


# ------------------------------------------- an exile-from-graveyard cost --

func test_two_necropolis_activations_each_eat_their_own_corpse() -> void:
	# Necropolis is free to activate, so feeding it twice in one priority
	# window is normal play. 1 + 4 counters, not 4 + 4.
	var necro := put_battlefield(0, "Necropolis")
	var cheap := _bury(0, give_hand(0, "Grizzly Bears"))       # {1}{G}, mv 2
	var dear := _bury(0, give_hand(0, "Craw Wurm"))            # {4}{G}{G}, mv 6
	var agent := _scripted(0)
	agent.cards = [cheap, dear]
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, necro, 0))
	assert_ok(g.activate_ability(0, necro, 0))
	assert_eq(g.stack.size(), 2)
	resolve_stack()
	assert_eq(int(necro.counters.get("+0/+1", 0)), 8,
		"2 for the Bears and 6 for the Wurm, not 6 twice")
	assert_eq(necro.cur_toughness, 9, "0/1 plus eight +0/+1 counters")


# ------------------------------------------------------- a discard cost --

func test_two_lands_edge_activations_read_their_own_discard() -> void:
	# ANY player may activate Land's Edge, so two activations on the stack
	# is the card's ordinary state and not a trick. One discard is a land
	# and the other is not: exactly one of them may deal its 2 damage.
	var edge := put_battlefield(0, "Land's Edge")
	var land := give_hand(0, "Mountain")
	var spell := give_hand(0, "Lightning Bolt")
	var agent := _scripted(0)
	agent.discards = [land, spell]
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, edge, 0, [TargetRef.player(1)]))
	assert_ok(g.activate_ability(0, edge, 0, [TargetRef.player(1)]))
	assert_eq(g.stack.size(), 2)
	resolve_stack()
	assert_eq(g.players[1].life, 18,
		"the land discard dealt 2; the Bolt discard dealt nothing")


func test_a_lands_edge_activation_that_threw_no_land_deals_nothing() -> void:
	var edge := put_battlefield(0, "Land's Edge")
	var spell := give_hand(0, "Lightning Bolt")
	var agent := _scripted(0)
	agent.discards = [spell]
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, edge, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 20)


# ------------------------------------------------------- the shape itself --

func test_the_record_rides_the_stack_item_not_the_permanent() -> void:
	# The structural claim, stated once so a future refactor cannot quietly
	# put it back on the permanent: after the cost is paid, the activation
	# on the stack knows what it ate and the permanent does not.
	var chisel := put_battlefield(0, "Life Chisel")
	var bears := put_battlefield(0, "Grizzly Bears")
	var agent := _scripted(0)
	agent.cards = [bears]
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.activate_ability(0, chisel, 0))
	assert_eq(g.stack.size(), 1)
	assert_eq(int(g.stack[0].cost_paid.get("_sacrificed_toughness", -1)), 2)
	assert_false(chisel.memory.has("_sacrificed_toughness"),
		"nothing engine-owned is left on the permanent any more")
