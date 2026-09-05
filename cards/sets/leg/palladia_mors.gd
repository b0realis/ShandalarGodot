extends CardScript
## Palladia-Mors — {2}{R}{R}{G}{G}{W}{W} — Legendary Creature — Elder Dragon — 7/7 — (leg, rare)
## Oracle: Flying, trample
##         At the beginning of your upkeep, sacrifice Palladia-Mors unless
##         you pay {R}{G}{W}.
##
## Implementation: the simplest Elder Dragon — two printed keywords and
## the cycle's upkeep rent. A 7/7 flying trampler ends the game in three
## swings, if the mana holds out.


func build() -> CardData:
	return CardData.new("Palladia-Mors", "{2}{R}{R}{G}{G}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(7, 7) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["elder", "dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.TRAMPLE]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _rent,
			"At the beginning of your upkeep, sacrifice Palladia-Mors unless you pay {R}{G}{W}.",
			_own_upkeep)) \
		.oracle("Flying, trample\nAt the beginning of your upkeep, sacrifice "
			+ "Palladia-Mors unless you pay {R}{G}{W}.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{R}{G}{W}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {R}{G}{W} to keep Palladia-Mors?", true) \
			and game.try_pay(pid, cost):
		return
	game.sacrifice_permanent(source)
