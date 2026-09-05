extends CardScript
## Serendib Efreet — {2}{U} — Creature — Efreet — 3/4 — (arn, rare)
## Oracle: Flying
##         At the beginning of your upkeep, this creature deals 1 damage
##         to you.
##
## Implementation: Juzám's blue cousin (juzam_djinn.gd) — a 3/4 flyer for
## three with the same one-a-turn bite.


func build() -> CardData:
	return CardData.new("Serendib Efreet", "{2}{U}", Mtg.CardType.CREATURE) \
		.pt(3, 4) \
		.with_subtypes(["efreet"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _bite,
			"At the beginning of your upkeep, this creature deals 1 damage to you.",
			_own_upkeep)) \
		.oracle("Flying\nAt the beginning of your upkeep, this creature deals 1 damage to you.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


static func _bite(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.deal_damage(source, TargetRef.player(source.controller_id), 1)
