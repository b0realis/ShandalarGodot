extends CardScript
## Wheel of Fortune — {2}{R} — Sorcery (2ed, rare)
## Oracle: Each player discards their hand, then draws seven cards.
##
## Implementation: card-local effect over the discard_hand + draw_cards
## helpers, each player in APNAP order. Unlike Timetwister, graveyards
## stay put — the discard FEEDS the graveyard (future reanimation fuel).
## Restricted in Shandalar's deck rules.


func build() -> CardData:
	return CardData.new("Wheel of Fortune", "{2}{R}", Mtg.CardType.SORCERY) \
		.spell(WheelEffect.new()) \
		.oracle("Each player discards their hand, then draws seven cards.")


class WheelEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for pid in [game.active_player, game.opponent_of(game.active_player)]:
			game.discard_hand(pid)
			game.draw_cards(pid, 7)

	func describe() -> String:
		return "each player discards their hand, then draws seven cards"
