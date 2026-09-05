extends CardScript
## Bottle of Suleiman — {4} — Artifact — (4ed, rare)
## Oracle: {1}, Sacrifice this artifact: Flip a coin. If you win the flip,
##         create a 5/5 colorless Djinn artifact creature token with
##         flying. If you lose the flip, this artifact deals 5 damage to you.
##
## Implementation: a sacrifice-cost ability whose payload calls
## MtgGame.flip_coin (deterministic through game.rng, so a seeded game
## replays identically) and branches: a 5/5 flier or five damage to the
## face. Five mana for a coin toss was Arabian Nights' idea of a bomb.


func build() -> CardData:
	return CardData.new("Bottle of Suleiman", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{1}", false, [BottleEffect.new(_djinn_data())],
			"{1}, Sacrifice Bottle of Suleiman: Flip a coin. Win: create a 5/5 flying "
			+ "Djinn. Lose: it deals 5 damage to you.") \
			.with_sacrifice_cost()) \
		.oracle("{1}, Sacrifice this artifact: Flip a coin. If you win the flip, "
			+ "create a 5/5 colorless Djinn artifact creature token with flying. If "
			+ "you lose the flip, this artifact deals 5 damage to you.")


static func _djinn_data() -> CardData:
	return CardData.new("Djinn", "", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_subtypes(["djinn"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.oracle("Flying")


class BottleEffect extends EffectBase:
	var token: CardData

	func _init(p_token: CardData) -> void:
		token = p_token

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if game.flip_coin(controller):
			game.create_token(controller, token)
		else:
			game.deal_damage(source, TargetRef.player(controller), 5)

	func describe() -> String:
		return "flip a coin: a 5/5 flier, or 5 damage to you"
