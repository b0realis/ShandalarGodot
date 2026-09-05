extends CardScript
## Riptide — {U} — Instant — (drk, common)
## Oracle: Tap all blue creatures.
##
## Implementation: a card-local sweep tapping every blue creature on the
## battlefield — symmetric, so a blue deck casting it usually taps its own
## board too. Cast in an opponent's beginning of combat it blanks a blue
## attack; cast in your own it clears blue blockers.


func build() -> CardData:
	return CardData.new("Riptide", "{U}", Mtg.CardType.INSTANT) \
		.spell(RiptideEffect.new()) \
		.oracle("Tap all blue creatures.")


class RiptideEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for inst in game.all_battlefield():
			if inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.U) != 0:
				game.tap_permanent(inst)

	func describe() -> String:
		return "taps all blue creatures"
