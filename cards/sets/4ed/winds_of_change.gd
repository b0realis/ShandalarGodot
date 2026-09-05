extends CardScript
## Winds of Change — {R} — Sorcery (4ed, rare; first printed in The Dark)
## Oracle: Each player shuffles the cards from their hand into their
##         library, then draws that many cards.
##
## Implementation: card-local effect over shuffle_hand_into_library —
## unlike Wheel of Fortune the counts are preserved and graveyards stay
## put: a pure hand reroll, symmetric, one red mana.


func build() -> CardData:
	return CardData.new("Winds of Change", "{R}", Mtg.CardType.SORCERY) \
		.spell(WindsEffect.new()) \
		.oracle("Each player shuffles the cards from their hand into their library, then draws that many cards.")


class WindsEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for pid in [game.active_player, game.opponent_of(game.active_player)]:
			var count := game.players[pid].hand.size()
			game.shuffle_hand_into_library(pid)
			game.draw_cards(pid, count)

	func describe() -> String:
		return "each player shuffles their hand into their library and redraws"
