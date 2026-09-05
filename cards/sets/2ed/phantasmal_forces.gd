extends CardScript
## Phantasmal Forces — {3}{U} — Creature — Illusion — 4/1 — (2ed, uncommon)
## Oracle: Flying
##         At the beginning of your upkeep, sacrifice this creature unless
##         you pay {U}.
##
## Implementation: the "sacrifice unless you pay" upkeep pattern — the
## controller's DecisionAgent is offered the {U} (MtgGame.try_pay);
## declining or being unable to pay sacrifices the illusion (a SACRIFICE:
## no regeneration possible). 4 power for four mana was the era's rate —
## if you kept feeding it.


func build() -> CardData:
	return CardData.new("Phantasmal Forces", "{3}{U}", Mtg.CardType.CREATURE) \
		.pt(4, 1) \
		.with_subtypes(["illusion"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _toll,
			"At the beginning of your upkeep, sacrifice this creature unless you pay {U}.",
			_own_upkeep)) \
		.oracle("Flying\nAt the beginning of your upkeep, sacrifice this creature unless you pay {U}.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


static func _toll(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{U}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {U} to keep %s?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		return
	game.sacrifice_permanent(source)
