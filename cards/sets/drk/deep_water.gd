extends CardScript
## Deep Water — {U}{U} — Enchantment — (drk, common)
## Oracle: {U}: Until end of turn, if you tap a land you control for mana,
##         it produces {U} instead of any other type.
##
## Implementation: a seat-level until-end-of-turn flag
## (MtgPlayer.land_mana_becomes, new) rather than a per-land text change,
## because the printed clause covers every land you control INCLUDING ones
## played later in the turn, and because it ends with the turn.
##
## MtgGame.tap_for_mana applies it by running the land's production into a
## scratch pool and moving only the TOTAL across, so the amount is whatever
## the land would have made — a Sol Ring is untouched (not a land), and a
## City of Shadows with five storage counters makes five BLUE.
##
## The Deep Water itself is a fixer, not a ramp: one blue in, all your lands
## blue out. It is also its own trap, since the effect is not optional.


func build() -> CardData:
	return CardData.new("Deep Water", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("{U}", false, [FloodEffect.new()],
			"{U}: Until end of turn, if you tap a land you control for mana, it produces {U} instead of any other type.")) \
		.oracle("{U}: Until end of turn, if you tap a land you control for mana, "
			+ "it produces {U} instead of any other type.")


class FloodEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.players[controller].land_mana_becomes = Mtg.ManaColor.U
		game.log_line("%s's lands run blue this turn"
			% game.players[controller].player_name)

	func describe() -> String:
		return "your lands produce blue this turn"
