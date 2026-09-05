extends CardScript
## Eternal Flame — {2}{R}{R} — Sorcery — (drk, rare)
## Oracle: Eternal Flame deals X damage to target opponent or planeswalker
##         and half X damage, rounded up, to you, where X is the number of
##         Mountains you control.
##
## Implementation: one TARGET slot for the opponent (TargetSpec.opponent(),
## so the choice is locked in at cast time and every targeting rule — a
## fizzle when the target is gone, protection, "can't be the target of"
## effects — applies to it, CR 115), plus an untargeted half-X to the
## caster. X counts live Mountain subtypes, so Taiga and Badlands feed the
## fire. Planeswalkers do not exist in the 1997 pool, so the printed "or
## planeswalker" half of the target line has nothing to describe.


func build() -> CardData:
	return CardData.new("Eternal Flame", "{2}{R}{R}", Mtg.CardType.SORCERY) \
		.spell(FlameEffect.new()) \
		.oracle("Eternal Flame deals X damage to target opponent and half X damage, rounded up, to you, where X is the number of Mountains you control.")


class FlameEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var mountains := 0
		for inst in game.players[controller].battlefield:
			if inst.is_land() and inst.has_subtype("mountain"):
				mountains += 1
		if target != null and target.is_player:
			game.deal_damage(source, target, mountains)
		# "and half X damage, rounded up, to you" — no target, so it
		# happens even if the targeted opponent has somehow left the game.
		@warning_ignore("integer_division")
		game.deal_damage(source, TargetRef.player(controller), (mountains + 1) / 2)

	func describe() -> String:
		return "X damage to target opponent and half X, rounded up, to you (X = your Mountains)"
