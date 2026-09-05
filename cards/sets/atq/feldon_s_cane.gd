extends CardScript
## Feldon's Cane — {1} — Artifact — (atq, uncommon)
## Oracle: {T}, Exile this artifact: Shuffle your graveyard into your library.
##
## Implementation: an ActivatedAbility with the new EXILE cost (the Cane
## removes itself from the game, so it can't be rebought) whose payload
## calls MtgGame.shuffle_graveyard_into_library. The pool's answer to
## decking — and, in a Millstone mirror, the whole game plan.


func build() -> CardData:
	return CardData.new("Feldon's Cane", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"", true, [RecycleEffect.new()],
			"{T}, Exile Feldon's Cane: Shuffle your graveyard into your library.") \
			.with_exile_cost()) \
		.oracle("{T}, Exile this artifact: Shuffle your graveyard into your library.")


class RecycleEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.shuffle_graveyard_into_library(controller)

	func describe() -> String:
		return "shuffles your graveyard into your library"
