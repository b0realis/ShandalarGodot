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
		# ONE RESOLUTION, ONE BRACKET (CR 704.3, 2026-09-10). This one is a
		# MASS BOUNCE and needs no death replacement to be visible:
		# MtgGame.return_to_hand ends with check_state_based_actions(), so
		# unbracketed the loop swept between every pair of artifacts and an
		# Aura orphaned by the first one was gone before the second left.
		# Nothing may return between the two calls: a deferral left open
		# freezes state-based actions for the rest of the game.
		game.begin_simultaneous()
		for inst in victims:
			game.return_to_hand(inst)
		game.end_simultaneous()

	func describe() -> String:
		return "returns all artifacts target player owns to their hand"
