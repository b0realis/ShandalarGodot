extends CardScript
## Hurkyl's Recall — {1}{U} — Instant — (4ed, rare)
## Oracle: Return all artifacts target player owns to their hand.
##
## Implementation: a card-local effect keyed on OWNERSHIP, not control —
## an artifact you stole with Steal Artifact goes back to its owner's hand
## when they are the target. Two mana to undo an entire artifact deck's
## turn; the reason blue was the artifact deck's nightmare.


func build() -> CardData:
	return CardData.new("Hurkyl's Recall", "{1}{U}", Mtg.CardType.INSTANT) \
		.spell(RecallEffect.new()) \
		.oracle("Return all artifacts target player owns to their hand.")


class RecallEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victims: Array[CardInstance] = []
		for inst in game.all_battlefield():
			if inst.owner_id == target.player_id and inst.is_type(Mtg.CardType.ARTIFACT):
				victims.append(inst)
		for inst in victims:
			game.return_to_hand(inst)

	func describe() -> String:
		return "returns all artifacts target player owns to their hand"
