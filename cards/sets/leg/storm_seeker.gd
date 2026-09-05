extends CardScript
## Storm Seeker — {3}{G} — Instant — (leg, uncommon)
## Oracle: Storm Seeker deals damage to target player equal to the number
##         of cards in that player's hand.
##
## Implementation: card-local effect reading the target's hand size AT
## RESOLUTION (CR 608.2h — the amount is locked in then, not on cast), so
## a discard in response shrinks it. Green's answer to a full grip.


func build() -> CardData:
	return CardData.new("Storm Seeker", "{3}{G}", Mtg.CardType.INSTANT) \
		.spell(StormSeekerEffect.new()) \
		.oracle("Storm Seeker deals damage to target player equal to the number of "
			+ "cards in that player's hand.")


class StormSeekerEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var n := game.players[target.player_id].hand.size()
		if n > 0:
			game.deal_damage(source, target, n)

	func describe() -> String:
		return "deals damage to target player equal to their hand size"
