extends CardScript
## Giant Badger — {1}{G}{G} — Creature — Badger — 2/2 — (phpr, rare)
## Oracle: Whenever this creature blocks, it gets +2/+2 until end of turn.
##
## Implementation: a BLOCKED trigger (one event per declared block pair)
## gated on this creature being the BLOCKER, resolving into a self pump.
## A 2/2 that fights as a 4/4 on defense — the original "Pit Fight"
## promo, and a genuinely awkward attack for the opponent.


func build() -> CardData:
	return CardData.new("Giant Badger", "{1}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["badger"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _bulk_up,
			"Whenever Giant Badger blocks, it gets +2/+2 until end of turn.",
			_is_the_blocker)) \
		.oracle("Whenever this creature blocks, it gets +2/+2 until end of turn.")


static func _is_the_blocker(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data.get("blocker") == source


static func _bulk_up(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_pump(source.id, 2, 2)
	game.recalculate()
