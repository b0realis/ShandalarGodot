extends CardScript
## Mind Twist — {X}{B} — Sorcery (2ed, rare)
## Oracle: Target player discards X cards at random.
##
## Implementation: card-local effect over discard_random with the X value —
## randomness through the game RNG (deterministic under seed). The era's
## most feared hand-destruction spell; restricted, later banned outright.


func build() -> CardData:
	return CardData.new("Mind Twist", "{X}{B}", Mtg.CardType.SORCERY) \
		.spell(TwistEffect.new()) \
		.oracle("Target player discards X cards at random.")


class TwistEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		if x_value > 0:
			game.discard_random(target.player_id, x_value)

	func describe() -> String:
		return "target player discards X cards at random"
