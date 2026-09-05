extends CardScript
## Cosmic Horror — {3}{B}{B}{B} — Creature — Horror — 7/7 — (4ed, rare)
## Oracle: First strike
##         At the beginning of your upkeep, destroy this creature unless
##         you pay {3}{B}{B}{B}. If this creature is destroyed this way,
##         it deals 7 damage to you.
##
## Implementation: the "pay or die" upkeep pattern (Phantasmal Forces)
## with teeth — failure DESTROYS it (so a regeneration shield can save it,
## unlike a sacrifice) and, only if it actually left the battlefield,
## burns its controller for 7. A 7/7 first striker for six that costs six
## more every turn.


func build() -> CardData:
	return CardData.new("Cosmic Horror", "{3}{B}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(7, 7) \
		.with_subtypes(["horror"]) \
		.with_keywords([Mtg.Keyword.FIRST_STRIKE]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _toll,
			"At the beginning of your upkeep, destroy Cosmic Horror unless you pay "
			+ "{3}{B}{B}{B}. If it is destroyed this way, it deals 7 damage to you.",
			_own_upkeep)) \
		.oracle("First strike\nAt the beginning of your upkeep, destroy this creature "
			+ "unless you pay {3}{B}{B}{B}. If this creature is destroyed this way, it "
			+ "deals 7 damage to you.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _toll(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{3}{B}{B}{B}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {3}{B}{B}{B} to keep Cosmic Horror?", true) \
			and game.try_pay(pid, cost):
		return
	game.destroy(source)
	if source.zone != Mtg.Zone.BATTLEFIELD:   # a regeneration shield saves you too
		game.deal_damage(source, TargetRef.player(pid), 7)
