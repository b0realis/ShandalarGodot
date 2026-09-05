extends CardScript
## North Star — {4} — Artifact — (leg, rare)
## Oracle: {4}, {T}: For one spell this turn, you may spend mana as though
##         it were mana of any type to pay that spell's mana cost.
##         (Additional costs are still paid normally.)
##
## Implementation: a charge on the controller (MtgPlayer.any_color_spells)
## that the next cast which NEEDS it consumes — the engine tries a normal
## payment first, so a charge is never wasted on a spell you could already
## afford. Unused charges expire at cleanup.


func build() -> CardData:
	return CardData.new("North Star", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{4}", true, [NorthStarEffect.new()],
			"{4}, {T}: For one spell this turn, you may spend mana as though it were mana of any type.")) \
		.oracle("{4}, {T}: For one spell this turn, you may spend mana as though it were mana of any type to pay that spell's mana cost. (Additional costs are still paid normally.)")


class NorthStarEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.players[controller].any_color_spells += 1
		game.log_line("%s may pay one spell's cost with any mana this turn"
			% game.players[controller].player_name)

	func describe() -> String:
		return "one spell this turn may be paid with mana of any type"
