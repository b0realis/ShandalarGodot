extends CardScript
## Ivory Tower — {1} — Artifact (4ed, rare; first printed in Antiquities)
## Oracle: At the beginning of your upkeep, you gain X life, where X is the
##         number of cards in your hand minus 4.
##
## Implementation: UPKEEP_START trigger on the CONTROLLER's upkeep, life
## gain = hand size - 4 (nothing at 4 or fewer). The defensive twin of
## Black Vise, and a Shandalar shop staple. Restricted in the era's
## tournament rules; the deck validator will flag it.


func build() -> CardData:
	return CardData.new("Ivory Tower", "{1}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START,
			_gain,
			"At the beginning of your upkeep, you gain X life, where X is the number of cards in your hand minus 4.",
			_is_my_upkeep)) \
		.oracle("At the beginning of your upkeep, you gain X life, where X is the number of cards in your hand minus 4.")


static func _is_my_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


static func _gain(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var x := game.players[source.controller_id].hand.size() - 4
	if x > 0:
		game.adjust_life(source.controller_id, x)
