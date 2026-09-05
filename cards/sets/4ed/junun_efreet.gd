extends CardScript
## Junún Efreet — {1}{B}{B} — Creature — Efreet — 3/3 — (4ed, uncommon)
## Oracle: Flying
##         At the beginning of your upkeep, sacrifice this creature unless
##         you pay {B}{B}.
##
## Implementation: the "sacrifice unless you pay" upkeep pattern
## (phantasmal_forces.gd) with a heavier colored rent — undercosted wings
## on a payment plan.


func build() -> CardData:
	return CardData.new("Junún Efreet", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["efreet"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _toll,
			"At the beginning of your upkeep, sacrifice this creature unless you pay {B}{B}.",
			_own_upkeep)) \
		.oracle("Flying\nAt the beginning of your upkeep, sacrifice this creature unless you pay {B}{B}.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


static func _toll(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{B}{B}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {B}{B} to keep %s?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		return
	game.sacrifice_permanent(source)
