extends CardScript
## Typhoon — {2}{G} — Sorcery — (leg, rare)
## Oracle: Typhoon deals damage to each opponent equal to the number of
##         Islands that player controls.
##
## Implementation: card-local effect counting Islands per opponent —
## the amount is per-player, so one DamageAllEffect can't express it.
## Counts the LAND SUBTYPE (dual lands count), not the card name.


func build() -> CardData:
	return CardData.new("Typhoon", "{2}{G}", Mtg.CardType.SORCERY) \
		.spell(TyphoonEffect.new()) \
		.oracle("Typhoon deals damage to each opponent equal to the number of "
			+ "Islands that player controls.")


class TyphoonEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for p in game.players:
			if p.id == controller or p.has_lost:
				continue
			var islands := 0
			for inst in game.all_battlefield():
				if inst.controller_id == p.id and inst.is_land() \
						and inst.has_subtype("island"):
					islands += 1
			if islands > 0:
				game.deal_damage(source, TargetRef.player(p.id), islands)

	func describe() -> String:
		return "deals damage to each opponent equal to their Island count"
