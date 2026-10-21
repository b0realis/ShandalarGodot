extends CardScript
## Contract from Below — {B} — Sorcery — (2ed, rare)
## Oracle: Remove this card from your deck before playing if you're not
##         playing for ante.
##         Discard your hand, ante the top card of your library, then draw
##         seven cards.
##
## Implementation: three steps, in the printed order — the discard happens
## BEFORE the ante, so a Contract cast with a full hand really costs you
## that hand.
##
## Not played for ante, it does nothing: the first line is enforced by the
## engine (the owner's ruling of 2026-10-21).
## `MtgGame.not_for_ante_refusal` refuses the cast: "Ante must be on for
## Contract from Below: this duel is not played for ante".


func build() -> CardData:
	return CardData.new("Contract from Below", "{B}", Mtg.CardType.SORCERY) \
		.spell(ContractEffect.new()) \
		.oracle("Remove this card from your deck before playing if you're not playing for ante.\nDiscard your hand, ante the top card of your library, then draw seven cards.")


class ContractEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.discard_hand(controller)
		game.ante_top_of_library(controller)
		game.draw_cards(controller, 7)

	func describe() -> String:
		return "discards your hand, antes the top card of your library, then draws seven"
