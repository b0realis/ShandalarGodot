extends CardScript
## Timetwister — {2}{U} — Sorcery (2ed, rare; Power Nine)
## Oracle: Each player shuffles their hand and graveyard into their
##         library, then draws seven cards.
##
## Implementation: card-local effect over two engine helpers
## (shuffle_hand_and_graveyard_into_library + draw_cards), each player in
## APNAP order. Zone subtlety the engine gets right for free: Timetwister
## itself is ON THE STACK while resolving, so it is NOT shuffled in — it
## reaches the graveyard only after resolution (CR 608.2m), exactly like
## the real card. The engine of the dos486 guide's infinite-turn Arzakon
## kill (Timetwister–Regrowth loop — Regrowth still a stub).


func build() -> CardData:
	return CardData.new("Timetwister", "{2}{U}", Mtg.CardType.SORCERY) \
		.spell(TwisterEffect.new()) \
		.oracle("Each player shuffles their hand and graveyard into their library, then draws seven cards.")


class TwisterEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for pid in [game.active_player, game.opponent_of(game.active_player)]:
			game.shuffle_hand_and_graveyard_into_library(pid)
			game.draw_cards(pid, 7)

	func describe() -> String:
		return "each player shuffles hand and graveyard into their library, then draws seven"
