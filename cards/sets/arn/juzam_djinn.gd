extends CardScript
## Juzám Djinn — {2}{B}{B} — Creature — Djinn — 5/5 — (arn, rare)
## Oracle: At the beginning of your upkeep, this creature deals 1 damage
##         to you.
##
## Implementation: the most famous drawback in early Magic — an own-upkeep
## trigger dealing 1 (a black source; CoP: Black stops your own djinn's
## bite). Undercosted muscle, paid for in blood.


func build() -> CardData:
	return CardData.new("Juzám Djinn", "{2}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_subtypes(["djinn"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _bite,
			"At the beginning of your upkeep, this creature deals 1 damage to you.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, this creature deals 1 damage to you.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


static func _bite(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.deal_damage(source, TargetRef.player(source.controller_id), 1)
