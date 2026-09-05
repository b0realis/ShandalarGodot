extends CardScript
## Jalum Tome — {3} — Artifact — Book — (atq, uncommon)
## Oracle: {2}, {T}: Draw a card, then discard a card.
##
## Implementation: a card-local looting effect — the draw happens first,
## then the controller's DecisionAgent picks the discard from the new
## hand (the printed order matters: you may discard the card you just
## drew). Card selection, not card advantage.


func build() -> CardData:
	return CardData.new("Jalum Tome", "{3}", Mtg.CardType.ARTIFACT) \
		.with_subtypes(["book"]) \
		.activated(ActivatedAbility.new(
			"{2}", true, [LootEffect.new()],
			"{2}, {T}: Draw a card, then discard a card.")) \
		.oracle("{2}, {T}: Draw a card, then discard a card.")


class LootEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.draw_cards(controller, 1)
		if game.players[controller].hand.is_empty():
			return
		var chosen := game.agents[controller].choose_discard(game, controller, 1)
		if chosen.is_empty():
			chosen = [game.players[controller].hand[-1]]
		game.discard_cards(controller, chosen)

	func describe() -> String:
		return "draw a card, then discard a card"
