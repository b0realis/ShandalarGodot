extends CardScript
## Disintegrate — {X}{R} — Sorcery — (2ed, common)
## Oracle: Disintegrate deals X damage to any target. If it's a creature,
##         it can't be regenerated this turn, and if it would die this turn,
##         exile it instead.
##
## Implementation: the damage plus both riders — the engine's
## "can't be regenerated this turn" flag and a new
## CardInstance.exile_instead_of_dying replacement, both cleared at cleanup.
## The riders are applied BEFORE the damage, so a creature that dies to it
## really is exiled.


func build() -> CardData:
	return CardData.new("Disintegrate", "{X}{R}", Mtg.CardType.SORCERY) \
		.spell(DisintegrateEffect.new()) \
		.oracle("Disintegrate deals X damage to any target. If it's a creature, it can't be regenerated this turn, and if it would die this turn, exile it instead.")


class DisintegrateEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.any_target()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		if not target.is_player:
			var victim := game.find_instance(target.instance_id)
			if victim != null and victim.zone == Mtg.Zone.BATTLEFIELD:
				victim.regeneration_banned_this_turn = true
				victim.exile_instead_of_dying = true
		game.deal_damage(source, target, x_value)

	func describe() -> String:
		return "deals X damage; a creature it kills is exiled and can't be regenerated"
