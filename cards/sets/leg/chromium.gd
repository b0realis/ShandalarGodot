extends CardScript
## Chromium — {2}{W}{W}{U}{U}{B}{B} — Legendary Creature — Elder Dragon — 7/7 — (leg, rare)
## Oracle: Flying
##         Rampage 2 (Whenever this creature becomes blocked, it gets
##         +2/+2 until end of turn for each creature blocking it beyond
##         the first.)
##         At the beginning of your upkeep, sacrifice Chromium unless you
##         pay {W}{U}{B}.
##
## Implementation: printed flying, the engine's RAMPAGE field, and the
## Elder Dragon upkeep rent — a "sacrifice unless you pay" trigger on
## your own upkeep (Phantasmal Forces' pattern, one dragon-sized bill).


func build() -> CardData:
	return CardData.new("Chromium", "{2}{W}{W}{U}{U}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(7, 7) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["elder", "dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.with_rampage(2) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _rent,
			"At the beginning of your upkeep, sacrifice Chromium unless you pay {W}{U}{B}.",
			_own_upkeep)) \
		.oracle("Flying\nRampage 2 (Whenever this creature becomes blocked, it gets "
			+ "+2/+2 until end of turn for each creature blocking it beyond the first.)\n"
			+ "At the beginning of your upkeep, sacrifice Chromium unless you pay {W}{U}{B}.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{W}{U}{B}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {W}{U}{B} to keep Chromium?", true) \
			and game.try_pay(pid, cost):
		return
	game.sacrifice_permanent(source)
