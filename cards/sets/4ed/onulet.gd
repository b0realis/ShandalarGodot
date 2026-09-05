extends CardScript
## Onulet — {3} — Artifact Creature — Construct — 2/2 — (4ed, rare)
## Oracle: When this creature dies, you gain 2 life.
##
## Implementation: a self DIES trigger (the dying card hears it via the
## engine's 603.6b look-back) granting its controller 2 life.
## mage-go: DiesTrigger(GainLife(2)).


func build() -> CardData:
	return CardData.new("Onulet", "{3}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["construct"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _payout,
			"When this creature dies, you gain 2 life.",
			_is_self)) \
		.oracle("When this creature dies, you gain 2 life.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["instance"] == source


static func _payout(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var controller: int = event.data["controller"]
	game.adjust_life(controller, 2)
