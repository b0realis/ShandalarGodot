extends CardScript
## Force of Nature — {2}{G}{G}{G}{G} — Creature — Elemental — 8/8 — (2ed, rare)
## Oracle: Trample
##         At the beginning of your upkeep, this creature deals 8 damage
##         to you unless you pay {G}{G}{G}{G}.
##
## Implementation: the hungriest upkeep cost in the pool — an
## "unless you pay" trigger whose failure mode is 8 GREEN damage to its
## own controller (source = the Force itself, so CoP: Green eats it —
## the era's famous trick). try_pay auto-taps four Forests. The trigger is
## independent of the Force once it is on the stack (CR 603.6): removing
## the Force in response does not cancel the tax.


func build() -> CardData:
	return CardData.new("Force of Nature", "{2}{G}{G}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(8, 8) \
		.with_subtypes(["elemental"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _hunger,
			"At the beginning of your upkeep, this creature deals 8 damage to you unless you pay {G}{G}{G}{G}.",
			_own_upkeep)) \
		.oracle("Trample\nAt the beginning of your upkeep, this creature deals 8 damage to you unless you pay {G}{G}{G}{G}.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


## NO "is it still on the battlefield?" guard: a triggered ability exists
## independently of its source once it is on the stack, and resolves even
## if the source has left (CR 603.6; the damage uses last known
## information, CR 608.2h). Killing or bouncing the Force in response to
## its own upkeep trigger does not refund the {G}{G}{G}{G}. The player is
## read off the EVENT rather than off the (possibly reset) source, so a
## stolen Force still taxes the player whose upkeep it triggered on.
static func _hunger(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var cost := ManaCost.parse("{G}{G}{G}{G}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {G}{G}{G}{G} to appease %s?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		return
	game.deal_damage(source, TargetRef.player(pid), 8)
