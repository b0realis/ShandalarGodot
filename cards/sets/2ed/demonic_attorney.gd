extends CardScript
## Demonic Attorney — {1}{B}{B} — Sorcery — (2ed, rare)
## Oracle: Remove this card from your deck before playing if you're not
##         playing for ante.
##         Each player antes the top card of their library.
##
## Implementation: symmetric — the caster antes too. Turn order (caster
## first) only matters when a library is nearly empty.


func build() -> CardData:
	return CardData.new("Demonic Attorney", "{1}{B}{B}", Mtg.CardType.SORCERY) \
		.spell(AttorneyEffect.new()) \
		.oracle("Remove this card from your deck before playing if you're not playing for ante.\nEach player antes the top card of their library.")


class AttorneyEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.ante_top_of_library(controller)
		game.ante_top_of_library(game.opponent_of(controller))

	func describe() -> String:
		return "each player antes the top card of their library"
