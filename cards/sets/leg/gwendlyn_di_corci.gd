extends CardScript
## Gwendlyn Di Corci — {U}{B}{B}{R} — Legendary Creature — Human Rogue — 3/5 — (leg, rare)
## Oracle: {T}: Target player discards a card at random. Activate only
##         during your turn.
##
## Implementation: a free tap ability restricted to its controller's turn
## (your_turn_only), stripping one card at random from any player. A 3/5
## body that empties a hand over four turns and blocks everything in the
## meantime.


func build() -> CardData:
	return CardData.new("Gwendlyn Di Corci", "{U}{B}{B}{R}", Mtg.CardType.CREATURE) \
		.pt(3, 5) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "rogue"]) \
		.activated(ActivatedAbility.new(
			"", true, [RandomDiscardEffect.new()],
			"{T}: Target player discards a card at random. Activate only during your turn.") \
			.your_turn_only()) \
		.oracle("{T}: Target player discards a card at random. Activate only during your turn.")


class RandomDiscardEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		game.discard_random(target.player_id, 1)

	func describe() -> String:
		return "target player discards a card at random"
