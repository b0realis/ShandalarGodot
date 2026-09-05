extends CardScript
## Bazaar of Baghdad — Land — (arn, uncommon)
## Oracle: {T}: Draw two cards, then discard three cards.
##
## Implementation: a land with NO mana ability at all — its only ability
## is a card-local draw-then-discard. Net card DISadvantage on purpose:
## the point is filling a graveyard and digging for one specific card,
## which is why it never left the reserved list's shadow.


func build() -> CardData:
	return CardData.new("Bazaar of Baghdad", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new(
			"", true, [BazaarEffect.new()],
			"{T}: Draw two cards, then discard three cards.")) \
		.oracle("{T}: Draw two cards, then discard three cards.")


class BazaarEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.draw_cards(controller, 2)
		var want: int = mini(3, game.players[controller].hand.size())
		if want <= 0:
			return
		var chosen := game.agents[controller].choose_discard(game, controller, want)
		game.discard_cards(controller, chosen)
		while game.players[controller].hand.size() > 0 \
				and chosen.size() < want:
			chosen.append(game.players[controller].hand[-1])
			game.discard_cards(controller, [game.players[controller].hand[-1]])

	func describe() -> String:
		return "draw two cards, then discard three cards"
