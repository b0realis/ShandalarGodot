extends CardScript
## Syphon Soul — {2}{B} — Sorcery — (leg, common)
## Oracle: Syphon Soul deals 2 damage to each other player. You gain life
##         equal to the damage dealt this way.
##
## Implementation: card-local effect. The life gain uses the amount
## MtgGame.deal_damage actually DEALT (the Drain Life audit fix), so a
## prevention shield on the opponent shrinks the gain to match.


func build() -> CardData:
	return CardData.new("Syphon Soul", "{2}{B}", Mtg.CardType.SORCERY) \
		.spell(SyphonEffect.new()) \
		.oracle("Syphon Soul deals 2 damage to each other player. "
			+ "You gain life equal to the damage dealt this way.")


class SyphonEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		# "You gain life equal to the damage dealt this way" — paid as
		# each packet LANDS, which under the 1997 damage-prevention window
		# is at the end of the step rather than now (§6.8).
		for p in game.players:
			if p.id != controller and not p.has_lost:
				game.deal_damage(source, TargetRef.player(p.id), 2, false,
					func(dealt: int) -> void:
						if dealt > 0:
							game.adjust_life(controller, dealt))

	func describe() -> String:
		return "deals 2 damage to each other player; you gain that much life"
